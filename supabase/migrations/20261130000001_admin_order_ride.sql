-- Track Admin-initiated ride bookings without changing the existing ride lifecycle.
alter table app.ride_requests
  add column if not exists booking_source text not null default 'passenger',
  add column if not exists booked_by_admin_id bigint references app.users (id) on delete set null,
  add column if not exists admin_booking_key text;

alter table app.ride_requests
  add constraint ride_requests_booking_source_check
  check (booking_source in ('passenger', 'admin'));

alter table app.ride_requests
  drop constraint if exists ride_requests_cancelled_by_check;
alter table app.ride_requests
  add constraint ride_requests_cancelled_by_check
  check (cancelled_by in ('rider', 'driver', 'system', 'admin'));

create unique index if not exists ride_requests_admin_booking_key_unique
  on app.ride_requests (admin_booking_key) where admin_booking_key is not null;

create index if not exists ride_requests_admin_source_idx
  on app.ride_requests (created_at desc) where booking_source = 'admin';
