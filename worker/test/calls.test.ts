// Call provider tokens, no database or network. Run: npx tsx test/calls.test.ts
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { inflateSync } from "node:zlib";
import { agoraToken, livekitToken } from "../src/lib/call-tokens";

const b64u = (s: string) => Buffer.from(s.replace(/-/g, "+").replace(/_/g, "/"), "base64");

const tests: [string, () => void | Promise<void>][] = [
  ["a LiveKit token is a valid HS256 JWT for one room and one person", async () => {
    const t = await livekitToken({ apiKey: "APIkey1", apiSecret: "s3cret", room: "ride9-abc", identity: "42", name: "Ada", ttlSeconds: 900, now: 1_000_000 });
    const [h, p, sig] = t.split(".");
    assert.deepEqual(JSON.parse(b64u(h).toString()), { alg: "HS256", typ: "JWT" });
    const body = JSON.parse(b64u(p).toString());
    assert.equal(body.iss, "APIkey1");
    assert.equal(body.sub, "42");
    assert.equal(body.exp, 1_000_900);
    assert.equal(body.video.room, "ride9-abc");
    assert.equal(body.video.roomJoin, true);
    assert.equal(body.video.roomAdmin, undefined); // can join and talk, nothing more
    assert.equal(sig, createHmac("sha256", "s3cret").update(`${h}.${p}`).digest("base64url"));
  }],
  ["a LiveKit token signed with another secret does not verify", async () => {
    const t = await livekitToken({ apiKey: "k", apiSecret: "right", room: "r", identity: "1", ttlSeconds: 60 });
    const [h, p, sig] = t.split(".");
    assert.notEqual(sig, createHmac("sha256", "wrong").update(`${h}.${p}`).digest("base64url"));
  }],
  ["an Agora token has the 007 layout, the right channel and user, and a signature that verifies", async () => {
    const cert = "0123456789abcdef0123456789abcdef";
    const t = await agoraToken({ appId: "a".repeat(32), appCertificate: cert, channel: "ride9-abc", uid: "42", ttlSeconds: 900, now: 1_700_000_000, salt: 7 });
    assert.ok(t.startsWith("007"));
    const raw = inflateSync(Buffer.from(t.slice(3), "base64"));
    let o = 0;
    const u16 = () => { const v = raw.readUInt16LE(o); o += 2; return v; };
    const u32 = () => { const v = raw.readUInt32LE(o); o += 4; return v; };
    const str = () => { const n = u16(); const s = raw.subarray(o, o + n); o += n; return s; };
    const sig = str();
    const infoStart = o;
    assert.equal(str().toString(), "a".repeat(32));
    assert.equal(u32(), 1_700_000_000);
    assert.equal(u32(), 900);
    assert.equal(u32(), 7);
    assert.equal(u16(), 1); // one service
    assert.equal(u16(), 1); // RTC
    assert.equal(u16(), 2); // two privileges
    assert.equal(u16(), 1); u32(); // join channel
    assert.equal(u16(), 2); u32(); // publish audio
    assert.equal(str().toString(), "ride9-abc");
    assert.equal(str().toString(), "42");
    const k1 = createHmac("sha256", (() => { const b = Buffer.alloc(4); b.writeUInt32LE(1_700_000_000); return b; })()).update(cert).digest();
    const key = createHmac("sha256", (() => { const b = Buffer.alloc(4); b.writeUInt32LE(7); return b; })()).update(k1).digest();
    assert.equal(sig.toString("hex"), createHmac("sha256", key).update(raw.subarray(infoStart)).digest("hex"));
  }],
  ["Agora tokens for different people differ", async () => {
    const a = await agoraToken({ appId: "x".repeat(32), appCertificate: "c".repeat(32), channel: "r", uid: "1", ttlSeconds: 60, now: 5, salt: 1 });
    const b = await agoraToken({ appId: "x".repeat(32), appCertificate: "c".repeat(32), channel: "r", uid: "2", ttlSeconds: 60, now: 5, salt: 1 });
    assert.notEqual(a, b);
  }],
];

let failed = 0;
for (const [name, fn] of tests) {
  try { await fn(); console.log("ok  ", name); } catch (e) { failed++; console.log("FAIL", name, "\n    ", (e as Error).message); }
}
if (failed) process.exit(1);
