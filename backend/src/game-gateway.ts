import { request, type IncomingMessage, type Server } from 'node:http';
import type { Duplex } from 'node:stream';

interface Match { port?: number; phase: string }

/** One public TLS port routes browsers to the room's private authoritative Godot process. */
export function attachGameGateway(server: Server, roomFor: (code: string) => Match | undefined,
  originAllowed: (origin?: string) => boolean) {
  let connections = 0;
  server.on('upgrade', (req: IncomingMessage, client: Duplex, initial: Buffer) => {
    if (req.url?.startsWith('/socket.io/')) return; // Socket.IO owns this upgrade.
    const code = /^\/game\/([A-Z2-9]{6})$/.exec(req.url || '')?.[1];
    const room = code ? roomFor(code) : undefined;
    const reject = (status: string) => client.end(`HTTP/1.1 ${status}\r\nConnection: close\r\nContent-Length: 0\r\n\r\n`);
    if (!originAllowed(req.headers.origin)) return void reject('403 Forbidden');
    if (!room?.port || room.phase !== 'match') return void reject('404 Not Found');
    if (connections >= 128) return void reject('503 Service Unavailable');
    connections++;
    let released = false;
    const release = () => { if (!released) { released = true; connections--; } };
    client.once('close', release);
    client.on('error', () => client.destroy());
    client.pause();
    // Never derive the upstream address or port from a client URL/header.
    const headers = { ...req.headers, host: `127.0.0.1:${room.port}` };
    delete headers.cookie;
    delete headers.authorization;
    const upstream = request({ hostname: '127.0.0.1', port: room.port, path: '/', headers, timeout: 5000 });
    upstream.on('upgrade', (response, stream, head) => {
      upstream.setTimeout(0);
      client.write(`HTTP/1.1 101 Switching Protocols\r\n${response.rawHeaders.reduce((s, h, i, a) => i % 2 === 0 ? s + h + ': ' + a[i + 1] + '\r\n' : s, '')}\r\n`);
      if (head.length) client.write(head);
      if (initial.length) stream.write(initial);
      stream.setNoDelay(true);
      stream.on('error', () => client.destroy());
      stream.on('close', () => client.destroy());
      client.on('close', () => stream.destroy());
      client.pipe(stream).pipe(client);
      client.resume();
    });
    upstream.on('response', () => { reject('502 Bad Gateway'); upstream.destroy(); });
    upstream.on('timeout', () => { client.destroy(); upstream.destroy(); });
    upstream.on('error', () => { client.destroy(); release(); });
    client.on('close', () => upstream.destroy());
    upstream.end();
  });
}
