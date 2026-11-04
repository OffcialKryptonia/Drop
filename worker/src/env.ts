import type { Client } from "pg";

export type Bindings = {
  ASSETS: Fetcher;
  HYPERDRIVE: Hyperdrive;
};

/** The signed-in user, as loaded by the auth middleware (no secrets). */
export type AuthUser = {
  id: number;
  user_type: string;
  status: string;
  email: string;
  [column: string]: unknown;
};

export type Variables = {
  db: Client;
  user: AuthUser;
  tokenId: number;
};

export type AppEnv = { Bindings: Bindings; Variables: Variables };
