-- Each person (rider or driver) works in one region at a time; they confirm a change when they cross a border.
alter table app.users add column if not exists region_id bigint references app.regions (id) on delete set null;
alter table app.users add column if not exists region_changed_at timestamptz;
create index if not exists users_region_idx on app.users (region_id) where region_id is not null;

-- Drivers start in the region of their ride type.
update app.users u set region_id = s.region_id
  from app.driver_profiles p join app.services s on s.id = p.service_id
 where p.user_id = u.id and u.region_id is null and s.region_id is not null;
