import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { serializeService } from "../serializers/user";

/**
 * Compatibility endpoints for the screens that still call the old (Mighty-era) API names.
 * Each one returns the exact shape the app parses, so a screen shows a normal empty
 * state ("nothing here yet") instead of the "Requested service is not available" error.
 * Real implementations replace these one by one as each feature is rebuilt.
 */
export const legacyRoutes = new Hono<AppEnv>();

const CURRENCY = { name: "Nigerian Naira", code: "NGN", symbol: "₦", position: "left" };

const emptyPage = (c: { req: { query: (k: string) => string | undefined } }) => ({
  data: [] as unknown[],
  pagination: { currentPage: Number(c.req.query("page")) || 1, per_page: 20, totalPages: 1, total_items: 0 },
});

/** App-wide settings: currency (₦) and the feature switches the apps read. */
const settings = async (c: any) =>
  c.json({
    app_seeting: {},
    ride_setting: [],
    Wallet_setting: [],
    currency_setting: CURRENCY,
    privacy_policy: null,
    terms_condition: null,
    reference_amount: "0",
    reference_type: "fixed",
    maxEarningPerMonth: "0",
  });
legacyRoutes.get("/admin-dashboard", settings);
legacyRoutes.get("/appsetting", settings);

/** Home-screen poll. The new ride flow uses /ride/current, so there is nothing legacy to return. */
legacyRoutes.get("/current-riderequest", withDb, requireAuth, (c) => {
  const me = c.get("user");
  return c.json({
    id: me.id, display_name: me.display_name ?? null, email: me.email ?? null, username: me.username ?? null,
    user_type: me.user_type, all_unread_count: 0, ride_has_bids: false,
    ride_request: null, on_ride_request: null, schedule_ride_request: [],
  });
});

/** Ride types, admin-managed. */
legacyRoutes.get("/service-list", withDb, requireAuth, async (c) => {
  const rows = (await c.get("db").query("select * from app.services where status and deleted_at is null order by sort_order, id")).rows;
  return c.json({ data: rows.map(serializeService) });
});

/** Lists that are empty until their feature is rebuilt. */
for (const path of [
  "/faq-list", "/coupon-list", "/notification-list", "/reward-list", "/reference-list",
  "/complaintcomment-list", "/managezone-list", "/additional-fees-list", "/airport-list",
  "/earning-list", "/withdrawrequest-list", "/coin-wallet-list", "/driver-rating-list",
  "/rider-rating-list", "/cancelReason-list", "/language-table-list", "/document-list",
  "/driver-document-list", "/driver-payout-document-list",
]) {
  legacyRoutes.get(path, withDb, requireAuth, (c) => c.json(emptyPage(c)));
  legacyRoutes.post(path, withDb, requireAuth, (c) => c.json(emptyPage(c)));
}
