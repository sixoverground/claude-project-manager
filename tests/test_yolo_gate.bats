#!/usr/bin/env bats

load 'helpers'

setup() {
  setup_cpm_data
  GQL="$CPM_DATA/gql.json"
}

# Write a GraphQL pullRequest response fixture to $GQL.
# Usage: write_gql <headOid> <reviewsJson> <threadsJson>
write_gql() {
  cat > "$GQL" <<EOF
{"data":{"repository":{"pullRequest":{
  "headRefOid": "$1",
  "reviews": {"nodes": $2},
  "reviewThreads": {"nodes": $3}
}}}}
EOF
}

# Run the pure gate helper against the fixture file.
gate() {
  run cpm_eval "_yolo_gate_reviewed \"\$(cat '$GQL')\" '$1'"
}

HEAD="abc123def456abc123def456abc123def456abcd"
OLD="0000000000000000000000000000000000000000"

# --- _yolo_gate_reviewed ---

@test "gate PASS: reviewer evaluated head and all threads resolved" {
  write_gql "$HEAD" \
    '[{"author":{"login":"copilot-pull-request-reviewer"},"commit":{"oid":"'"$HEAD"'"}}]' \
    '[{"isResolved":true},{"isResolved":true}]'
  gate "copilot-pull-request-reviewer,github-copilot,copilot"
  [ "$output" = "PASS" ]
}

@test "gate PASS: no threads at all (clean review of head)" {
  write_gql "$HEAD" \
    '[{"author":{"login":"claude"},"commit":{"oid":"'"$HEAD"'"}}]' \
    '[]'
  gate "claude"
  [ "$output" = "PASS" ]
}

@test "gate PASS: proof via inline thread comment at head (no formal review node)" {
  write_gql "$HEAD" \
    '[]' \
    '[{"isResolved":true,"comments":{"nodes":[{"author":{"login":"claude"},"commit":{"oid":"'"$HEAD"'"}}]}}]'
  gate "claude"
  [ "$output" = "PASS" ]
}

@test "gate FAIL: inline thread comment is at an old sha (stale)" {
  write_gql "$HEAD" \
    '[]' \
    '[{"isResolved":true,"comments":{"nodes":[{"author":{"login":"claude"},"commit":{"oid":"'"$OLD"'"}}]}}]'
  gate "claude"
  [[ "$output" == FAIL:*"evaluated current head"* ]]
}

@test "gate FAIL: reviewer reviewed an old sha (stale)" {
  write_gql "$HEAD" \
    '[{"author":{"login":"copilot-pull-request-reviewer"},"commit":{"oid":"'"$OLD"'"}}]' \
    '[{"isResolved":true}]'
  gate "copilot-pull-request-reviewer"
  [[ "$output" == FAIL:*"evaluated current head"* ]]
}

@test "gate FAIL: reviewed head but a thread is unresolved" {
  write_gql "$HEAD" \
    '[{"author":{"login":"claude"},"commit":{"oid":"'"$HEAD"'"}}]' \
    '[{"isResolved":true},{"isResolved":false}]'
  gate "claude"
  [[ "$output" == FAIL:*"unresolved review thread"* ]]
}

@test "gate FAIL: reviewer has not reviewed at all" {
  write_gql "$HEAD" '[]' '[]'
  gate "claude"
  [[ "$output" == FAIL:*"evaluated current head"* ]]
}

@test "gate FAIL: only a non-configured reviewer reviewed head" {
  write_gql "$HEAD" \
    '[{"author":{"login":"someone-else"},"commit":{"oid":"'"$HEAD"'"}}]' \
    '[]'
  gate "claude"
  [[ "$output" == FAIL:* ]]
}

@test "gate login match tolerates [bot] suffix in the GraphQL login" {
  write_gql "$HEAD" \
    '[{"author":{"login":"claude[bot]"},"commit":{"oid":"'"$HEAD"'"}}]' \
    '[]'
  gate "claude"
  [ "$output" = "PASS" ]
}

@test "gate login match tolerates [bot] suffix in the config value" {
  write_gql "$HEAD" \
    '[{"author":{"login":"claude"},"commit":{"oid":"'"$HEAD"'"}}]' \
    '[]'
  gate "claude[bot]"
  [ "$output" = "PASS" ]
}

@test "gate login match is case-insensitive" {
  write_gql "$HEAD" \
    '[{"author":{"login":"Copilot"},"commit":{"oid":"'"$HEAD"'"}}]' \
    '[]'
  gate "copilot"
  [ "$output" = "PASS" ]
}

@test "gate FAIL: malformed GraphQL response does not crash under errexit" {
  printf '%s' "not json" > "$GQL"
  gate "claude"
  [ "$status" -eq 0 ]
  [[ "$output" == FAIL:*"could not read PR review data"* ]]
}

@test "gate FAIL: empty GraphQL response (e.g. network failure)" {
  printf '%s' "" > "$GQL"
  gate "claude"
  [ "$status" -eq 0 ]
  [[ "$output" == FAIL:* ]]
}

# --- _resolve_yolo_reviewer ---

@test "resolver returns default Copilot logins when config absent" {
  run cpm_eval "_resolve_yolo_reviewer ''"
  [ "$output" = "copilot-pull-request-reviewer,github-copilot,copilot" ]
}

@test "resolver returns __DISABLED__ for false" {
  run cpm_eval "_resolve_yolo_reviewer 'false'"
  [ "$output" = "__DISABLED__" ]
}

@test "resolver reads .logins array from object" {
  run cpm_eval "_resolve_yolo_reviewer '{\"logins\":[\"claude\"]}'"
  [ "$output" = "claude" ]
}

@test "resolver joins multiple logins with commas" {
  run cpm_eval "_resolve_yolo_reviewer '{\"logins\":[\"claude\",\"github-actions\"]}'"
  [ "$output" = "claude,github-actions" ]
}

@test "resolver falls back to default when object has no logins" {
  run cpm_eval "_resolve_yolo_reviewer '{}'"
  [ "$output" = "copilot-pull-request-reviewer,github-copilot,copilot" ]
}

# --- gate 5 disabled path in _yolo_check_pr ---

@test "disabled reviewer skips gate 5 (helper returns __DISABLED__ passthrough)" {
  # A project configured with "yolo_reviewer": false resolves to __DISABLED__,
  # which _yolo_check_pr treats as an automatic gate-5 pass.
  run cpm_eval "_resolve_yolo_reviewer 'false'"
  [ "$output" = "__DISABLED__" ]
}
