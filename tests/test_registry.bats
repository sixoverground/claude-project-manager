#!/usr/bin/env bats

load 'helpers'

setup() {
  setup_cpm_data
}

@test "_append_project_to_registry appends a single-repo project" {
  cpm_eval "_append_project_to_registry myapp trig_abc '' '' false yourorg/myapp" >/dev/null
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
  cpm_eval "_append_project_to_registry myapp trig_abc '' '' false yourorg/web yourorg/ios" >/dev/null
  run jq '.projects[0].repos | length' "$CPM_DATA/projects.json"
  [ "$output" = "2" ]
}

@test "_append_project_to_registry records branch_prefix when given" {
  cpm_eval "_append_project_to_registry myapp trig_abc 'cpm/' '' false yourorg/myapp" >/dev/null
  run jq -r '.projects[0].branch_prefix' "$CPM_DATA/projects.json"
  [ "$output" = "cpm/" ]
}

@test "_append_project_to_registry omits branch_prefix when empty" {
  cpm_eval "_append_project_to_registry myapp trig_abc '' '' false yourorg/myapp" >/dev/null
  run jq '.projects[0] | has("branch_prefix")' "$CPM_DATA/projects.json"
  [ "$output" = "false" ]
}

@test "_append_project_to_registry records target_branch when given" {
  cpm_eval "_append_project_to_registry myapp trig_abc '' 'develop' false yourorg/myapp" >/dev/null
  run jq -r '.projects[0].target_branch' "$CPM_DATA/projects.json"
  [ "$output" = "develop" ]
}

@test "_append_project_to_registry omits target_branch when empty" {
  cpm_eval "_append_project_to_registry myapp trig_abc '' '' false yourorg/myapp" >/dev/null
  run jq '.projects[0] | has("target_branch")' "$CPM_DATA/projects.json"
  [ "$output" = "false" ]
}

@test "_append_project_to_registry records both branch_prefix and target_branch" {
  cpm_eval "_append_project_to_registry myapp trig_abc 'cpm/' 'release/2026' false yourorg/myapp" >/dev/null
  run jq -r '.projects[0].branch_prefix' "$CPM_DATA/projects.json"
  [ "$output" = "cpm/" ]
  run jq -r '.projects[0].target_branch' "$CPM_DATA/projects.json"
  [ "$output" = "release/2026" ]
}

@test "_append_project_to_registry records yolo when true" {
  cpm_eval "_append_project_to_registry myapp trig_abc '' '' true yourorg/myapp" >/dev/null
  run jq -r '.projects[0].yolo' "$CPM_DATA/projects.json"
  [ "$output" = "true" ]
}

@test "_append_project_to_registry omits yolo when false" {
  cpm_eval "_append_project_to_registry myapp trig_abc '' '' false yourorg/myapp" >/dev/null
  run jq '.projects[0] | has("yolo")' "$CPM_DATA/projects.json"
  [ "$output" = "false" ]
}

@test "_append_project_to_registry records all optional fields together" {
  cpm_eval "_append_project_to_registry myapp trig_abc 'cpm/' 'develop' true yourorg/myapp" >/dev/null
  run jq -r '.projects[0].branch_prefix' "$CPM_DATA/projects.json"
  [ "$output" = "cpm/" ]
  run jq -r '.projects[0].target_branch' "$CPM_DATA/projects.json"
  [ "$output" = "develop" ]
  run jq -r '.projects[0].yolo' "$CPM_DATA/projects.json"
  [ "$output" = "true" ]
}

@test "_append_project_to_registry rejects duplicate project name" {
  cpm_eval "_append_project_to_registry myapp trig_abc '' '' false yourorg/myapp" >/dev/null
  run cpm_eval "_append_project_to_registry myapp trig_xyz '' '' false yourorg/other"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "_append_project_to_registry rejects missing name" {
  run cpm_eval "_append_project_to_registry '' trig_abc '' '' false yourorg/myapp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"name is required"* ]]
}

@test "_append_project_to_registry rejects missing trigger_id" {
  run cpm_eval "_append_project_to_registry myapp '' '' '' false yourorg/myapp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"trigger_id is required"* ]]
}

@test "_append_project_to_registry rejects empty repo list" {
  run cpm_eval "_append_project_to_registry myapp trig_abc '' '' false"
  [ "$status" -ne 0 ]
  [[ "$output" == *"at least one repo"* ]]
}

@test "two projects can coexist in projects.json" {
  cpm_eval "_append_project_to_registry alpha trig_a '' '' false o/a" >/dev/null
  cpm_eval "_append_project_to_registry beta trig_b '' '' false o/b" >/dev/null
  run jq '.projects | length' "$CPM_DATA/projects.json"
  [ "$output" = "2" ]
}
