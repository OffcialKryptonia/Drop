-- Trip states: what the passenger was charged if they cancel late, and how a finished trip was paid.
alter table app.ride_requests
  add column cancellation_fee numeric(14, 2) not null default 0,
  add column commission numeric(14, 2),
  add column paid_with text check (paid_with in ('cash', 'wallet', 'card'));

insert into app.settings (key, value) values ('ride_cancel_grace_seconds', '120'::jsonb)
  on conflict (key) do nothing;
