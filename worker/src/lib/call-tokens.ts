/**
 * Short-lived join tokens for the two calling providers. The provider secrets never leave the Worker:
 * the app only ever receives a token that is valid for one room, one person and a few minutes.
 */

const enc = new TextEncoder();
const b64url = (b: ArrayBuffer | Uint8Array) =>
  btoa(String.fromCharCode(...new Uint8Array(b))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

async function hmac(key: ArrayBuffer | Uint8Array | string, data: ArrayBuffer | Uint8Array | string): Promise<ArrayBuffer> {
  const k = await crypto.subtle.importKey("raw", typeof key === "string" ? enc.encode(key) : key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return crypto.subtle.sign("HMAC", k, typeof data === "string" ? enc.encode(data) : data);
}

// ---------------------------------------------------------------- LiveKit

/** A LiveKit access token (JWT, HS256): may join exactly one room and publish/subscribe audio. */
export async function livekitToken(o: { apiKey: string; apiSecret: string; room: string; identity: string; name?: string; ttlSeconds: number; now?: number }): Promise<string> {
  const now = o.now ?? Math.floor(Date.now() / 1000);
  const header = b64url(enc.encode(JSON.stringify({ alg: "HS256", typ: "JWT" })));
  const payload = b64url(enc.encode(JSON.stringify({
    iss: o.apiKey, sub: o.identity, name: o.name ?? o.identity, nbf: now, iat: now, exp: now + o.ttlSeconds,
    video: { room: o.room, roomJoin: true, canPublish: true, canSubscribe: true, canPublishData: false },
  })));
  const sig = b64url(await hmac(o.apiSecret, `${header}.${payload}`));
  return `${header}.${payload}.${sig}`;
}

// ------------------------------------------------------------------ Agora

const u16 = (n: number) => { const b = new Uint8Array(2); new DataView(b.buffer).setUint16(0, n, true); return b; };
const u32 = (n: number) => { const b = new Uint8Array(4); new DataView(b.buffer).setUint32(0, n >>> 0, true); return b; };
const str = (s: string) => { const d = enc.encode(s); return cat(u16(d.length), d); };
const cat = (...p: Uint8Array[]) => { const o = new Uint8Array(p.reduce((a, b) => a + b.length, 0)); let i = 0; for (const x of p) { o.set(x, i); i += x.length; } return o; };

async function zlib(data: Uint8Array): Promise<Uint8Array> {
  const cs = new CompressionStream("deflate"); // "deflate" is the zlib wrapper, which is what Agora expects
  const w = cs.writable.getWriter();
  void w.write(data); void w.close();
  return new Uint8Array(await new Response(cs.readable).arrayBuffer());
}

/**
 * An Agora "AccessToken2" (007) for one RTC channel and user. It can join and publish audio only.
 * `salt` and `now` are injectable so the output is reproducible in tests.
 */
export async function agoraToken(o: { appId: string; appCertificate: string; channel: string; uid: string; ttlSeconds: number; now?: number; salt?: number }): Promise<string> {
  const issue = o.now ?? Math.floor(Date.now() / 1000);
  const salt = o.salt ?? crypto.getRandomValues(new Uint32Array(1))[0];
  const expire = o.ttlSeconds; // Agora stores the lifetime in seconds, counted from the issue time
  const k1 = await hmac(u32(issue), o.appCertificate);
  const key = await hmac(u32(salt), k1);
  // RTC service: type 1, privileges {join:1, publish audio:2}, channel, uid
  const service = cat(u16(1), u16(2), u16(1), u32(expire), u16(2), u32(expire), str(o.channel), str(o.uid));
  const info = cat(str(o.appId), u32(issue), u32(expire), u32(salt), u16(1), service);
  const signature = new Uint8Array(await hmac(key, info));
  const body = await zlib(cat(u16(signature.length), signature, info));
  return "007" + btoa(String.fromCharCode(...body));
}
