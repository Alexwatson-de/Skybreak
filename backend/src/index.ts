import { createServer } from 'node:http';
import { randomBytes, randomInt, randomUUID, timingSafeEqual } from 'node:crypto';
import { spawn, type ChildProcess } from 'node:child_process';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Server, type Socket } from 'socket.io';
import { z } from 'zod';
import { attachGameGateway } from './game-gateway.js';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const godot = process.env.GODOT_BIN || resolve(root,'.runtime/Godot.app/Contents/MacOS/Godot');
const gamePath = process.env.GAME_PATH || resolve(root,'game');
const port = Number(process.env.PORT || 3000);
const publicHost = process.env.PUBLIC_GAME_HOST || '127.0.0.1';
const publicUrl = process.env.PUBLIC_URL || process.env.RENDER_EXTERNAL_URL || `http://localhost:${port}`;
const webUrl = (process.env.WEB_URL || '').replace(/\/$/, '');
const gameTransport = process.env.GAME_TRANSPORT || 'enet';
if (!['enet','websocket'].includes(gameTransport)) throw Error('Invalid GAME_TRANSPORT');
const allowedOrigins = new Set([webUrl, ...(process.env.ALLOWED_ORIGINS || '').split(',')].filter(Boolean).map(u=>new URL(u).origin));
function originAllowed(origin?:string) {
  if (!origin) return true; // Native clients authenticate with per-match tickets.
  if (allowedOrigins.has(origin)) return true;
  if (!webUrl && !process.env.ALLOWED_ORIGINS) {
    try { const u=new URL(origin); return ['127.0.0.1','localhost','[::1]'].includes(u.hostname); } catch { return false; }
  }
  return false;
}
const basePort = Number(process.env.GAME_PORT_BASE || 29500);
const maxRooms = Math.min(32, Number(process.env.MAX_ROOMS || 8));
const nameSchema = z.string().trim().min(1).max(18).regex(/^[\p{L}\p{N} _.-]+$/u);
const codeSchema = z.object({code:z.string().toUpperCase().regex(/^[A-Z2-9]{6}$/)});
const configSchema = z.object({map:z.number().int().min(0).max(2),mode:z.number().int().min(0).max(1)});
interface Pilot { id:string; token:string; name:string; char:number; team:number; ready:boolean; socket?:string; disconnectedAt?:number; }
interface Room { code:string; host:string; map:number; mode:number; players:string[]; chat:{name:string;text:string}[]; phase:'lobby'|'starting'|'match'; process?:ChildProcess; port?:number; tickets?:Record<string,string>; createdAt:number; }
const pilots = new Map<string,Pilot>();
const rooms = new Map<string,Room>();
const usedPorts = new Set<number>();
const ipConnections = new Map<string,number>();
const http = createServer((req,res)=>{
  if(req.url==='/health') { res.setHeader('Content-Type','application/json'); res.setHeader('Cache-Control','no-store'); if(originAllowed(req.headers.origin)&&req.headers.origin)res.setHeader('Access-Control-Allow-Origin',req.headers.origin); res.end(JSON.stringify({ok:true,rooms:rooms.size,protocol:2,version:'1.2.0',transport:gameTransport})); return; }
  if(req.url?.startsWith('/join?')) {
    const code=new URL(req.url,publicUrl).searchParams.get('room')||'';
    if(webUrl && /^[A-Z2-9]{6}$/.test(code)) { res.writeHead(302,{Location:`${webUrl}/?room=${code}`});res.end();return; }
    res.setHeader('Content-Type','text/html; charset=utf-8');
    res.end(`<!doctype html><meta name="viewport" content="width=device-width"><title>Skybreak invite</title><body style="background:#08121f;color:#eef4fc;font:20px system-ui;max-width:640px;margin:12vh auto;padding:32px"><p style="color:#b8ef70">SKYBREAK / ARENA</p><h1>Your squad is waiting.</h1><p>Open Skybreak Arena → Online → paste this invite link or room code.</p><pre style="font-size:48px;letter-spacing:8px">${/^[A-Z2-9]{6}$/.test(code)?code:'INVALID'}</pre><p>Use the lobby server address provided by your host. Play in the Skybreak website or the latest desktop client.</p></body>`);return;
  }
  res.statusCode=404;res.end('Skybreak lobby. GET /health');
});
const io = new Server(http,{maxHttpBufferSize:4096,transports:['websocket'],cors:{origin:[...allowedOrigins]},allowRequest:(req,done)=>done(null,originAllowed(req.headers.origin)),destroyUpgrade:false,pingInterval:10000,pingTimeout:6000});
attachGameGateway(http,code=>gameTransport==='websocket'?rooms.get(code):undefined,originAllowed);
const tokenEqual=(a:string,b:string)=>{const aa=Buffer.from(a),bb=Buffer.from(b);return aa.length===bb.length&&timingSafeEqual(aa,bb);};
function pilotFor(socket:Socket) { const p=pilots.get(socket.data.pilotId); if(!p)throw Error('Session expired');return p; }
function roomFor(id:string) { return [...rooms.values()].find(r=>r.players.includes(id)); }
function publicRoom(r:Room) { return {code:r.code,host:r.host,map:r.map,mode:r.mode,phase:r.phase,invite:webUrl?`${webUrl}/?room=${r.code}`:`${publicUrl}/join?room=${r.code}`,players:r.players.map(id=>{const p=pilots.get(id)!;return {id:p.id,name:p.name,char:p.char,team:p.team,ready:p.ready,online:!!p.socket};}),chat:r.chat}; }
function broadcast(r:Room) { io.to(r.code).emit('room',publicRoom(r)); }
function fail(s:Socket,message:string) { s.emit('error_message',{message}); }
function leave(p:Pilot) {
  const r=roomFor(p.id);if(!r)return;
  r.players=r.players.filter(id=>id!==p.id);
  if(p.socket){io.sockets.sockets.get(p.socket)?.leave(r.code);io.to(p.socket).emit('left',{});}
  if(r.players.length===0){r.process?.kill('SIGTERM');rooms.delete(r.code);return;}
  if(r.host===p.id)r.host=r.players[0];
  broadcast(r);
}
function createRoom(p:Pilot,map:number,mode:number) {
  if(rooms.size>=maxRooms)throw Error('Server room capacity reached');
  leave(p);
  let code='';do{code=Array.from({length:6},()=> 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[randomInt(32)]).join('');}while(rooms.has(code));
  const r:Room={code,host:p.id,map,mode,players:[p.id],chat:[],phase:'lobby',createdAt:Date.now()};
  p.ready=false;p.team=0;rooms.set(code,r);if(p.socket)io.sockets.sockets.get(p.socket)?.join(code);broadcast(r);return r;
}
function joinRoom(p:Pilot,r:Room) {
  if(r.phase!=='lobby')throw Error('Match already started');
  if(r.players.length>=8)throw Error('Room is full');
  leave(p);p.team=r.players.length%2;p.ready=false;r.players.push(p.id);
  if(p.socket)io.sockets.sockets.get(p.socket)?.join(r.code);broadcast(r);
}
function matchPayload(r:Room,p:Pilot) { return {host:publicHost,port:r.port,token:r.tickets?.[p.id],room:r.code,transport:gameTransport,websocket:`${publicUrl.replace(/^http/,'ws')}/game/${r.code}`}; }
async function startMatch(r:Room) {
  if(r.phase!=='lobby')throw Error('Match already starting');
  if(r.players.length<2)throw Error('At least two pilots are required');
  if(r.players.some(id=>!pilots.get(id)?.ready||!pilots.get(id)?.socket))throw Error('Every pilot must be connected and ready');
  if(r.mode===1&&new Set(r.players.map(id=>pilots.get(id)!.team)).size<2)throw Error('Team deathmatch needs pilots on both teams');
  let udp=basePort;while(usedPorts.has(udp))udp++;
  usedPorts.add(udp);r.port=udp;r.phase='starting';broadcast(r);
  const dir=await mkdtemp(resolve(tmpdir(),'skybreak-'));
  r.tickets={};
  const roster=r.players.map((id,index)=>{const p=pilots.get(id)!;const token=randomBytes(32).toString('hex');r.tickets![id]=token;return {id:index+1,name:p.name,char:p.char,team:p.team,token};});
  const file=resolve(dir,'roster.json');
  await writeFile(file,JSON.stringify(roster),{mode:0o600});
  try {
    const child=spawn(godot,['--headless','--path',gamePath,'--','--server',`--port=${udp}`,`--transport=${gameTransport}`,`--map=${r.map}`,`--mode=${r.mode}`,`--roster=${file}`],{stdio:['ignore','pipe','pipe']});
    r.process=child;
    await new Promise<void>((done,reject)=>{
      const timer=setTimeout(()=>reject(Error('Game server startup timed out')),15000);
      child.once('error',e=>{clearTimeout(timer);reject(e);});
      child.once('exit',()=>{clearTimeout(timer);reject(Error('Game server exited during startup'));});
      child.stdout?.on('data',b=>{process.stdout.write(`[game ${r.code}] ${b}`);if(String(b).includes('SERVER_READY')){clearTimeout(timer);done();}});
      child.stderr?.on('data',b=>process.stderr.write(`[game ${r.code}] ${b}`));
    });
    r.phase='match';broadcast(r);
    for(const id of r.players){const p=pilots.get(id)!;if(p.socket)io.to(p.socket).emit('match',matchPayload(r,p));}
    child.once('exit',()=>{usedPorts.delete(udp);r.process=undefined;r.phase='lobby';r.tickets=undefined;for(const id of r.players){const p=pilots.get(id);if(p)p.ready=false;}broadcast(r);void rm(dir,{recursive:true,force:true});});
    // Bound abandoned matches and server resources, even if clients never connect.
    setTimeout(()=>child.kill('SIGTERM'),7*60*1000).unref();
  } catch(e) {r.process?.kill();usedPorts.delete(udp);r.phase='lobby';broadcast(r);await rm(dir,{recursive:true,force:true});throw e;}
}
io.use((socket,next)=>{
  const ip=socket.handshake.address;const count=ipConnections.get(ip)||0;
  if(count>=32)return next(Error('Connection capacity reached'));
  const auth=socket.handshake.auth||{};
  let p=typeof auth.session==='string'?[...pilots.values()].find(x=>tokenEqual(x.token,auth.session)):undefined;
  if(p?.socket&&io.sockets.sockets.has(p.socket))return next(Error('Session already connected'));
  if(!p){
    if(pilots.size>=512)return next(Error('Server session capacity reached'));
    const parsed=nameSchema.safeParse(auth.name);if(!parsed.success)return next(Error('Use a name with 1–18 letters or numbers'));
    p={id:randomUUID(),token:randomBytes(32).toString('hex'),name:parsed.data,char:z.number().int().min(0).max(3).catch(0).parse(auth.char),team:0,ready:false};pilots.set(p.id,p);
  }
  p.socket=socket.id;p.disconnectedAt=undefined;socket.data.pilotId=p.id;ipConnections.set(ip,count+1);next();
});
io.on('connection',socket=>{
  const p=pilotFor(socket);socket.emit('session',{id:p.id,token:p.token});
  const previous=roomFor(p.id);if(previous){socket.join(previous.code);broadcast(previous);if(previous.phase==='match')socket.emit('match',matchPayload(previous,p));}
  let events=0;let window=Date.now();
  function on<T>(event:string,schema:z.ZodType<T>,run:(data:T)=>unknown){socket.on(event,async(raw:unknown)=>{
    if(Date.now()-window>1000){window=Date.now();events=0;}
    if(++events>12){fail(socket,'Slow down');return;}
    const parsed=schema.safeParse(raw);if(!parsed.success){fail(socket,'Invalid request');return;}
    try{await run(parsed.data);}catch(e){fail(socket,e instanceof Error?e.message:'Request failed');}
  });}
  on('create',configSchema,d=>createRoom(p,d.map,d.mode));
  on('join',codeSchema,d=>{const r=rooms.get(d.code);if(!r)throw Error('Room not found');if(r.players.includes(p.id)){broadcast(r);return;}joinRoom(p,r);});
  on('matchmake',configSchema,d=>{if(roomFor(p.id))throw Error('Leave your room first');const r=[...rooms.values()].find(r=>r.phase==='lobby'&&r.mode===d.mode&&r.map===d.map&&r.players.length<8);return r?joinRoom(p,r):createRoom(p,d.map,d.mode);});
  on('ready',z.object({ready:z.boolean()}),d=>{const r=roomFor(p.id);if(!r||r.phase!=='lobby')throw Error('No open lobby');p.ready=d.ready;broadcast(r);});
  on('team',z.object({team:z.number().int().min(0).max(1)}),d=>{const r=roomFor(p.id);if(!r||r.phase!=='lobby')throw Error('No open lobby');p.team=d.team;p.ready=false;broadcast(r);});
  on('chat',z.object({text:z.string().trim().min(1).max(160)}),d=>{const r=roomFor(p.id);if(!r)throw Error('Join a room first');r.chat.push({name:p.name,text:d.text.replace(/[\r\n\x00-\x1f]/g,' ')});r.chat=r.chat.slice(-30);broadcast(r);});
  on('start',z.object({}),async()=>{const r=roomFor(p.id);if(!r||r.host!==p.id)throw Error('Only the host can start');await startMatch(r);});
  on('leave',z.object({}),()=>leave(p));
  on('end_match',z.object({}),()=>{const r=roomFor(p.id);if(!r||r.host!==p.id)throw Error('Only the host can end');r.process?.kill('SIGTERM');});
  socket.on('disconnect',()=>{ipConnections.set(socket.handshake.address,Math.max(0,(ipConnections.get(socket.handshake.address)||1)-1));if(p.socket===socket.id){p.socket=undefined;p.disconnectedAt=Date.now();p.ready=false;const r=roomFor(p.id);if(r)broadcast(r);}});
});
setInterval(()=>{for(const p of pilots.values()){if(!p.socket&&p.disconnectedAt&&Date.now()-p.disconnectedAt>30000&&roomFor(p.id)?.phase!=='match'){leave(p);pilots.delete(p.id);}}},5000).unref();
http.listen(port,'0.0.0.0',()=>console.log(`LOBBY_READY port=${port} gameHost=${publicHost}`));
function shutdown(){for(const r of rooms.values())r.process?.kill('SIGTERM');io.close();http.close(()=>process.exit(0));setTimeout(()=>process.exit(0),2000).unref();}
process.on('SIGINT',shutdown);process.on('SIGTERM',shutdown);
// Deliberately no database, payment SDK, tracking SDK, or client authority.

