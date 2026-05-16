#!/usr/bin/env bats

load 'helpers'

@test "hours_since returns 0 for 'now'" {
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  result=$(cpm_eval "hours_since '$now'")
  [ "$result" = "0" ]
}

@test "hours_since returns 1 for 1 hour ago" {
  local then
  then=$(iso_offset -1H)
  result=$(cpm_eval "hours_since '$then'")
  [ "$result" = "1" ]
}

@test "hours_since returns 5 for 5 hours ago" {
  local then
  then=$(iso_offset -5H)
  result=$(cpm_eval "hours_since '$then'")
  [ "$result" = "5" ]
}

@test "hours_since handles fractional seconds and Z suffix" {
  local then
  then=$(iso_offset -2H)
  result=$(cpm_eval "hours_since '${then%Z}.123Z'")
  [ "$result" = "2" ]
}

@test "time_ago reports minutes for recent times" {
  local then
  then=$(iso_offset -10M)
  result=$(cpm_eval "time_ago '$then'")
  [[ "$result" =~ ^[0-9]+m\ ago$ ]]
}

@test "time_ago reports hours for older times" {
  local then
  then=$(iso_offset -3H)
  result=$(cpm_eval "time_ago '$then'")
  [ "$result" = "3h ago" ]
}
