import pg from "pg";
import type { MiddlewareHandler } from "hono";
import type { AppEnv } from "./env";

const { Client, types } = pg;

/**
 * Postgres returns bigint (int8) and date as strings. The legacy API (and the Flutter
 * apps) expect numeric ids and plain "YYYY-MM-DD" dates, so parse them accordingly.
 * Ids stay far below 2^53, so Number() is exact.
 */
const typeParsers = {
  getTypeParser: (oid: number, format?: "text" | "binary") => {
    if (oid === 20) return (value: string) => Number(value); // int8
    if (oid === 1082) return (value: string) => value; // date
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return types.getTypeParser(oid as any, (format ?? "text") as any);
  },
};

/** Opens one connection (through Hyperdrive, which pools the real ones). */
export async function connectDb(connectionString: string): Promise<pg.Client> {
  const client = new Client({
    connectionString,
    types: typeParsers,
  });
  await client.connect();
  return client;
}

/**
 * One Postgres connection for the request, closed afterwards. Only routes that need the
 * database use this middleware, so /api/health stays free.
 */
export const withDb: MiddlewareHandler<AppEnv> = async (c, next) => {
  const client = await connectDb(c.env.HYPERDRIVE.connectionString);
  c.set("db", client);
  try {
    await next();
  } finally {
    c.executionCtx.waitUntil(client.end().catch(() => undefined));
  }
};

/** Postgres error codes we translate into friendly API errors. */
export const UNIQUE_VIOLATION = "23505";
export const FOREIGN_KEY_VIOLATION = "23503";
