import { test } from 'node:test';
import { request } from 'node:http';
import assert from 'node:assert/strict';
import { spawn, type ChildProcess } from 'node:child_process';
import { io, type Socket } from 'socket.io-client';
import { resolve } from 'node:path';
import { writeFile, readFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
const url='http://127.0.0.1:3017';
const root=resolve('..');
const godot=process.env.GODOT_BIN || resolve(root,'.runtime/Godot.app/Contents/MacOS/Godot');
function event(s:Socket,name:string,predicate:(d:any)=>boolean=()=>true,timeout=16000):Promise<any>{return new Promise((done,reject)=>{const timer=setTimeout(()=>{s.off(name,on);reject(Error(`Timed out waiting for ${name}`));},timeout);const on=(d:any)=>{if(predicate(d)){clearTimeout(timer);s.off(name,on);done(d);}};s.on(name,on);});}
async function connect(name:string,session?:string){const s=io(url,{transports:['websocket'],autoConnect:false,auth:{name,char:1,session},reconnection:false});const ready=event(s,'session');s.connect();return {socket:s,session:await ready};}
const delay=(ms:number)=>new Promise(r=>setTimeout(r,ms));
function client(args:string[],log:string){const binary=process.env.CLIENT_BIN||godot;const runtimeArgs=process.env.CLIENT_BIN?['--headless']:['--headless','--path',resolve(root,'game')];const p=spawn(binary,[...runtimeArgs,'--',...args],{stdio:['ignore','pipe','pipe']});let out='';p.stdout?.on('data',d=>out+=d);p.stderr?.on('data',d=>out+=d);const result=new Promise<number|null>((done)=>p.on('exit',async(code)=>{await writeFile(log,out);done(code);}));return {p,result};}
test(`real lobby → ready checks → dedicated ${process.env.GAME_TRANSPORT || 'enet'} → two native clients → reconnect`, {timeout:65000},async()=>{
 const server=spawn(process.execPath,['dist/index.js'],{env:{...process.env,PORT:'3017',PUBLIC_URL:url,GAME_PORT_BASE:'29700',GODOT_BIN:godot},stdio:['ignore','pipe','pipe']});
 let logs='';server.stdout.on('data',d=>logs+=d);server.stderr.on('data',d=>logs+=d);
 const sockets:Socket[]=[];const processes:ChildProcess[]=[];const dir=await mkdtemp(resolve(tmpdir(),'skybreak-test-'));
 try{
  for(let i=0;i<80;i++){try{if((await fetch(url+'/health')).ok)break;}catch{}await delay(100);}
  const health=await (await fetch(url+'/health')).json();assert.equal(health.protocol,2);
  async function upgradeStatus(path:string,origin='http://127.0.0.1:8123') {
    return new Promise<number>((done,reject)=>{
      const req=request(url+path,{headers:{Connection:'Upgrade',Upgrade:'websocket',Origin:origin}},res=>{res.resume();done(res.statusCode!);});
      req.setTimeout(2500,()=>{req.destroy();reject(Error('Upgrade was left hanging'));});req.on('error',reject);req.end();
    });
  }
  assert.equal(await upgradeStatus('/game/ABC234'),404);
  assert.equal(await upgradeStatus('/unknown-upgrade'),404);
  assert.equal(await upgradeStatus('/game/ABC234','https://untrusted.invalid'),403);
  const a=await connect('Alpha');const b=await connect('Bravo');sockets.push(a.socket,b.socket);
  let roomEvent=event(a.socket,'room');a.socket.emit('create',{map:0,mode:1});let room=await roomEvent;
  assert.match(room.code,/^[A-Z2-9]{6}$/);assert.match(room.invite,/room=/);
  const joined=event(a.socket,'room',r=>r.players.length===2);b.socket.emit('join',{code:room.code});room=await joined;
  const chat=event(b.socket,'room',r=>r.chat.at(-1)?.text==='Ready to fly');a.socket.emit('chat',{text:'Ready to fly'});await chat;
  const forbidden=event(b.socket,'error_message');b.socket.emit('start',{});assert.match((await forbidden).message,/host/);
  const notReady=event(a.socket,'error_message');a.socket.emit('start',{});assert.match((await notReady).message,/ready/);
  let updated=event(a.socket,'room',r=>r.players.find((p:any)=>p.id===b.session.id)?.team===0);b.socket.emit('team',{team:0});await updated;
  updated=event(a.socket,'room',r=>r.players.every((p:any)=>p.ready));a.socket.emit('ready',{ready:true});b.socket.emit('ready',{ready:true});await updated;
  const teamError=event(a.socket,'error_message');a.socket.emit('start',{});assert.match((await teamError).message,/both teams/);
  updated=event(a.socket,'room',r=>r.players.find((p:any)=>p.id===b.session.id)?.team===1);b.socket.emit('team',{team:1});await updated;
  updated=event(a.socket,'room',r=>r.players.every((p:any)=>p.ready));b.socket.emit('ready',{ready:true});await updated;
  const ma=event(a.socket,'match'),mb=event(b.socket,'match');a.socket.emit('start',{});const [ta,tb]=await Promise.all([ma,mb]);
  assert.equal(ta.transport,process.env.GAME_TRANSPORT || 'enet');assert.notEqual(ta.token,tb.token);assert.equal(ta.port,tb.port);
  const ra=resolve(dir,'alpha.json'),rb=resolve(dir,'bravo.json');
  const ca=client([...(ta.transport==='websocket'?[`--websocket=${ta.websocket}`]:[`--join=${ta.host}`,`--port=${ta.port}`]),`--token=${ta.token}`,'--auto','--seconds=16',`--report=${ra}`],resolve(dir,'alpha.log'));
  const cb=client([...(tb.transport==='websocket'?[`--websocket=${tb.websocket}`]:[`--join=${tb.host}`,`--port=${tb.port}`]),`--token=${tb.token}`,'--auto','--adversarial','--drop-at=5','--seconds=16',`--report=${rb}`],resolve(dir,'bravo.log'));
  processes.push(ca.p,cb.p);
  const id=b.session.id;b.socket.disconnect();await delay(150);
  const recovered=await connect('Bravo',b.session.token);sockets.push(recovered.socket);assert.equal(recovered.session.id,id);
  const done=await Promise.all([ca.result,cb.result]);assert.deepEqual(done,[0,0]);
  const reportA=JSON.parse(await readFile(ra,'utf8')),reportB=JSON.parse(await readFile(rb,'utf8'));
  console.log(JSON.stringify({reportA,reportB}));
  assert.ok(reportA.metrics.snapshots>150);assert.ok(reportB.metrics.snapshots>100);assert.equal(reportA.players.length,2);assert.equal(reportB.players.length,2);
  assert.equal(reportB.metrics.reconnects,1);assert.equal(reportB.local_id,2);assert.ok(reportA.metrics.shots>20);assert.ok(reportA.metrics.hits>0);assert.ok(reportA.players.every((p:any)=>p.hp>=0&&p.hp<=100));
  assert.ok(!logs.includes('SCRIPT ERROR'));assert.ok(!logs.includes('above the MTU'));
  await writeFile(resolve(root,'docs/online-test-evidence.json'),JSON.stringify({date:new Date().toISOString(),client_kind:process.env.CLIENT_BIN?'packaged-macos':'engine-project',transport:ta.transport,checks:['room codes','invite link','lobby chat','host authorization','ready gate','team balance','dedicated startup','unique match tickets','2 ENet clients','snapshots','hits','lobby session recovery','ENet reconnect'],alpha:reportA,bravo:reportB},null,2));
  await writeFile(resolve(root,'docs/online-server-test.log'),logs);
 }finally{await writeFile(resolve(root,'docs/latest-server-test.log'),logs);for(const s of sockets)s.disconnect();for(const p of processes)p.kill();server.kill('SIGTERM');await delay(300);await rm(dir,{recursive:true,force:true});}
});
