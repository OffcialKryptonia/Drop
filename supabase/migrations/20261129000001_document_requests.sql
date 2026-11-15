-- Admin asks an already-approved (or under-review) driver to upload or replace specific documents.
-- A row is removed when the driver uploads the file, or when the admin cancels the request.
create table if not exists app.driver_document_requests (
  driver_id    bigint not null references app.users (id) on delete cascade,
  document_id  bigint not null references app.documents (id) on delete cascade,
  note         text,
  requested_by bigint references app.users (id) on delete set null,
  requested_at timestamptz not null default now(),
  primary key (driver_id, document_id)
);
alter table app.driver_document_requests enable row level security;
