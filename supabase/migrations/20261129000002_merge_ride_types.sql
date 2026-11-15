-- One ride-type catalogue. The admin's own types (region Kogi) were being shown while the starter set (region Abuja)
-- sat unused, because a region with no boundary matches first by id. Everything now lives in region 1.
--   Regular  -> DROP Go    (fares, commission, booking modes and status of Regular carry over; rides, driver and documents move)
--   Keke(3)  -> DROP Keke  (the admin's fares carry over)
--   Hourly -> Hire, Delivery -> Courier, Bike -> Okada. The duplicate Comfort is retired; the admin's Comfort stays.
-- Retired rows are soft-deleted (deleted_at), never removed, so old rides still resolve.
do $$
declare reg bigint := 1;
begin
  -- DROP Go takes over Regular's settings
  update app.services t set
      region_id = reg, name = 'DROP Go', status = s.status, capacity = s.capacity,
      base_fare = s.base_fare, minimum_fare = s.minimum_fare, minimum_distance = s.minimum_distance, per_distance = s.per_distance,
      per_minute_drive = s.per_minute_drive, per_minute_wait = s.per_minute_wait, waiting_time_limit = s.waiting_time_limit,
      cancellation_fee = s.cancellation_fee, payment_method = s.payment_method, commission_type = s.commission_type,
      admin_commission = s.admin_commission, fleet_commission = s.fleet_commission, description = s.description,
      booking_modes = s.booking_modes, payment_methods = s.payment_methods, badge = s.badge,
      min_driver_rating = s.min_driver_rating, min_wallet_balance = s.min_wallet_balance, working_hours = s.working_hours,
      map_icon_key = coalesce(t.map_icon_key, s.map_icon_key)
    from app.services s where t.id = 6 and s.id = 1;
  update app.ride_requests   set service_id = 6 where service_id = 1;
  update app.driver_profiles set service_id = 6 where service_id = 1;
  update app.driver_services set service_id = 6 where service_id = 1;
  update app.users           set service_id = 6 where service_id = 1;
  insert into app.document_requirements (document_id, service_id)
    select document_id, 6 from app.document_requirements where service_id = 1 on conflict do nothing;
  delete from app.document_requirements where service_id = 1;
  update app.services set status = false, deleted_at = now() where id = 1;

  -- DROP Keke takes over the admin's Keke
  update app.services t set
      region_id = reg, name = 'DROP Keke', status = s.status, capacity = s.capacity,
      base_fare = s.base_fare, minimum_fare = s.minimum_fare, minimum_distance = s.minimum_distance, per_distance = s.per_distance,
      per_minute_drive = s.per_minute_drive, per_minute_wait = s.per_minute_wait, waiting_time_limit = s.waiting_time_limit,
      cancellation_fee = s.cancellation_fee, payment_method = s.payment_method, commission_type = s.commission_type,
      admin_commission = s.admin_commission, fleet_commission = s.fleet_commission, map_icon_key = 'keke'
    from app.services s where t.id = 11 and s.id = 3;
  update app.ride_requests   set service_id = 11 where service_id = 3;
  update app.driver_profiles set service_id = 11 where service_id = 3;
  update app.driver_services set service_id = 11 where service_id = 3;
  update app.users           set service_id = 11 where service_id = 3;
  insert into app.document_requirements (document_id, service_id)
    select document_id, 11 from app.document_requirements where service_id = 3 on conflict do nothing;
  delete from app.document_requirements where service_id = 3;
  update app.services set status = false, deleted_at = now() where id = 3;

  -- the starter Comfort duplicates the admin's Comfort (id 2)
  update app.services set status = false, deleted_at = now() where id = 7;

  -- renames
  update app.services set name = 'DROP Okada',   description = 'Motorcycle taxi that beats traffic. Check local rules before enabling.' where id = 10;
  update app.services set name = 'DROP Hire'    where id = 15;
  update app.services set name = 'DROP Courier' where id = 14;

  -- the rest of the starter set joins the same region, order of the list in the app
  update app.services set region_id = reg where id in (8, 9, 10, 12, 13, 14, 15, 16, 17);
  update app.services s set sort_order = o.n from (values
    (6, 1), (2, 2), (11, 3), (10, 4), (4, 5), (15, 6), (16, 7), (17, 8), (5, 9), (14, 10), (8, 11), (9, 12), (12, 13), (13, 14)
  ) as o(id, n) where s.id = o.id;
end $$;
