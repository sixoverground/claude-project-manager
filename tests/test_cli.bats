#!/usr/bin/env bats

load 'helpers'

@test "cpm help prints usage" {
  run "$CPM_REPO_ROOT/cpm" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: cpm"* ]]
  [[ "$output" == *"init"* ]]
  [[ "$output" == *"doctor"* ]]
  [[ "$output" == *"new"* ]]
  [[ "$output" == *"add"* ]]
}

@test "cpm with no args defaults to help" {
  run "$CPM_REPO_ROOT/cpm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: cpm"* ]]
}

@test "cpm --help is equivalent to help" {
  run "$CPM_REPO_ROOT/cpm" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: cpm"* ]]
}

@test "cpm bogus_command exits non-zero" {
  run "$CPM_REPO_ROOT/cpm" bogus_command
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown command"* ]]
}

@test "cpm trigger with no name exits non-zero" {
  run "$CPM_REPO_ROOT/cpm" trigger
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage: cpm trigger"* ]]
}

@test "cpm remove with no name exits non-zero" {
  run "$CPM_REPO_ROOT/cpm" remove
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage: cpm remove"* ]]
}
