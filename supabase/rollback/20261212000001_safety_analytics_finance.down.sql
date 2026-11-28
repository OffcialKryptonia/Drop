-- Undoes 20261212000001_safety_analytics_finance.sql. Run by hand only. It deletes the incident history, driver event history and
-- online sessions recorded since the migration, and maps the new incident states back to the old three.
drop index if exists app.withdraw_requests_created_idx, app.ride_extras_responded_idx, app.wallet_ledger_ride_idx, app.wallet_ledger_kind_created_idx,
  app.ride_requests_driver_accepted_idx, app.ride_requests_rider_created_idx;
delete from app.settings where key = 'analytics_tracking';
drop trigger if exists users_track_online on app.users;
drop function if exists app.track_driver_online();
drop table if exists app.driver_online_sessions;
drop trigger if exists ride_requests_track_driver_upd on app.ride_requests;
drop trigger if exists ride_requests_track_driver_ins on app.ride_requests;
drop function if exists app.track_driver_ride();
drop table if exists app.driver_ride_events;
drop index if exists app.admin_audit_target_idx, app.admin_audit_admin_idx, app.admin_audit_action_idx, app.admin_audit_created_idx;
drop trigger if exists safety_incident_events_no_truncate on app.safety_incident_events;
drop trigger if exists admin_audit_no_truncate on app.admin_audit;
drop trigger if exists safety_incident_events_append_only on app.safety_incident_events;
drop trigger if exists admin_audit_append_only on app.admin_audit;
drop function if exists app.block_log_truncate();
drop function if exists app.block_log_changes();
drop table if exists app.safety_incident_events;
drop index if exists app.sos_alerts_ride_idx, app.sos_alerts_assigned_idx;
alter table app.sos_alerts drop column if exists closed_at, drop column if exists updated_at, drop column if exists source,
  drop column if exists assigned_to, drop column if exists severity, drop column if exists category;
update app.sos_alerts set status = 'acknowledged' where status in ('investigating', 'escalated');
update app.sos_alerts set status = 'resolved' where status = 'closed';
alter table app.sos_alerts drop constraint sos_alerts_status_check;
alter table app.sos_alerts add constraint sos_alerts_status_check check (status in ('open', 'acknowledged', 'resolved'));
