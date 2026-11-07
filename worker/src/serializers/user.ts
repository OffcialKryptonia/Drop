import { coordText, flag, laravelTime, num } from "../lib/legacy";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Row = Record<string, any>;

/**
 * The signed-in user's own view. Matches the legacy login/register payload, so the
 * apps' UserModel.fromJson keeps working: flags are 0/1, coordinates are strings,
 * timestamps are Laravel ISO strings.
 */
export function serializeUser(u: Row) {
  return {
    id: u.id,
    first_name: u.first_name,
    last_name: u.last_name,
    display_name: u.display_name,
    email: u.email,
    username: u.username,
    status: u.status,
    user_type: u.user_type,
    roles: u.roles ?? [],
    active_mode: u.active_mode ?? "rider",
    driver_status: u.driver_status ?? null,
    address: u.address,
    country_code: u.country_code,
    contact_number: u.contact_number,
    gender: u.gender,
    profile_image: null as string | null, // file storage (R2) arrives with the uploads migration
    login_type: u.login_type,
    latitude: coordText(u.latitude),
    longitude: coordText(u.longitude),
    uid: u.uid,
    player_id: u.player_id,
    fcm_token: u.fcm_token,
    is_online: flag(u.is_online),
    is_available: flag(u.is_available),
    is_verified_driver: flag(u.is_verified_driver),
    timezone: u.timezone,
    fleet_id: u.fleet_id ?? null,
    service_id: u.service_id ?? null,
    email_verified_at: laravelTime(u.email_verified_at),
    otp_verify_at: laravelTime(u.otp_verify_at),
    last_notification_seen: laravelTime(u.last_notification_seen),
    last_location_update_at: laravelTime(u.last_location_update_at),
    last_actived_at: laravelTime(u.last_actived_at),
    referral_code: u.referral_code,
    partner_referral_code: u.partner_referral_code,
    currentHeading: u.current_heading ?? null,
    total_coins: u.total_coins,
    created_at: laravelTime(u.created_at),
    updated_at: laravelTime(u.updated_at),
  };
}

/**
 * What another user may see (a rider looking at their driver and vice versa): no email,
 * address, push tokens, referral data, coins or bank details.
 */
export function serializePublicUser(u: Row) {
  return {
    id: u.id,
    first_name: u.first_name,
    last_name: u.last_name,
    display_name: u.display_name,
    username: u.username,
    status: u.status,
    user_type: u.user_type,
    country_code: u.country_code,
    contact_number: u.contact_number,
    gender: u.gender,
    profile_image: null as string | null,
    login_type: u.login_type,
    latitude: coordText(u.latitude),
    longitude: coordText(u.longitude),
    uid: u.uid,
    is_online: flag(u.is_online),
    is_available: flag(u.is_available),
    is_verified_driver: flag(u.is_verified_driver),
    timezone: u.timezone,
    service_id: u.service_id ?? null,
    currentHeading: u.current_heading ?? null,
    created_at: laravelTime(u.created_at),
    updated_at: laravelTime(u.updated_at),
  };
}

export function serializeUserDetail(d: Row | undefined) {
  if (!d) return null;
  return {
    id: d.id,
    user_id: d.user_id,
    car_model: d.car_model,
    car_color: d.car_color,
    car_plate_number: d.car_plate_number,
    car_production_year: d.car_production_year,
    work_address: d.work_address,
    home_address: d.home_address,
    work_latitude: coordText(d.work_latitude),
    work_longitude: coordText(d.work_longitude),
    home_latitude: coordText(d.home_latitude),
    home_longitude: coordText(d.home_longitude),
    created_at: laravelTime(d.created_at),
    updated_at: laravelTime(d.updated_at),
  };
}

export function serializeBankAccount(b: Row | undefined) {
  if (!b) return null;
  return {
    id: b.id,
    user_id: b.user_id,
    bank_name: b.bank_name,
    bank_code: b.bank_code,
    account_holder_name: b.account_holder_name,
    account_number: b.account_number,
    bank_address: b.bank_address,
    routing_number: b.routing_number,
    bank_iban: b.bank_iban,
    bank_swift: b.bank_swift,
    created_at: laravelTime(b.created_at),
    updated_at: laravelTime(b.updated_at),
  };
}

export function serializeService(s: Row | undefined) {
  if (!s) return null;
  return {
    id: s.id,
    name: s.name,
    region_id: s.region_id,
    capacity: s.capacity,
    base_fare: num(s.base_fare),
    minimum_fare: num(s.minimum_fare),
    minimum_distance: num(s.minimum_distance),
    per_distance: num(s.per_distance),
    per_minute_drive: num(s.per_minute_drive),
    per_minute_wait: num(s.per_minute_wait),
    waiting_time_limit: num(s.waiting_time_limit),
    cancellation_fee: num(s.cancellation_fee),
    payment_method: s.payment_method,
    commission_type: s.commission_type,
    admin_commission: num(s.admin_commission),
    fleet_commission: num(s.fleet_commission),
    status: flag(s.status),
    description: s.description,
    created_at: laravelTime(s.created_at),
    updated_at: laravelTime(s.updated_at),
  };
}

export function serializeDocument(d: Row) {
  return {
    id: d.id,
    name: d.name,
    type: d.type,
    is_required: flag(d.is_required),
    has_expiry_date: flag(d.has_expiry_date),
    status: flag(d.status),
    created_at: laravelTime(d.created_at),
    updated_at: laravelTime(d.updated_at),
  };
}
