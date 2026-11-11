-- Phone-first accounts: email becomes optional, and one phone number can belong to one account.
alter table app.users alter column email drop not null;

-- Canonical digits of a phone number: country code + national number without a leading 0.
create or replace function app.phone_digits(country_code text, contact_number text)
returns text language sql immutable as $$
  select case when contact_number is null or btrim(contact_number) = '' then null
    else regexp_replace(coalesce(country_code, ''), '\D', '', 'g')
      || ltrim(regexp_replace(contact_number, '\D', '', 'g'), '0') end
$$;

create unique index if not exists users_phone_unique
  on app.users (app.phone_digits(country_code, contact_number))
  where deleted_at is null and app.phone_digits(country_code, contact_number) is not null;
