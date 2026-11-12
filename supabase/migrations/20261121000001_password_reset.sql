-- Forgot password by emailed 6-digit code. Email sending (Resend) is configured in Admin > Payment methods.
alter table app.password_reset_tokens add column if not exists attempts int not null default 0;
alter table app.password_reset_tokens alter column expires_at set default now() + interval '15 minutes';
alter table app.payment_gateways drop constraint if exists payment_gateways_type_check;
alter table app.payment_gateways add constraint payment_gateways_type_check
  check (type in ('wallet', 'cash', 'pocketfi', 'korapay', 'paystack', 'flutterwave', 'resend'));
insert into app.payment_gateways (type, title, status, sort_order) values ('resend', 'Email sending (Resend)', false, 99)
on conflict (type) do nothing;
