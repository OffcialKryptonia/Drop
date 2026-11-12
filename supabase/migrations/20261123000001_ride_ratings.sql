-- Passengers rate the driver after a completed ride (1 to 5 stars, optional comment).
create table app.ride_ratings (
  ride_request_id bigint primary key references app.ride_requests (id) on delete cascade,
  rider_id        bigint not null references app.users (id) on delete cascade,
  driver_id       bigint not null references app.users (id) on delete cascade,
  rating          int    not null check (rating between 1 and 5),
  comment         text,
  created_at      timestamptz not null default now()
);
create index ride_ratings_driver_idx on app.ride_ratings (driver_id);
alter table app.ride_ratings enable row level security;
