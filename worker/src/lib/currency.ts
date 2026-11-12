import type { Client } from "pg";

export type Currency = { code: string; name: string; symbol: string; decimals: number };

/** Currencies an admin can set on a region. Symbols are shown before the amount. */
export const CURRENCIES: Record<string, Currency> = {
  NGN: { code: "NGN", name: "Nigerian naira", symbol: "₦", decimals: 2 },
  GHS: { code: "GHS", name: "Ghanaian cedi", symbol: "GH₵", decimals: 2 },
  XOF: { code: "XOF", name: "West African CFA franc", symbol: "CFA ", decimals: 0 },
  XAF: { code: "XAF", name: "Central African CFA franc", symbol: "FCFA ", decimals: 0 },
  GMD: { code: "GMD", name: "Gambian dalasi", symbol: "D", decimals: 2 },
  GNF: { code: "GNF", name: "Guinean franc", symbol: "FG ", decimals: 0 },
  LRD: { code: "LRD", name: "Liberian dollar", symbol: "L$", decimals: 2 },
  SLE: { code: "SLE", name: "Sierra Leonean leone", symbol: "Le ", decimals: 2 },
  MRU: { code: "MRU", name: "Mauritanian ouguiya", symbol: "UM ", decimals: 2 },
  CVE: { code: "CVE", name: "Cape Verdean escudo", symbol: "CVE ", decimals: 2 },
  KES: { code: "KES", name: "Kenyan shilling", symbol: "KSh ", decimals: 2 },
  ZAR: { code: "ZAR", name: "South African rand", symbol: "R", decimals: 2 },
  USD: { code: "USD", name: "US dollar", symbol: "$", decimals: 2 },
  GBP: { code: "GBP", name: "British pound", symbol: "£", decimals: 2 },
  EUR: { code: "EUR", name: "Euro", symbol: "€", decimals: 2 },
};

/** A user's phone country code decides the currency of their wallet. */
const DIAL: Record<string, string> = {
  "234": "NGN", "233": "GHS", "229": "XOF", "228": "XOF", "225": "XOF", "226": "XOF", "227": "XOF", "221": "XOF", "223": "XOF", "245": "XOF",
  "220": "GMD", "224": "GNF", "231": "LRD", "232": "SLE", "222": "MRU", "238": "CVE", "254": "KES", "27": "ZAR",
};

export const currencyForDial = (countryCode: string | null | undefined): string => DIAL[String(countryCode ?? "").replace(/\D/g, "")] ?? "NGN";

export const currencyInfo = (code: string | null | undefined): Currency => CURRENCIES[String(code ?? "NGN").toUpperCase()] ?? CURRENCIES.NGN;

/** The currency a user's wallet is (or will be) in. */
export async function userCurrency(db: Client, userId: number): Promise<string> {
  const w = (await db.query("select currency from app.wallets where user_id = $1 and kind = 'rider'", [userId])).rows[0];
  if (w?.currency) return String(w.currency).trim();
  const u = (await db.query("select country_code from app.users where id = $1", [userId])).rows[0];
  return currencyForDial(u?.country_code);
}
