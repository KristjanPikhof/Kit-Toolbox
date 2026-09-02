#!/bin/zsh
# Hermetic tests for shared file and directory input discovery.

emulate -L zsh
setopt no_unset pipe_fail

typeset -i PASS=0 FAIL=0
ROOT="${0:A:h:h}"
TMP="${${TMPDIR:-/tmp}%/}/kit-files-test.$$"

pass() { print -r -- "ok - $1"; PASS+=1 }
fail() { print -r -- "not ok - $1"; print -r -- "  $2"; FAIL+=1 }
assert_status() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "expected status $3, got $2" }
assert_equals() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "expected '$3', got '$2'" }

cleanup() { rm -rf "$TMP" }
trap cleanup EXIT INT TERM

mkdir -p "$TMP/images/nested" "$TMP/empty"
touch "$TMP/images/a.jpg" "$TMP/images/b.PNG" "$TMP/images/readme.txt"
touch "$TMP/images/nested/c.webp" "$TMP/images/nested/ignore.mov"

source "$ROOT/lib/kit-files.zsh"

_kit_collect_files _kit_is_image_file false image "$TMP/images/a.jpg"; rc=$?
assert_status "collects one explicit file" "$rc" 0
assert_equals "single file result" "${reply[*]}" "$TMP/images/a.jpg"

_kit_collect_files _kit_is_image_file false image "$TMP/images/a.jpg" "$TMP/images/b.PNG"; rc=$?
assert_status "collects multiple explicit files" "$rc" 0
assert_equals "multiple file order" "${reply[*]}" "$TMP/images/a.jpg $TMP/images/b.PNG"

_kit_collect_files _kit_is_image_file false image "$TMP/images"; rc=$?
assert_status "collects matching directory files" "$rc" 0
assert_equals "directory scan is filtered and sorted" "${reply[*]}" "$TMP/images/a.jpg $TMP/images/b.PNG"

_kit_collect_files _kit_is_image_file true image "$TMP/images"; rc=$?
assert_status "collects recursively" "$rc" 0
assert_equals "recursive scan includes nested matches" "${reply[*]}" "$TMP/images/a.jpg $TMP/images/b.PNG $TMP/images/nested/c.webp"

_kit_collect_files _kit_is_image_file false image "$TMP/images/a.jpg" "$TMP/images"; rc=$?
assert_status "deduplicates mixed inputs" "$rc" 0
assert_equals "mixed input keeps first occurrence" "${reply[*]}" "$TMP/images/a.jpg $TMP/images/b.PNG"
assert_equals "tracks explicit and directory origins" "${(j:|:)reply_origins}" "|$TMP/images"
assert_equals "tracks paths below directory inputs" "${(j:|:)reply_relatives}" "a.jpg|b.PNG"

_kit_collect_files _kit_is_image_file true image "$TMP/images"; rc=$?
_kit_default_output_path "${reply[3]}" "${reply_origins[3]}" "${reply_relatives[3]}" resized -resized jpg
assert_equals "default output preserves a nested source path" "$REPLY" "$TMP/images/resized/nested/c-resized.jpg"

_kit_collect_files _kit_is_image_file false image "$TMP/images/readme.txt" >/dev/null 2>&1; rc=$?
assert_status "rejects an explicit unsupported file" "$rc" 1

_kit_collect_files _kit_is_image_file false image "$TMP/empty" >/dev/null 2>&1; rc=$?
assert_status "rejects an empty matching set" "$rc" 1

_kit_collect_files _kit_is_image_file false image >/dev/null 2>&1; rc=$?
assert_status "requires a target" "$rc" 2

_kit_prepare_output_dir "$TMP/new-output"; rc=$?
assert_status "creates an output directory" "$rc" 0
[[ -d "$TMP/new-output" ]] && pass "output directory exists" || fail "output directory exists" "directory was not created"

touch "$TMP/not-a-directory"
_kit_prepare_output_dir "$TMP/not-a-directory" >/dev/null 2>&1; rc=$?
assert_status "rejects an output path that is a file" "$rc" 1

print -r -- ""
print -r -- "Passed: $PASS"
print -r -- "Failed: $FAIL"
(( FAIL == 0 ))
