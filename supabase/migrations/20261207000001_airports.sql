-- Airport transfers: Admin-managed airports, airport price rules, and airport details on a ride.
-- Nothing here is seeded. Airports (including ABV) are added in Admin with details the operator has verified.

-- "Airport transfers" is its own booking mode on a ride type. Ride types without it never appear for airport trips,
-- and airport-only ride types (no 'now') never appear for ordinary rides.
alter table app.services drop constraint if exists services_booking_modes_valid;
alter table app.services add constraint services_booking_modes_valid
  check (booking_modes <@ array['now','scheduled','multi_drop','bidding','for_other','airport']);

create table app.airports (
  id                 bigserial primary key,
  region_id          bigint not null references app.regions (id),
  name               text not null check (length(btrim(name)) between 2 and 120),
  iata_code          text check (iata_code is null or iata_code ~ '^[A-Z]{3}$'),
  icao_code          text check (icao_code is null or icao_code ~ '^[A-Z]{4}$'),
  latitude           double precision check (latitude between -90 and 90),
  longitude          double precision check (longitude between -180 and 180),
  location           extensions.geography(Point, 4326),
  geofence           extensions.geography(Polygon, 4326),       -- optional drawn boundary of the airport area
  geofence_coordinates jsonb,                                   -- the points the admin drew, for editing
  radius_m           integer check (radius_m is null or radius_m between 100 and 20000),  -- used when there is no geofence
  terminals          jsonb not null default '[]'::jsonb,        -- [{"name": "..."}], entered by the operator
  pickup_instructions text check (pickup_instructions is null or length(pickup_instructions) <= 1000),
  default_surcharge  numeric(12,2) not null default 0 check (default_surcharge >= 0),
  status             boolean not null default false,            -- inactive until the operator has finished and verified it
  deleted_at         timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  -- An airport cannot be switched on until its position and its area are known.
  constraint airports_active_needs_geo check (not status or (location is not null and (geofence is not null or radius_m is not null)))
);
create unique index airports_iata_uq on app.airports (iata_code) where iata_code is not null and deleted_at is null;
create index airports_region_idx on app.airports (region_id) where deleted_at is null;
create index airports_geofence_gix on app.airports using gist (geofence);
create index airports_location_gix on app.airports using gist (location);
alter table app.airports enable row level security;

-- Price rules. The most specific matching rule wins (see worker/src/lib/airports.ts):
--   ride type + direction  >  ride type, any direction  >  any ride type + direction  >  any ride type, any direction
-- and with no rule the ride type's normal distance/time formula applies plus the airport's default surcharge.
create table app.airport_prices (
  id          bigserial primary key,
  airport_id  bigint not null references app.airports (id) on delete cascade,
  service_id  bigint references app.services (id),              -- null = every airport ride type
  direction   text check (direction in ('drop','pickup')),      -- null = both directions
  mode        text not null check (mode in ('fixed','standard')),
  fixed_price numeric(12,2) check (fixed_price is null or fixed_price >= 0),
  surcharge   numeric(12,2) not null default 0 check (surcharge >= 0),
  status      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint airport_prices_fixed_needs_price check (mode <> 'fixed' or fixed_price is not null)
);
create unique index airport_prices_uq on app.airport_prices (airport_id, coalesce(service_id, 0), coalesce(direction, '*'));
alter table app.airport_prices enable row level security;

-- Airport details on a normal ride. Same lifecycle, wallet, commission and receipts as any other ride.
alter table app.ride_requests
  add column airport_id        bigint references app.airports (id),
  add column airport_direction text check (airport_direction in ('drop','pickup')),
  add column flight            jsonb;
create index ride_requests_airport_idx on app.ride_requests (airport_id) where airport_id is not null;
