-- Per-country currency: a region (where rides are priced) has a currency, every ride remembers it,
-- and a user's wallet is in the currency of their phone country. Wallet payments need the two to match.
alter table app.regions add column if not exists currency char(3) not null default 'NGN';
alter table app.ride_requests add column if not exists currency char(3) not null default 'NGN';

-- Wallets with no history take the currency of their owner's country.
update app.wallets w set currency = m.cur
  from (select u.id, case regexp_replace(coalesce(u.country_code, ''), '\D', '', 'g')
          when '233' then 'GHS' when '229' then 'XOF' when '228' then 'XOF' when '225' then 'XOF' when '226' then 'XOF'
          when '227' then 'XOF' when '221' then 'XOF' when '223' then 'XOF' when '245' then 'XOF' when '220' then 'GMD'
          when '224' then 'GNF' when '231' then 'LRD' when '232' then 'SLE' when '222' then 'MRU' when '238' then 'CVE'
          when '254' then 'KES' when '27' then 'ZAR' else 'NGN' end as cur
          from app.users u) m
 where m.id = w.user_id and m.cur <> 'NGN' and w.balance = 0
   and not exists (select 1 from app.wallet_ledger l where l.wallet_id = w.id);
