import type { Client } from "pg";

export type Bindings = {
  ASSETS: Fetcher;
  HYPERDRIVE: Hyperdrive;
  /** R2 bucket for driver documents and photos. Not bound yet = uploads answer 503. */
  DOCS?: R2Bucket;
  /** Any long random phrase (32+ chars). Encrypts gateway credentials stored in the database. */
  SETTINGS_ENCRYPTION_KEY?: string;
  /** Lets the very first admin be created; unset it (or leave it) once an admin exists. */
  ADMIN_BOOTSTRAP_TOKEN?: string;
  /** Tests only: points Pocketfi calls at a local mock instead of api.pocketfi.ng. Leave unset in production. */
  POCKETFI_BASE_URL?: string;
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
