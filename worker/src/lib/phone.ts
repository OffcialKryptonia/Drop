/**
 * The part of a phone number after the country code, without the leading 0. Apps sometimes send the number with the
 * country code already in it (e.g. "+234" + "+2348136320187"); that must not be saved twice.
 */
export function nationalNumber(countryCode: string | null | undefined, raw: string): string {
  const cc = String(countryCode ?? "").replace(/\D/g, "");
  let d = String(raw ?? "").replace(/\D/g, "");
  if (cc) while (d.startsWith(cc) && d.length - cc.length >= 8) d = d.slice(cc.length);
  return d.replace(/^0+/, "");
}
