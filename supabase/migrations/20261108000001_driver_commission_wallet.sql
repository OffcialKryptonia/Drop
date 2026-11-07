-- Driver commission wallet: cash trips take DROP's commission from the driver's wallet, so a driver's
-- balance may go below zero. Riders' wallets can still never go negative: the database enforces it.

alter table app.wallets add column allow_negative boolean not null default false;
alter table app.wallets drop constraint wallets_balance_check;
alter table app.wallets add constraint wallets_balance_check check (balance >= 0 or allow_negative);
alter table app.wallet_ledger drop constraint wallet_ledger_balance_after_check;

update app.wallets w set allow_negative = true
  from app.users u where u.id = w.user_id and u.user_type = 'driver';

-- Small key/value store for admin-editable settings (later: the full App Settings screen).
create table app.settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);
create trigger settings_touch before update on app.settings
  for each row execute function app.touch_updated_at();
alter table app.settings enable row level security;

-- Drivers whose wallet balance is below this cannot take new trips. Per ride type, a value set on the
-- ride type itself (min_wallet_balance) takes priority.
insert into app.settings (key, value) values ('driver_min_wallet_balance', '0'::jsonb);
