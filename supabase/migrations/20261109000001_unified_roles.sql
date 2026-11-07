-- One app, two modes. A person has roles (rider, driver) and an active mode; a driver profile holds the
-- application and its review status. A person who is both keeps TWO wallets (rider and driver/commission),
-- so each balance has its own ledger for accountability.

-- ---------------------------------------------------------------------------
-- Roles and mode
-- ---------------------------------------------------------------------------
alter table app.users
  add column roles       text[] not null default array['rider'],
  add column active_mode text   not null default 'rider';
alter table app.users
  add constraint users_roles_valid  check (roles <@ array['rider', 'driver']),
  add constraint users_mode_valid   check (active_mode in ('rider', 'driver'));

update app.users set roles = array['rider', 'driver'], active_mode = 'driver' where user_type = 'driver';
update app.users set roles = '{}' where user_type in ('admin', 'fleet');

-- ---------------------------------------------------------------------------
-- Driver profile: the application and its review
-- ---------------------------------------------------------------------------
create table app.driver_profiles (
  user_id        bigint primary key references app.users (id) on delete cascade,
  status         text not null default 'draft'
                   check (status in ('draft', 'submitted', 'in_review', 'needs_changes', 'approved', 'rejected', 'suspended')),
  service_id     bigint references app.services (id) on delete set null,   -- the ride type they apply for
  date_of_birth  date,
  licence_years  integer check (licence_years between 0 and 80),
  vehicle_make   text,
  vehicle_model  text,
  vehicle_year   text,
  vehicle_colour text,
  vehicle_plate  text,
  vehicle_seats  integer check (vehicle_seats between 1 and 60),
  submitted_at   timestamptz,
  reviewed_by    bigint references app.users (id) on delete set null,
  reviewed_at    timestamptz,
  review_note    text,                                                     -- reason shown to the applicant
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index driver_profiles_status_idx on app.driver_profiles (status);
create trigger driver_profiles_touch before update on app.driver_profiles
  for each row execute function app.touch_updated_at();
alter table app.driver_profiles enable row level security;

-- Existing drivers become profiles with a status that matches their account.
insert into app.driver_profiles (user_id, status, service_id, vehicle_model, vehicle_colour, vehicle_plate, vehicle_year)
select u.id,
       case u.status when 'active' then 'approved' when 'pending' then 'submitted' when 'reject' then 'rejected' else 'suspended' end,
       u.service_id, d.car_model, d.car_color, d.car_plate_number, d.car_production_year
  from app.users u left join app.user_details d on d.user_id = u.id
 where u.user_type = 'driver';

-- Uploaded document files and the reviewer's note (the file itself lives in R2 storage).
alter table app.driver_documents
  add column file_key   text,
  add column admin_note text;

-- ---------------------------------------------------------------------------
-- Separate wallets per role
-- ---------------------------------------------------------------------------
alter table app.wallets add column kind text not null default 'rider' check (kind in ('rider', 'driver'));
update app.wallets w set kind = 'driver' from app.users u where u.id = w.user_id and u.user_type = 'driver';
update app.wallets set allow_negative = (kind = 'driver');
alter table app.wallets drop constraint wallets_user_id_key;
alter table app.wallets add constraint wallets_user_kind_key unique (user_id, kind);
alter table app.wallets add constraint wallets_negative_only_driver check (kind = 'driver' or not allow_negative);

alter table app.virtual_accounts add column wallet_kind text not null default 'rider' check (wallet_kind in ('rider', 'driver'));
update app.virtual_accounts v set wallet_kind = 'driver' from app.users u where u.id = v.user_id and u.user_type = 'driver';
alter table app.virtual_accounts drop constraint virtual_accounts_user_id_provider_bank_name_key;
alter table app.virtual_accounts add constraint virtual_accounts_user_kind_key unique (user_id, provider, bank_name, wallet_kind);
