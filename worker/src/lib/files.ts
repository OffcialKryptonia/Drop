/** What we accept for driver documents and photos, judged by the file itself and never by its name or header. */
export type Sniffed = { type: "image/jpeg" | "image/png" | "image/webp" | "application/pdf"; ext: "jpg" | "png" | "webp" | "pdf" };

export const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

export function sniff(b: Uint8Array): Sniffed | null {
  const at = (i: number, ...v: number[]) => v.every((x, k) => b[i + k] === x);
  if (at(0, 0xff, 0xd8, 0xff)) return { type: "image/jpeg", ext: "jpg" };
  if (at(0, 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)) return { type: "image/png", ext: "png" };
  if (at(0, 0x52, 0x49, 0x46, 0x46) && at(8, 0x57, 0x45, 0x42, 0x50)) return { type: "image/webp", ext: "webp" };
  if (at(0, 0x25, 0x50, 0x44, 0x46)) return { type: "application/pdf", ext: "pdf" };
  return null;
}

/** A random, unguessable object name inside the person's own folder. */
export const newKey = (folder: string, label: string, ext: string) => `${folder}/${label}-${crypto.randomUUID()}.${ext}`;
