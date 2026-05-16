# Shared bats helpers. Source from each test file with:
#   load 'helpers'

CPM_REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
export CPM_REPO_ROOT

# Run a zsh snippet with cpm sourced. CPM_DATA (if set) is used as the sandbox
# for PROJECTS_FILE and STATE_FILE so tests never touch the real registry.
cpm_eval() {
  local snippet="$1"
  zsh -c "
    export CPM_SOURCE_ONLY=1
    source '$CPM_REPO_ROOT/cpm'
    if [ -n \"\${CPM_DATA:-}\" ]; then
      PROJECTS_FILE=\"\$CPM_DATA/projects.json\"
      STATE_FILE=\"\$CPM_DATA/.cpm-state.json\"
    fi
    $snippet
  "
}

# ISO-8601 UTC timestamp shifted by N hours from now. N can be negative.
# Usage: iso_offset -1H  -> 1 hour ago
iso_offset() {
  local offset="$1"
  date -u -v"$offset" +%Y-%m-%dT%H:%M:%SZ
}

# Make a sandboxed CPM_DATA directory for a single test. The path is exported
# as CPM_DATA. Teardown runs after each test (per BATS_TEST_NAME).
setup_cpm_data() {
  CPM_DATA="$BATS_TEST_TMPDIR/cpm-data"
  mkdir -p "$CPM_DATA"
  export CPM_DATA
  echo '{"projects": []}' > "$CPM_DATA/projects.json"
}
