#!/usr/bin/env bash
# Admin API checks against a running `wrangler dev` with a LOCAL/test database (it creates regions, ride types, roles).
# Usage: ADMIN_EMAIL=... ADMIN_PASSWORD=... BASE=http://127.0.0.1:8787 bash test/admin-smoke.sh
set -u
BASE=${BASE:-http://127.0.0.1:8787}; B=$BASE/api
: "${ADMIN_EMAIL:?set ADMIN_EMAIL}"; : "${ADMIN_PASSWORD:?set ADMIN_PASSWORD}"
j(){ curl -s -H 'content-type: application/json' "$@"; }
ok(){ [[ "$3" == *"$2"* ]] && echo "PASS $1" || echo "FAIL $1 :: $3"; }
T=$(j -X POST $B/login -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"user_type\":\"admin\"}" | sed -n 's/.*"api_token":"\([^"]*\)".*/\1/p'); A="Authorization: Bearer $T"
ok login '|' "$T"
ME_ID=$(j -H "$A" $B/admin/me | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
S=$RANDOM$RANDOM
ok me '"is_super":true' "$(j -H "$A" $B/admin/me)"
R=$(j -H "$A" -X POST $B/admin/regions -d '{"name":"Test region $S","distance_unit":"km","timezone":"Africa/Lagos","status":true,"coordinates":[{"lat":9.0,"lng":7.3},{"lat":9.1,"lng":7.3},{"lat":9.1,"lng":7.5}]}')
ok region_add 'Region added' "$R"; RID=$(echo $R | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
ok region_bad_poly "Too small" "$(j -H "$A" -X POST $B/admin/regions -d '{"name":"X","distance_unit":"km","timezone":"UTC","status":true,"coordinates":[{"lat":1,"lng":1}]}')"
ok seed 'ride types added' "$(j -H "$A" -X POST $B/admin/regions/$RID/starter-ride-types)"
ok seed_again 'Nothing to add' "$(j -H "$A" -X POST $B/admin/regions/$RID/starter-ride-types)"
L=$(j -H "$A" "$B/admin/services?region_id=$RID"); ok list '"DROP Go"' "$L"; SID=$(echo $L | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
ok add_service 'Ride type added' "$(j -H "$A" -X POST $B/admin/services -d "{\"name\":\"DROP Tuk\",\"region_id\":$RID,\"category\":\"Tricycle\",\"capacity\":3,\"description\":null,\"icon_url\":null,\"photo_url\":null,\"name_i18n\":{\"ha\":\"Tuk\"},\"description_i18n\":{},\"base_fare\":200,\"minimum_fare\":300,\"minimum_distance\":1,\"per_distance\":50,\"per_minute_drive\":5,\"per_minute_wait\":2,\"waiting_time_limit\":3,\"cancellation_fee\":100,\"commission_type\":\"percentage\",\"admin_commission\":15,\"fleet_commission\":0,\"booking_modes\":[\"now\",\"scheduled\"],\"payment_methods\":[\"cash\",\"card\"],\"min_driver_rating\":null,\"min_wallet_balance\":null,\"working_hours\":{\"from\":\"06:00\",\"to\":\"22:00\"},\"badge\":\"New\",\"sort_order\":99,\"status\":true}")"
ok bad_mode 'Invalid' "$(j -H "$A" -X POST $B/admin/services -d "{\"name\":\"X\"}")"
ok edit "Saved" "$(j -H "$A" -X PUT $B/admin/services/$SID -d '{"base_fare":650,"status":true}')"
ok toggle "Saved" "$(j -H "$A" -X PUT $B/admin/services/$SID/status -d '{"status":false}')"
ok dup 'Copied' "$(j -H "$A" -X POST $B/admin/services/$SID/duplicate -d "{\"region_id\":$RID}")"
ok order 'Saved' "$(j -H "$A" -X PUT $B/admin/services-order -d "{\"ids\":[$SID]}")"
ok region_delete_blocked 'still has ride types' "$(j -H "$A" -X DELETE $B/admin/regions/$RID)"
ok opt_list 'Child seat' "$(j -H "$A" $B/admin/service-options)"
ok opt_add 'Option added' "$(j -H "$A" -X POST $B/admin/service-options -d '{"name":"Roof rack","price":300}')"
# roles + sub admin with limited rights
RR=$(j -H "$A" -X POST $B/admin/roles -d '{"name":"ops'$S'","label":"Operations","permissions":["service list","service edit","region list"]}'); ok role_add 'Saved' "$RR"; ROLE=$(echo $RR | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
ok role_bad_perm 'Unknown permission' "$(j -H "$A" -X POST $B/admin/roles -d '{"name":"zz","label":"Z","permissions":["nope"]}')"
ok sub_add 'Sub-admin added' "$(j -H "$A" -X POST $B/admin/sub-admins -d "{\"first_name\":\"Ops\",\"last_name\":\"User\",\"email\":\"ops$S@x.com\",\"username\":\"ops$S\",\"contact_number\":null,\"admin_role_id\":$ROLE,\"status\":\"active\",\"password\":\"ops-password-1\"}")"
T2=$(j -X POST $B/login -d "{\"email\":\"ops$S@x.com\",\"password\":\"ops-password-1\",\"user_type\":\"admin\"}" | sed -n 's/.*"api_token":"\([^"]*\)".*/\1/p'); A2="Authorization: Bearer $T2"
ok ops_login '|' "$T2"
ok ops_me '"is_super":false' "$(j -H "$A2" $B/admin/me)"
ok ops_can_list '"DROP Go"' "$(j -H "$A2" $B/admin/services)"
ok ops_cannot_add 'do not have permission' "$(j -H "$A2" -X POST $B/admin/services -d '{}')"
ok ops_cannot_delete 'do not have permission' "$(j -H "$A2" -X DELETE $B/admin/services/$SID)"
ok ops_cannot_gateways 'do not have permission' "$(j -H "$A2" $B/admin/payment-gateways)"
ok ops_cannot_roles 'do not have permission' "$(j -H "$A2" $B/admin/roles)"
ok rider_forbidden 'Forbidden' "$(j -H "Authorization: Bearer $(j -X POST $B/register -d '{"first_name":"R","last_name":"R","email":"r'$RANDOM'@x.com","username":"r'$RANDOM'","password":"secret123"}' | sed -n 's/.*"api_token":"\([^"]*\)".*/\1/p')" $B/admin/services)"
ok last_super 'at least one active super admin' "$(j -H "$A" -X PUT $B/admin/sub-admins/$ME_ID -d '{"status":"inactive"}')"
ok self_delete 'cannot delete your own' "$(j -H "$A" -X DELETE $B/admin/sub-admins/$ME_ID)"
ok gateways_super 'data' "$(j -H "$A" $B/admin/payment-gateways)"
ok svc_delete 'Deleted' "$(j -H "$A" -X DELETE $B/admin/services/$SID)"
ok role_delete_inuse 'still use this role' "$(j -H "$A" -X DELETE $B/admin/roles/$ROLE)"
