-- Road routes can now also come from OpenStreetMap routing (OSRM).
alter table app.ride_requests drop constraint if exists ride_requests_route_source_check;
alter table app.ride_requests add constraint ride_requests_route_source_check check (route_source in ('google', 'osrm', 'estimate'));

insert into app.settings (key, value) values
  ('map_provider', '"auto"'::jsonb),
  ('osm_tile_url', '"https://tile.openstreetmap.org/{z}/{x}/{y}.png"'::jsonb),
  ('osm_routing_url', '"https://router.project-osrm.org"'::jsonb)
on conflict (key) do nothing;
