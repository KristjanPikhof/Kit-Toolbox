#!/bin/zsh
# Helper-only tests for lib/kit-core.zsh. This does not source runtime files.

emulate -L zsh
setopt no_unset pipe_fail

typeset -i PASS=0 FAIL=0
ROOT="${0:A:h:h}"
TMP="${${TMPDIR:-/tmp}%/}/kit-core-test.$$"
TMP="${TMP:A}"
LIB="$ROOT/lib/kit-core.zsh"

pass() { print -r -- "ok - $1"; PASS+=1 }
fail() { print -r -- "not ok - $1"; print -r -- "  $2"; FAIL+=1 }
assert_status() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "expected status $3, got $2" }
assert_contains() { [[ "$2" == *"$3"* ]] && pass "$1" || fail "$1" "expected output to contain: $3\noutput was: $2" }
assert_equals() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "expected: $3\nactual: $2" }
assert_empty() { [[ -z "$2" ]] && pass "$1" || fail "$1" "expected empty output, got: $2" }

cleanup() { rm -rf "$TMP" }
trap cleanup EXIT INT TERM

mkdir -p "$TMP/functions"

out=$(zsh -fc "emulate -L zsh; source ${(q)LIB}; source ${(q)LIB}" 2>&1); rc=$?
assert_status "source is idempotent" "$rc" 0
assert_empty "source has no output" "$out"

source "$LIB"

_kit_validate_shell_identifier "proj_1"; rc=$?
assert_status "identifier accepts shell-safe names" "$rc" 0
_kit_validate_shell_identifier "_private"; rc=$?
assert_status "identifier accepts leading underscore" "$rc" 0
_kit_validate_shell_identifier "1bad"; rc=$?
assert_status "identifier rejects leading digit" "$rc" 1
_kit_validate_shell_identifier "bad-name"; rc=$?
assert_status "identifier rejects hyphen" "$rc" 1
_kit_validate_shell_identifier "bad name"; rc=$?
assert_status "identifier rejects spaces" "$rc" 1

_kit_validate_editor_command 'code --wait'; rc=$?
assert_status "editor validation accepts safe command" "$rc" 0
_kit_validate_editor_command 'open -a "Zed"'; rc=$?
assert_status "editor validation accepts quoted app name" "$rc" 0
_kit_validate_editor_command '$HOME/bin/editor'; rc=$?
assert_status "editor validation rejects dollar sign" "$rc" 1
_kit_validate_editor_command 'fake-editor; touch pwned'; rc=$?
assert_status "editor validation rejects semicolon" "$rc" 1

name="" value="" desc=""
_kit_parse_config_line "edit|fake-editor '--classic mode'|Description with spaces and | pipe" name value desc; rc=$?
assert_status "parse accepts pipe-delimited config line" "$rc" 0
assert_equals "parse extracts name" "$name" "edit"
assert_equals "parse preserves value quotes and spaces" "$value" "fake-editor '--classic mode'"
assert_equals "parse preserves desc remainder" "$desc" "Description with spaces and | pipe"

_kit_parse_config_line "" name value desc; rc=$?
assert_status "parse skips blank lines" "$rc" 1
_kit_parse_config_line "   # comment" name value desc; rc=$?
assert_status "parse skips comment lines" "$rc" 1
_kit_parse_config_line "not-delimited" name value desc; rc=$?
assert_status "parse reports malformed lines" "$rc" 2
_kit_parse_config_line "edit|fake-editor|desc" "bad-name" value desc; rc=$?
assert_status "parse rejects invalid output variable names" "$rc" 3
_kit_parse_config_line "edit|fake-editor|desc" "touch_pwned" 'bad;name' desc; rc=$?
assert_status "parse rejects unsafe output variable names before assignment" "$rc" 3

cat > "$TMP/shortcuts.conf" <<EOF
# comment

proj|$TMP/project one|Project one
1bad|$TMP/bad|Invalid name skipped
proj|$TMP/project two|Duplicate second entry
space_value|$TMP/path with spaces|Path with spaces
EOF

cat > "$TMP/editor.conf" <<'EOF'
# comment
edit|fake-editor --classic|Classic editor
bad-name|fake-editor|Invalid name skipped
quoted|fake-editor '--quoted arg'|Quoted editor
edit|fake-editor --second|Duplicate second entry
EOF

out=$(_kit_read_shortcut_entries "$TMP/shortcuts.conf"); rc=$?
assert_status "shortcut reader succeeds" "$rc" 0
assert_contains "shortcut reader emits valid entry" "$out" "proj|$TMP/project one|Project one"
assert_contains "shortcut reader preserves path spaces" "$out" "space_value|$TMP/path with spaces|Path with spaces"
if [[ "$out" != *"1bad"* ]]; then pass "shortcut reader skips invalid names"; else fail "shortcut reader skips invalid names" "$out"; fi

out=$(_kit_read_editor_entries "$TMP/editor.conf"); rc=$?
assert_status "editor reader succeeds" "$rc" 0
assert_contains "editor reader emits valid entry" "$out" "edit|fake-editor --classic|Classic editor"
assert_contains "editor reader preserves quoted command text" "$out" "quoted|fake-editor '--quoted arg'|Quoted editor"
if [[ "$out" != *"bad-name"* ]]; then pass "editor reader skips invalid names"; else fail "editor reader skips invalid names" "$out"; fi

out=$(_kit_find_shortcut "$TMP/shortcuts.conf" "proj"); rc=$?
assert_status "find shortcut succeeds" "$rc" 0
assert_equals "find shortcut returns first match" "$out" "proj|$TMP/project one|Project one"
out=$(_kit_find_shortcut "$TMP/shortcuts.conf" "missing"); rc=$?
assert_status "find shortcut missing returns 1" "$rc" 1
assert_empty "find shortcut missing has no output" "$out"

out=$(_kit_find_editor "$TMP/editor.conf" "edit"); rc=$?
assert_status "find editor succeeds" "$rc" 0
assert_equals "find editor returns first match" "$out" "edit|fake-editor --classic|Classic editor"
out=$(_kit_find_editor "$TMP/editor.conf" "missing"); rc=$?
assert_status "find editor missing returns 1" "$rc" 1
assert_empty "find editor missing has no output" "$out"

cat > "$TMP/functions/images.sh" <<'EOF'
# images.sh
# Category: Image Processing
# Description: Image tools
# Dependencies: magick
# Functions: img-resize, img-optimize
EOF
cat > "$TMP/functions/system.sh" <<'EOF'
# system.sh
# Category: System Utilities
# Description: System tools
# Functions: ports, kill-port
EOF
cat > "$TMP/functions/no-header.sh" <<'EOF'
# no reusable metadata here
EOF

out=$(_kit_read_module_headers "$TMP/functions"); rc=$?
assert_status "module header reader succeeds" "$rc" 0
assert_contains "module header reader emits image module" "$out" "images.sh|Image Processing|img-resize, img-optimize|Image tools"
assert_contains "module header reader emits system module" "$out" "system.sh|System Utilities|ports, kill-port|System tools"
if [[ "$out" != *"no-header.sh"* ]]; then pass "module header reader skips files without headers"; else fail "module header reader skips files without headers" "$out"; fi

out=$(_kit_read_module_headers "$ROOT/functions"); rc=$?
assert_status "module header reader works against repo functions" "$rc" 0
assert_contains "module header reader discovers repo resize commands" "$out" "img-resize"
assert_contains "module header reader discovers repo navigation category" "$out" "Navigation Shortcuts"

print -r -- ""
print -r -- "Passed: $PASS"
print -r -- "Failed: $FAIL"
(( FAIL == 0 ))
