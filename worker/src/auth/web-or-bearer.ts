import type { MiddlewareHandler } from "hono";
import type { AppEnv } from "../env";
import { unauthenticated } from "../lib/legacy";
import {
  CSRF_HEADER,
  fetchMetadataAllowed,
  originAllowed,
  parseSessionCookie,
  safeEqual,
  sessionCsrf,
  validateSession,
} from "../lib/web-session";
import { requireAuth } from "./middleware";

/**
 * Accepts the existing Flutter Bearer token or a browser cookie session.
 * Bearer authentication remains delegated to the original middleware.
 */
export const requireWebOrBearer: MiddlewareHandler<AppEnv> = async (c, next) => {
  // Preserve existing mobile authentication exactly as it is.
  if (c.req.header("authorization")) {
    return requireAuth(c, next);
  }

  const secret = c.env.SESSION_SECRET;
  if (!secret || secret.length < 32) {
    return c.json({ error: "session_unconfigured" }, 503);
  }

  const parsed = parseSessionCookie(c);
  if (!parsed) return unauthenticated(c);

  const session = await validateSession(c.get("db"), parsed);
  if (!session) return unauthenticated(c);

  // Browser cookie sessions require origin and CSRF validation on mutations.
  if (!["GET", "HEAD", "OPTIONS"].includes(c.req.method.toUpperCase())) {
    if (!originAllowed(c) || !fetchMetadataAllowed(c)) {
      return c.json({ error: "csrf_invalid" }, 403);
    }

    const supplied = c.req.header(CSRF_HEADER) ?? "";
    const expected = await sessionCsrf(secret, session.tokenId);
    if (!supplied || !safeEqual(supplied, expected)) {
      return c.json({ error: "csrf_invalid" }, 403);
    }
  }

  c.set("user", session.user);
  c.set("tokenId", session.tokenId);
  await next();
};
