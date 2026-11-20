// Pure chat helpers, no database. Run: npx tsx test/chat.test.ts
import assert from "node:assert/strict";
import { audioToken, audioTokenValid, sniffAudio, messageView } from "../src/lib/chat";

const secret = "k".repeat(40);
const tests: [string, () => void | Promise<void>][] = [
  ["m4a, ogg, webm and mp3 recordings are recognised by their bytes", () => {
    assert.equal(sniffAudio(Uint8Array.from([0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, 0x4d, 0x34, 0x41, 0x20, 0, 0]))?.type, "audio/mp4");
    assert.equal(sniffAudio(Uint8Array.from([0x4f, 0x67, 0x67, 0x53, 0, 2]))?.type, "audio/ogg");
    assert.equal(sniffAudio(Uint8Array.from([0x1a, 0x45, 0xdf, 0xa3, 0, 0]))?.type, "audio/webm");
    assert.equal(sniffAudio(Uint8Array.from([0x49, 0x44, 0x33, 4, 0, 0]))?.type, "audio/mpeg");
  }],
  ["pictures, documents and scripts are refused", () => {
    assert.equal(sniffAudio(Uint8Array.from([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0, 0, 0, 0, 0, 0])), null);
    assert.equal(sniffAudio(new TextEncoder().encode("<script>alert(1)</script>")), null);
    assert.equal(sniffAudio(Uint8Array.from([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x34, 0, 0, 0, 0, 0])), null);
  }],
  ["an audio link works for its own person and message only", async () => {
    const t = await audioToken(secret, 7, 42);
    assert.equal(await audioTokenValid(secret, 7, 42, t.exp, t.sig), true);
    assert.equal(await audioTokenValid(secret, 8, 42, t.exp, t.sig), false); // another message
    assert.equal(await audioTokenValid(secret, 7, 43, t.exp, t.sig), false); // another person
    assert.equal(await audioTokenValid("z".repeat(40), 7, 42, t.exp, t.sig), false); // another secret
  }],
  ["an expired or tampered audio link is refused", async () => {
    const t = await audioToken(secret, 7, 42);
    assert.equal(await audioTokenValid(secret, 7, 42, t.exp - 700, t.sig), false);
    assert.equal(await audioTokenValid(secret, 7, 42, t.exp, t.sig.slice(0, -1) + (t.sig.endsWith("a") ? "b" : "a")), false);
  }],
  ["a message never carries the storage key, and 'mine' follows the sender", () => {
    const v = messageView({ id: 5, kind: "voice", audio_key: "chat/1/secret.m4a", audio_seconds: 12, waveform: [1, 2], sender_id: 42, client_id: "abc12345", created_at: "x" }, 42);
    assert.equal(v.mine, true);
    assert.equal(JSON.stringify(v).includes("secret"), false);
    assert.equal(messageView({ id: 6, kind: "text", body: "hi", sender_id: 9, client_id: "abc12345" }, 42).mine, false);
  }],
];
let failed = 0;
for (const [name, fn] of tests) {
  try { await fn(); console.log("ok -", name); } catch (e) { failed++; console.log("FAIL -", name, (e as Error).message); }
}
if (failed) process.exit(1);
