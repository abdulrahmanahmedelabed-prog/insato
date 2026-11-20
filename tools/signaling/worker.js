// Insato live-call signaling relay for Cloudflare Workers (free plan).
//
// Same protocol as tools/signaling_server.dart (the tested reference):
// each room id (a one-way hash of the call code, also passed as ?room=)
// is served by one Durable Object that pairs at most two WebSockets and
// forwards opaque sealed blobs between them. Nothing is stored; the
// relay cannot read or forge the messages.
//
// Deploy: see docs/SETUP.md («مكالمة إنصاتو الحية»):
//   npm i -g wrangler && wrangler login && wrangler deploy
// then put wss://<name>.<account>.workers.dev in Insato's settings.

const ROOM = /^[0-9a-f]{64}$/;
const MAX_FRAME = 96 * 1024;

export default {
  async fetch(request, env) {
    if (request.headers.get('Upgrade') !== 'websocket') {
      return new Response('Insato signaling relay: ok\n', {
        headers: { 'content-type': 'text/plain' },
      });
    }
    const room = new URL(request.url).searchParams.get('room') || '';
    if (!ROOM.test(room)) return new Response('bad room', { status: 400 });
    const stub = env.ROOMS.get(env.ROOMS.idFromName(room));
    return stub.fetch(request);
  },
};

export class Room {
  constructor(state, env) {
    this.clients = [];
  }

  async fetch(request) {
    const room = new URL(request.url).searchParams.get('room');
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();
    const c = { ws: server, joined: false, frames: 0, windowStart: Date.now() };
    const send = (x, frame) => {
      try {
        x.ws.send(JSON.stringify(frame));
      } catch (_) {}
    };
    const drop = (x) => {
      const i = this.clients.indexOf(x);
      if (i >= 0) {
        this.clients.splice(i, 1);
        for (const o of this.clients) send(o, { t: 'peer', ev: 'leave' });
      }
      try {
        x.ws.close(1000, 'bye');
      } catch (_) {}
    };
    const fail = (x, code) => {
      send(x, { t: 'error', code });
      drop(x);
    };
    const joinTimer = setTimeout(() => {
      if (!c.joined) fail(c, 'bad');
    }, 10000);
    server.addEventListener('message', (ev) => {
      const data = ev.data;
      if (typeof data !== 'string') return fail(c, 'bad');
      if (data.length > MAX_FRAME) return fail(c, 'size');
      const now = Date.now();
      if (now - c.windowStart > 10000) {
        c.windowStart = now;
        c.frames = 0;
      }
      if (++c.frames > 200) return fail(c, 'rate');
      let j;
      try {
        j = JSON.parse(data);
      } catch (_) {
        return fail(c, 'bad');
      }
      if (!j || typeof j !== 'object') return fail(c, 'bad');
      switch (j.t) {
        case 'join': {
          if (c.joined || j.room !== room) return fail(c, 'bad');
          if (this.clients.length >= 2) return fail(c, 'full');
          c.joined = true;
          clearTimeout(joinTimer);
          for (const o of this.clients) send(o, { t: 'peer', ev: 'join' });
          send(c, { t: 'joined', peers: this.clients.length });
          this.clients.push(c);
          break;
        }
        case 'relay':
          if (!c.joined || typeof j.d !== 'string') return fail(c, 'bad');
          for (const o of this.clients) if (o !== c) send(o, { t: 'relay', d: j.d });
          break;
        case 'ping':
          send(c, { t: 'pong' });
          break;
        case 'pong':
          break;
        default:
          return fail(c, 'bad');
      }
    });
    server.addEventListener('close', () => drop(c));
    server.addEventListener('error', () => drop(c));
    return new Response(null, { status: 101, webSocket: client });
  }
}
