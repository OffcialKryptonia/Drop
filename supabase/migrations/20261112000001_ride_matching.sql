-- Matching: a driver can be on only one ride at a time; drivers can decline a request (it is hidden from them).
create unique index ride_requests_one_open_per_driver on app.ride_requests (driver_id)
  where driver_id is not null and status in ('accepted', 'arrived', 'in_progress');

create table app.ride_request_declines (
  request_id bigint not null references app.ride_requests (id) on delete cascade,
  driver_id  bigint not null references app.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (request_id, driver_id)
);
alter table app.ride_request_declines enable row level security;

insert into app.settings (key, value) values ('driver_location_stale_minutes', '10'::jsonb)
  on conflict (key) do nothing;
