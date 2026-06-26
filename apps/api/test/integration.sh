#!/usr/bin/env bash
# Ordo integration test harness — drives the live API over HTTP.
set -uo pipefail
BASE="${BASE:-http://localhost:4010}"
STAMP="$$"
A_EMAIL="it_a_${STAMP}@ordo.app"; B_EMAIL="it_b_${STAMP}@ordo.app"; C_EMAIL="it_c_${STAMP}@ordo.app"
A_USER="it_a_${STAMP}"; B_USER="it_b_${STAMP}"; C_USER="it_c_${STAMP}"
PASS="Test1234!"
PASS_COUNT=0; FAIL_COUNT=0; FAILED=()
TOKEN=""   # current bearer

req() { # method path [json | - for none] [extra curl args...]
  local method="$1" path="$2" body="${3:-}"; shift 3 2>/dev/null || shift $# 2>/dev/null || true
  local -a hdrs=( -H "Content-Type: application/json" )
  [[ -n "${TOKEN:-}" ]] && hdrs+=( -H "Authorization: Bearer $TOKEN" )
  if [[ -n "$body" && "$body" != "-" ]]; then
    curl -sS -o /tmp/ordo-resp.json -w "%{http_code}" -X "$method" "$BASE$path" "${hdrs[@]}" -d "$body" "$@"
  else
    curl -sS -o /tmp/ordo-resp.json -w "%{http_code}" -X "$method" "$BASE$path" "${hdrs[@]}" "$@"
  fi
}
jget() { if command -v jq >/dev/null; then jq -r "$1" /tmp/ordo-resp.json 2>/dev/null; else python3 -c "import json;d=json.load(open('/tmp/ordo-resp.json'));print($1)" 2>/dev/null; fi; }
chk()  { local n="$1" e="$2" a="$3" x="${4:-}"; if [[ "$e" == "$a" ]]; then PASS_COUNT=$((PASS_COUNT+1)); printf "  ✓ %-56s [%s]\n" "$n" "$a"; else FAIL_COUNT=$((FAIL_COUNT+1)); FAILED+=("$n (exp $e got $a) $x"); printf "  ✗ %-56s [exp %s got %s]  %s\n" "$n" "$e" "$a" "$x"; fi; }
ok2x() { local n="$1" a="$2" x="${3:-}"; if [[ "$a" =~ ^2 ]]; then PASS_COUNT=$((PASS_COUNT+1)); printf "  ✓ %-56s [%s]\n" "$n" "$a"; else FAIL_COUNT=$((FAIL_COUNT+1)); FAILED+=("$n (got $a) $x"); printf "  ✗ %-56s [got %s]  %s\n" "$n" "$a" "$x"; fi; }
deny() { local n="$1" a="$2" x="${3:-}"; if [[ "$a" =~ ^(4|5) && "$a" != "200" ]]; then PASS_COUNT=$((PASS_COUNT+1)); printf "  ✓ %-56s [%s]\n" "$n" "$a"; else FAIL_COUNT=$((FAIL_COUNT+1)); FAILED+=("$n (expected deny got $a) $x"); printf "  ✗ %-56s [got %s, expected deny]  %s\n" "$n" "$a" "$x"; fi; }

echo "============================================================"
echo "Ordo integration tests @ $BASE (run $STAMP)"
echo "============================================================"

echo "## AUTH/REGISTER"
TOKEN=""
s=$(req POST /api/auth/register "{\"name\":\"IT A\",\"email\":\"$A_EMAIL\",\"username\":\"$A_USER\",\"password\":\"$PASS\"}")
chk "register A" 201 "$s"; A_ID=$(jget '.user.id'); A_TOKEN=$(jget '.accessToken'); A_REFRESH=$(jget '.refreshToken'); TOKEN="$A_TOKEN"
s=$(req POST /api/auth/register "{\"name\":\"IT B\",\"email\":\"$B_EMAIL\",\"username\":\"$B_USER\",\"password\":\"$PASS\"}")
chk "register B" 201 "$s"; B_ID=$(jget '.user.id'); B_TOKEN=$(jget '.accessToken'); B_REFRESH=$(jget '.refreshToken')
s=$(req POST /api/auth/register "{\"name\":\"IT A\",\"email\":\"$A_EMAIL\",\"username\":\"dup_${STAMP}\",\"password\":\"$PASS\"}")
chk "duplicate email -> 409" 409 "$s"
s=$(req POST /api/auth/register "{\"name\":\"x\",\"email\":\"bad\",\"username\":\"ab\",\"password\":\"1\"}")
chk "garbage input -> 400" 400 "$s"
s=$(req POST /api/auth/register "{\"name\":\"Case\",\"email\":\"${A_EMAIL^^}\",\"username\":\"case_${STAMP}\",\"password\":\"$PASS\"}")
chk "uppercase-email dup -> expect 409 (case-insensitive)" 409 "$s" "(if 201: emails are case-sensitive = bug)"

echo "## AUTH/LOGIN"
s=$(req POST /api/auth/login "{\"email\":\"$A_EMAIL\",\"password\":\"$PASS\"}"); ok2x "login email" "$s"
s=$(req POST /api/auth/login "{\"email\":\"$A_USER\",\"password\":\"$PASS\"}")
ok2x "login with username (service ORs it)" "$s" "(if 400: LoginDto blocked username login = bug)"
s=$(req POST /api/auth/login "{\"email\":\"$A_EMAIL\",\"password\":\"wrong\"}"); chk "login wrong pw -> 401" 401 "$s"

echo "## AUTH/SESSION"
TOKEN="$A_TOKEN"; s=$(req GET /api/auth/me); chk "GET me" 200 "$s"
TOKEN=""; s=$(req GET /api/auth/me); chk "GET me no token -> 401" 401 "$s"
s=$(req POST /api/auth/refresh "{\"refreshToken\":\"$A_REFRESH\"}"); ok2x "refresh" "$s"; NEWR=$(jget '.refreshToken')
s=$(req POST /api/auth/refresh "{\"refreshToken\":\"$A_REFRESH\"}"); chk "old refresh reused -> 401" 401 "$s"; A_REFRESH="$NEWR"
TOKEN="$A_TOKEN"; s=$(req GET /api/auth/sessions); chk "sessions list" 200 "$s"; SID=$(jget '.sessions[0].id')
s=$(req DELETE "/api/auth/sessions/$SID"); chk "delete own session" 200 "$s"
s=$(req DELETE "/api/auth/sessions/00000000-0000-0000-0000-000000000000"); chk "delete bogus session -> 404" 404 "$s"
s=$(req POST /api/auth/logout "{\"refreshToken\":\"$A_REFRESH\"}"); ok2x "logout" "$s"
# re-login to refresh A token after session revoke
TOKEN=$(req POST /api/auth/login "{\"email\":\"$A_EMAIL\",\"password\":\"$PASS\"}" >/dev/null; jget '.accessToken'); A_TOKEN="$TOKEN"
[[ -z "$A_TOKEN" ]] && echo "ABORT: A re-login failed" && exit 99

echo "## OTP"
s=$(req POST /api/auth/request-otp "{\"target\":\"email\",\"value\":\"otp_${STAMP}@ordo.app\",\"purpose\":\"signup\"}"); ok2x "request OTP" "$s"
DEV=$(jget '.devCode')
s=$(req POST /api/auth/verify-otp "{\"target\":\"email\",\"value\":\"otp_${STAMP}@ordo.app\",\"code\":\"$DEV\"}"); ok2x "verify OTP correct" "$s"
s=$(req POST /api/auth/verify-otp "{\"target\":\"email\",\"value\":\"otp_${STAMP}@ordo.app\",\"code\":\"000000\"}"); chk "verify OTP wrong -> 401" 401 "$s"

echo "## GROUPS"
TOKEN="$A_TOKEN"
s=$(req POST /api/groups "{\"name\":\"A Group\",\"type\":\"FAMILY\",\"accentColor\":\"rose\"}"); chk "A create group (named accentColor)" 201 "$s"; A_GROUP=$(jget '.id')
TOKEN=""; s=$(req POST /api/groups "{\"name\":\"x\"}"); chk "create group no auth -> 401" 401 "$s"
TOKEN="$A_TOKEN"; s=$(req GET /api/groups); ok2x "A list groups" "$s"
s=$(req GET "/api/groups/$A_GROUP"); ok2x "A get own group" "$s"
# invite + join
s=$(req POST "/api/groups/$A_GROUP/invite"); ok2x "A create invite" "$s"; INVITE=$(jget '.code')
TOKEN="$B_TOKEN"; s=$(req POST /api/groups/join "{\"code\":\"$INVITE\"}"); ok2x "B joins A group" "$s"
# IDOR: a 3rd user C cannot touch A's group
s=$(req POST /api/auth/register "{\"name\":\"C\",\"email\":\"$C_EMAIL\",\"username\":\"$C_USER\",\"password\":\"$PASS\"}" >/dev/null); C_TOKEN=$(jget '.accessToken')
TOKEN="$C_TOKEN"
s=$(req GET "/api/groups/$A_GROUP"); chk "IDOR: C reads A group -> 404" 404 "$s"
s=$(req PATCH "/api/groups/$A_GROUP" "{\"name\":\"hax\"}"); deny "IDOR: C update A group" "$s"
s=$(req DELETE "/api/groups/$A_GROUP"); deny "IDOR: C delete A group" "$s"
# members/roles
TOKEN="$A_TOKEN"; s=$(req GET "/api/groups/$A_GROUP/members"); ok2x "A list members" "$s"

echo "## TIMELINE / PRIVACY"
TOKEN="$A_TOKEN"
s=$(req POST /api/timeline/blocks "{\"title\":\"Lunch\",\"startTime\":\"2026-07-01T12:00:00Z\",\"endTime\":\"2026-07-01T13:00:00Z\",\"visibility\":\"FULL\"}")
chk "A create self FULL block" 201 "$s"; FULL_ID=$(jget '.id')
s=$(req POST /api/timeline/blocks "{\"title\":\"Secret\",\"startTime\":\"2026-07-01T14:00:00Z\",\"endTime\":\"2026-07-01T15:00:00Z\",\"visibility\":\"PRIVATE\"}")
chk "A create self PRIVATE block" 201 "$s"
s=$(req POST /api/timeline/blocks "{\"title\":\"Bad\",\"startTime\":\"2026-07-01T16:00:00Z\",\"endTime\":\"2026-07-01T15:00:00Z\",\"visibility\":\"FULL\"}")
deny "create block end<start (validation)" "$s" "(if 2xx: no time ordering check = bug)"
# group block BUSY_ONLY
s=$(req POST /api/timeline/blocks "{\"title\":\"Group Secret Meeting\",\"groupId\":\"$A_GROUP\",\"startTime\":\"2026-07-01T09:00:00Z\",\"endTime\":\"2026-07-01T10:00:00Z\",\"visibility\":\"BUSY_ONLY\"}")
ok2x "A create group BUSY_ONLY block" "$s"
# B (member) views group timeline; raw title must NOT leak
TOKEN="$B_TOKEN"; s=$(req GET "/api/timeline/group/$A_GROUP?from=2026-07-01T00:00:00Z&to=2026-07-02T00:00:00Z"); ok2x "B view group timeline" "$s"
LEAK=$(jget '[.items[] | select(.title=="Group Secret Meeting")] | length')
chk "PRIVACY: BUSY_ONLY title redacted for B" 0 "$LEAK" "(if 1: raw title leaked = privacy bug)"
# C (non-member) cannot read group timeline
TOKEN="$C_TOKEN"; s=$(req GET "/api/timeline/group/$A_GROUP?from=2026-07-01T00:00:00Z&to=2026-07-02T00:00:00Z"); deny "IDOR: C read A group timeline" "$s"
# C cannot patch A's self block
s=$(req PATCH "/api/timeline/blocks/$FULL_ID" "{\"title\":\"hax\"}"); deny "IDOR: C patch A self block" "$s"

echo "## TASKS"
TOKEN="$A_TOKEN"
s=$(req POST /api/tasks "{\"groupId\":\"$A_GROUP\",\"title\":\"Task 1\",\"priority\":\"HIGH\"}"); chk "A create task" 201 "$s"; TASK_ID=$(jget '.id')
s=$(req GET /api/tasks"?groupId=$A_GROUP"); ok2x "A list tasks" "$s"
s=$(req PATCH "/api/tasks/$TASK_ID" "{\"status\":\"DONE\"}"); ok2x "A update task" "$s"
s=$(req POST "/api/tasks/$TASK_ID/comments" "{\"body\":\"c\"}"); ok2x "A comment on task" "$s"
TOKEN="$C_TOKEN"; s=$(req GET "/api/tasks/$TASK_ID"); deny "IDOR: C read A group task" "$s"
TOKEN=""; s=$(req POST /api/tasks "{\"groupId\":\"$A_GROUP\",\"title\":\"X\"}"); chk "create task no auth -> 401" 401 "$s"

echo "## TODOS"
TOKEN="$A_TOKEN"
s=$(req POST /api/todos "{\"title\":\"Todo 1\",\"groupId\":\"$A_GROUP\"}"); chk "A create todo" 201 "$s"; TODO_ID=$(jget '.id')
s=$(req GET /api/todos/mine); ok2x "A own todos" "$s"
s=$(req PATCH "/api/todos/$TODO_ID" "{\"done\":true}"); ok2x "A toggle todo" "$s"

echo "## CHAT"
TOKEN="$A_TOKEN"
s=$(req POST "/api/groups/$A_GROUP/messages" "{\"body\":\"hello\"}"); chk "A send msg" 201 "$s"; MSG_ID=$(jget '.id')
s=$(req GET "/api/groups/$A_GROUP/messages"); ok2x "A list msgs" "$s"
s=$(req POST "/api/messages/$MSG_ID/reactions" "{\"emoji\":\"👍\"}"); ok2x "A react" "$s"
s=$(req PATCH "/api/messages/$MSG_ID" "{\"body\":\"edited\"}"); ok2x "A edit own msg" "$s"
s=$(req POST "/api/groups/$A_GROUP/read"); ok2x "A mark read" "$s"
TOKEN="$C_TOKEN"; s=$(req POST "/api/groups/$A_GROUP/messages" "{\"body\":\"spam\"}"); deny "IDOR: C post to A group chat" "$s"

echo "## POLLS"
TOKEN="$A_TOKEN"
s=$(req POST "/api/groups/$A_GROUP/polls" "{\"question\":\"Tea?\",\"options\":[{\"text\":\"Yes\"},{\"text\":\"No\"}]}"); chk "A create poll" 201 "$s"; POLL_ID=$(jget '.id'); OPT_ID=$(jget '.results.options[0].id')
TOKEN="$B_TOKEN"; s=$(req POST "/api/polls/$POLL_ID/vote" "{\"optionIds\":[\"$OPT_ID\"]}"); ok2x "B vote" "$s"
s=$(req GET "/api/polls/$POLL_ID"); ok2x "B view poll" "$s"
TOKEN="$C_TOKEN"; s=$(req POST "/api/polls/$POLL_ID/vote" "{\"optionIds\":[\"$OPT_ID\"]}"); deny "IDOR: C vote in A group poll" "$s"

echo "## ANNOUNCEMENTS"
TOKEN="$A_TOKEN"; s=$(req POST "/api/groups/$A_GROUP/announcements" "{\"title\":\"Hi\",\"body\":\"b\"}"); chk "A(owner) announce" 201 "$s"
TOKEN="$B_TOKEN"; s=$(req POST "/api/groups/$A_GROUP/announcements" "{\"title\":\"x\",\"body\":\"y\"}"); deny "B(member) announce -> 403 (ADMIN)" "$s"

echo "## INBOX/DM"
TOKEN="$A_TOKEN"
s=$(req POST /api/inbox/threads "{\"otherUserId\":\"$B_ID\"}"); chk "A start DM w/ B" 201 "$s"; THREAD_ID=$(jget '.threadId')
s=$(req POST "/api/inbox/threads/$THREAD_ID/messages" "{\"body\":\"hi\"}"); ok2x "A send DM" "$s"
s=$(req GET "/api/inbox/threads"); ok2x "A inbox list" "$s"
TOKEN="$C_TOKEN"; s=$(req GET "/api/inbox/threads/$THREAD_ID/messages"); deny "IDOR: C read DM not theirs" "$s"

echo "## NOTIFICATIONS"
TOKEN="$A_TOKEN"; s=$(req GET /api/notifications); ok2x "A notifications" "$s"
s=$(req GET /api/notifications/unread-count); ok2x "A unread count" "$s"
s=$(req POST /api/notifications/read "{}"); ok2x "A mark notif read" "$s"

echo "## AVAILABILITY/SEARCH"
TOKEN="$A_TOKEN"; s=$(req GET /api/me/availability); ok2x "A avail prefs" "$s"
s=$(req POST /api/availability/find-slots "{\"groupId\":\"$A_GROUP\",\"dateRangeStart\":\"2026-08-01T00:00:00Z\",\"dateRangeEnd\":\"2026-08-07T00:00:00Z\",\"durationMinutes\":30}"); ok2x "find slots" "$s"
s=$(req GET "/api/search?q=hello"); ok2x "search" "$s"

echo "## EVENTS/RSVP"
TOKEN="$A_TOKEN"
s=$(req POST /api/timeline/blocks "{\"title\":\"Ev\",\"groupId\":\"$A_GROUP\",\"startTime\":\"2026-07-10T10:00:00Z\",\"endTime\":\"2026-07-10T11:00:00Z\",\"visibility\":\"FULL\",\"isEvent\":true}")
ok2x "A create group event" "$s"; EV_ID=$(jget '.id')
TOKEN="$B_TOKEN"; s=$(req POST "/api/events/$EV_ID/rsvp" "{\"status\":\"GOING\"}"); ok2x "B RSVP" "$s"
s=$(req GET "/api/events/$EV_ID/attendees"); ok2x "B attendees" "$s"

echo "## CATEGORIES/ME"
TOKEN="$A_TOKEN"; s=$(req POST /api/timeline/categories "{\"name\":\"Work\",\"groupId\":\"$A_GROUP\"}"); ok2x "A create category" "$s"
s=$(req PATCH /api/me/profile "{\"bio\":\"hi\",\"timezone\":\"UTC\"}"); ok2x "A update profile" "$s"
s=$(req PATCH /api/me/preferences "{\"accentColor\":\"emerald\",\"theme\":\"dark\"}"); ok2x "A update preferences (named accentColor)" "$s" "(if 400: accentColor validated as hex = regression)"
s=$(req GET /api/me/export); ok2x "A export data" "$s"

echo "## MEDIA"
echo "integration test file" > /tmp/ordo-upload.txt
s=$(curl -sS -o /tmp/ordo-resp.json -w "%{http_code}" -X POST "$BASE/api/media" -H "Authorization: Bearer $TOKEN" -F "file=@/tmp/ordo-upload.txt" -F "groupId=$A_GROUP")
ok2x "A upload file" "$s"; MEDIA_ID=$(jget '.id')

echo "## LOCATION"
s=$(req POST "/api/groups/$A_GROUP/location" "{\"mode\":\"APPROXIMATE\"}"); ok2x "A set location mode" "$s"
s=$(req POST "/api/groups/$A_GROUP/location/point" "{\"lat\":40.0,\"lng\":-3.0}"); ok2x "A post point" "$s"
s=$(req GET "/api/groups/$A_GROUP/location"); ok2x "A view locations" "$s"

echo "## AI"
s=$(req POST /api/ai/parse-command "{\"text\":\"schedule lunch tomorrow 1pm\"}"); ok2x "AI parse-command" "$s"
s=$(req GET /api/ai/plan-day); ok2x "AI plan-day" "$s"

echo "============================================================"
echo "PASS: $PASS_COUNT   FAIL: $FAIL_COUNT"
if [[ ${#FAILED[@]} -gt 0 ]]; then echo "---- FAILURES ----"; for f in "${FAILED[@]}"; do echo "  - $f"; done; fi
echo "============================================================"
exit $FAIL_COUNT
