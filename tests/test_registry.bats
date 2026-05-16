#!/usr/bin/env bats

load 'helpers'

setup() {
  setup_cpm_data
}

@test "_append_project_to_registry appends a single-repo project" {
  cpm_eval "_append_project_to_registry myapp trig_abc '' yourorg/myapp" >/dev/null
  run jq -r '.projects[0].name' "$CPM_DATA/projects.json"
  [ "$status" -eq 0 ]
  [ "$output" = "myapp" ]
  run jq -r '.projects[0].repos[0].repo' "$CPM_DATA/projects.json"
  [ "$output" = "yourorg/myapp" ]
  run jq -r '.projects[0].trigger_id' "$CPM_DATA/projects.json"
  [ "$output" = "trig_abc" ]
  run jq -r '.projects[0].paused' "$CPM_DATA/projects.json"
  [ "$output" = "false" ]
}

@test "_append_project_to_registry accepts multiple repos" {
  cpm_eval "_append_project_to_registry myapp trig_abc '' yourorg/web yourorg/ios" >/dev/null
  run jq '.projects[0].repos | length' "$CPM_DATA/projects.json"
  [ "$output" = "2" ]
}

@test "_append_project_to_registry records branch_prefix when given" {
  cpm_eval "_append_project_to_registry myapp trig_abc 'cpm/' yourorg/myapp" >/dev/null
  run jq -r '.projects[0].branch_prefix' "$CPM_DATA/projects.json"
  [ "$output" = "cpm/" ]
}

@test "_append_project_to_registry omits branch_prefix when empty" {
  cpm_eval "_append_project_to_registry myapp trig_abc '' yourorg/myapp" >/dev/null
  run jq '.projects[0] | has("branch_prefix")' "$CPM_DATA/projects.json"
  [ "$output" = "false" ]
}

@test "_append_project_to_registry rejects duplicate project name" {
  cpm_eval "_append_project_to_registry myapp trig_abc '' yourorg/myapp" >/dev/null
  run cpm_eval "_append_project_to_registry myapp trig_xyz '' yourorg/other"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "_append_project_to_registry rejects missing name" {
  run cpm_eval "_append_project_to_registry '' trig_abc '' yourorg/myapp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"name is required"* ]]
}

@test "_append_project_to_registry rejects missing trigger_id" {
  run cpm_eval "_append_project_to_registry myapp '' '' yourorg/myapp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"trigger_id is required"* ]]
}

@test "_append_project_to_registry rejects empty repo list" {
  run cpm_eval "_append_project_to_registry myapp trig_abc ''"
  [ "$status" -ne 0 ]
  [[ "$output" == *"at least one repo"* ]]
}

@test "two projects can coexist in projects.json" {
  cpm_eval "_append_project_to_registry alpha trig_a '' o/a" >/dev/null
  cpm_eval "_append_project_to_registry beta trig_b '' o/b" >/dev/null
  run jq '.projects | length' "$CPM_DATA/projects.json"
  [ "$output" = "2" ]
}
