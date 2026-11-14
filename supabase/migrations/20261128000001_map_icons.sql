-- Vehicle icons drawn on the map. Six built-in keys fall back to icons bundled in the app;
-- an admin can upload a replacement for any key, or add extra custom icons.
create table if not exists app.map_icons (
  key          text primary key check (key ~ '^[a-z0-9_]{2,40}$'),
  label        text not null,
  builtin      boolean not null default false,
  file_key     text,
  content_type text,
  version      integer not null default 1,
  updated_at   timestamptz not null default now()
);
insert into app.map_icons (key, label, builtin) values
  ('car', 'Car', true), ('bike', 'Bike', true), ('keke', 'Tricycle (Keke)', true),
  ('van', 'Van', true), ('car_dispatch', 'Car (dispatch)', true), ('bike_dispatch', 'Bike (dispatch)', true)
on conflict (key) do nothing;
alter table app.services add column if not exists map_icon_key text references app.map_icons (key) on update cascade on delete set null;
alter table app.map_icons enable row level security;
