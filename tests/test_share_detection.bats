#!/usr/bin/env bats

# Verifies CPM_SHARE auto-detection picks up the Homebrew pkgshare path when
# the script is invoked from a brew-style install location (no adjacent
# templates/ directory). Regression coverage for the share/cpm →
# share/claude-project-manager rename.

load 'helpers'

setup() {
  FAKE_PREFIX="$BATS_TEST_TMPDIR/fake-brew"
  mkdir -p "$FAKE_PREFIX/share/claude-project-manager/templates"
  mkdir -p "$FAKE_PREFIX/share/claude-project-manager/prompts"
  # Provide a valid plist template so cpm init wouldn't bail later (not used
  # here, but keeps the share dir realistic).
  cp "$CPM_REPO_ROOT/templates/claude-project-manager.plist.tmpl" \
     "$FAKE_PREFIX/share/claude-project-manager/templates/"

  # Copy cpm to a brew-style bin/ with no adjacent templates/ or prompts/.
  FAKE_BIN_DIR="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$FAKE_BIN_DIR"
  cp "$CPM_REPO_ROOT/cpm" "$FAKE_BIN_DIR/cpm"
  chmod +x "$FAKE_BIN_DIR/cpm"

  # Shim 'brew' on PATH so `brew --prefix` returns our fake prefix.
  SHIM_BIN_DIR="$BATS_TEST_TMPDIR/shim-bin"
  mkdir -p "$SHIM_BIN_DIR"
  cat > "$SHIM_BIN_DIR/brew" <<EOF
#!/bin/sh
case "\$1" in
  --prefix) echo "$FAKE_PREFIX" ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$SHIM_BIN_DIR/brew"

  setup_cpm_data
}

@test "CPM_SHARE resolves to brew pkgshare when no adjacent templates/" {
  result=$(PATH="$SHIM_BIN_DIR:$PATH" zsh -c "
    export CPM_SOURCE_ONLY=1
    source '$FAKE_BIN_DIR/cpm'
    echo \"\$CPM_SHARE\"
  ")
  [ "$result" = "$FAKE_PREFIX/share/claude-project-manager" ]
}

@test "_render_plist reads template from CPM_SHARE/templates/" {
  result=$(PATH="$SHIM_BIN_DIR:$PATH" zsh -c "
    export CPM_SOURCE_ONLY=1
    source '$FAKE_BIN_DIR/cpm'
    _render_plist craigtest /Users/craigtest /opt/homebrew /opt/homebrew/bin/cpm '$CPM_DATA' \"\$CPM_SHARE\"
  ")
  # The rendered plist should reference our substituted values.
  [[ "$result" == *"<string>/opt/homebrew/bin/cpm</string>"* ]]
  [[ "$result" == *"<string>$CPM_DATA</string>"* ]]
  [[ "$result" == *"<string>$FAKE_PREFIX/share/claude-project-manager</string>"* ]]
}
