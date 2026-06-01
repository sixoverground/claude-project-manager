#!/usr/bin/env bats

load 'helpers'

setup() {
  setup_cpm_data
}

@test "state_record_yolo_attempt initializes count to 1" {
  cpm_eval "state_record_yolo_attempt myproj 'owner/repo#42'"
  run jq -r '.myproj.last_yolo_attempt_for_pr' "$CPM_DATA/.cpm-state.json"
  [ "$output" = "owner/repo#42" ]
  run jq -r '.myproj.yolo_attempt_count' "$CPM_DATA/.cpm-state.json"
  [ "$output" = "1" ]
}

@test "state_record_yolo_attempt increments count for same PR" {
  cpm_eval "state_record_yolo_attempt myproj 'owner/repo#42'"
  cpm_eval "state_record_yolo_attempt myproj 'owner/repo#42'"
  cpm_eval "state_record_yolo_attempt myproj 'owner/repo#42'"
  run jq -r '.myproj.yolo_attempt_count' "$CPM_DATA/.cpm-state.json"
  [ "$output" = "3" ]
}

@test "state_record_yolo_attempt resets count when PR key changes" {
  cpm_eval "state_record_yolo_attempt myproj 'owner/repo#42'"
  cpm_eval "state_record_yolo_attempt myproj 'owner/repo#42'"
  cpm_eval "state_record_yolo_attempt myproj 'owner/repo#43'"
  run jq -r '.myproj.last_yolo_attempt_for_pr' "$CPM_DATA/.cpm-state.json"
  [ "$output" = "owner/repo#43" ]
  run jq -r '.myproj.yolo_attempt_count' "$CPM_DATA/.cpm-state.json"
  [ "$output" = "1" ]
}

@test "state_record_dispatch preserves prior yolo state" {
  cpm_eval "state_record_yolo_attempt myproj 'owner/repo#42'"
  cpm_eval "state_record_dispatch myproj 'owner/repo#43'"
  run jq -r '.myproj.last_yolo_attempt_for_pr' "$CPM_DATA/.cpm-state.json"
  [ "$output" = "owner/repo#42" ]
  run jq -r '.myproj.last_dispatched_for_pr' "$CPM_DATA/.cpm-state.json"
  [ "$output" = "owner/repo#43" ]
}

@test "state_record_yolo_attempt preserves prior dispatch state" {
  cpm_eval "state_record_dispatch myproj 'owner/repo#41'"
  cpm_eval "state_record_yolo_attempt myproj 'owner/repo#42'"
  run jq -r '.myproj.last_dispatched_for_pr' "$CPM_DATA/.cpm-state.json"
  [ "$output" = "owner/repo#41" ]
  run jq -r '.myproj.last_yolo_attempt_for_pr' "$CPM_DATA/.cpm-state.json"
  [ "$output" = "owner/repo#42" ]
}

@test "state_record_yolo_attempt writes ISO-8601 UTC timestamp" {
  cpm_eval "state_record_yolo_attempt myproj 'owner/repo#42'"
  run jq -r '.myproj.last_yolo_attempt_at' "$CPM_DATA/.cpm-state.json"
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}
