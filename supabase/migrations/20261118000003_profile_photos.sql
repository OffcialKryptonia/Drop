-- Persist private profile photos in the existing DROP R2 document bucket.
alter table app.users add column if not exists profile_image_key text;
