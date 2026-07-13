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

# --- _update_project_in_registry ---

# Seed a project with prefix + base + yolo for update tests.
seed_updatable() {
  cpm_eval "_append_project_to_registry myapp trig_abc 'cpm/notes/' 'feature/notes' true yourorg/myapp" >/dev/null
}

@test "_update_project_in_registry changes branch_prefix and target_branch" {
  seed_updatable
  cpm_eval "_update_project_in_registry myapp __CPM_KEEP__ __CPM_KEEP__ 'cpm/tasks/' 'feature/tasks' __CPM_KEEP__ __CPM_KEEP__" >/dev/null
  run jq -r '.projects[0].branch_prefix' "$CPM_DATA/projects.json"
  [ "$output" = "cpm/tasks/" ]
  run jq -r '.projects[0].target_branch' "$CPM_DATA/projects.json"
  [ "$output" = "feature/tasks" ]
}

@test "_update_project_in_registry leaves untouched fields alone" {
  seed_updatable
  cpm_eval "_update_project_in_registry myapp __CPM_KEEP__ __CPM_KEEP__ 'cpm/tasks/' __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__" >/dev/null
  run jq -r '.projects[0].target_branch' "$CPM_DATA/projects.json"
  [ "$output" = "feature/notes" ]
  run jq -r '.projects[0].trigger_id' "$CPM_DATA/projects.json"
  [ "$output" = "trig_abc" ]
}

@test "_update_project_in_registry clears branch_prefix on empty string" {
  seed_updatable
  cpm_eval "_update_project_in_registry myapp __CPM_KEEP__ __CPM_KEEP__ '' __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__" >/dev/null
  run jq '.projects[0] | has("branch_prefix")' "$CPM_DATA/projects.json"
  [ "$output" = "false" ]
}

@test "_update_project_in_registry clears target_branch on empty string" {
  seed_updatable
  cpm_eval "_update_project_in_registry myapp __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ '' __CPM_KEEP__ __CPM_KEEP__" >/dev/null
  run jq '.projects[0] | has("target_branch")' "$CPM_DATA/projects.json"
  [ "$output" = "false" ]
}

@test "_update_project_in_registry updates trigger_id" {
  seed_updatable
  cpm_eval "_update_project_in_registry myapp __CPM_KEEP__ trig_new __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__" >/dev/null
  run jq -r '.projects[0].trigger_id' "$CPM_DATA/projects.json"
  [ "$output" = "trig_new" ]
}

@test "_update_project_in_registry renames a project" {
  seed_updatable
  cpm_eval "_update_project_in_registry myapp renamed __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__" >/dev/null
  run jq -r '.projects[0].name' "$CPM_DATA/projects.json"
  [ "$output" = "renamed" ]
}

@test "_update_project_in_registry replaces the repos array" {
  seed_updatable
  cpm_eval "_update_project_in_registry myapp __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ '[{\"repo\":\"o/web\"},{\"repo\":\"o/ios\"}]'" >/dev/null
  run jq '.projects[0].repos | length' "$CPM_DATA/projects.json"
  [ "$output" = "2" ]
  run jq -r '.projects[0].repos[1].repo' "$CPM_DATA/projects.json"
  [ "$output" = "o/ios" ]
}

@test "_update_project_in_registry toggles yolo off" {
  seed_updatable
  cpm_eval "_update_project_in_registry myapp __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ false __CPM_KEEP__" >/dev/null
  run jq -r '.projects[0].yolo' "$CPM_DATA/projects.json"
  [ "$output" = "false" ]
}

@test "_update_project_in_registry rejects unknown project" {
  seed_updatable
  run cpm_eval "_update_project_in_registry ghost __CPM_KEEP__ trig_x __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "_update_project_in_registry rejects rename onto existing project" {
  cpm_eval "_append_project_to_registry alpha trig_a '' '' false o/a" >/dev/null
  cpm_eval "_append_project_to_registry beta trig_b '' '' false o/b" >/dev/null
  run cpm_eval "_update_project_in_registry alpha beta __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "_update_project_in_registry rejects blanking trigger_id" {
  seed_updatable
  run cpm_eval "_update_project_in_registry myapp __CPM_KEEP__ '' __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__"
  [ "$status" -ne 0 ]
  [[ "$output" == *"trigger_id cannot be empty"* ]]
}

@test "_update_project_in_registry rejects empty repos replacement" {
  seed_updatable
  run cpm_eval "_update_project_in_registry myapp __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ __CPM_KEEP__ '[]'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"at least one repo"* ]]
}
