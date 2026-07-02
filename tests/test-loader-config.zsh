#!/bin/zsh
# Focused, hermetic characterization tests for loader-generated shortcuts/editors.

emulate -L zsh
setopt no_unset pipe_fail

typeset -i PASS=0 FAIL=0
ROOT="${0:A:h:h}"
TMP="${${TMPDIR:-/tmp}%/}/kit-loader-config-test.$$"
TMP="${TMP:A}"
FIXTURE="$TMP/kit"
HOME_DIR="$TMP/home"

pass() { print -r -- "ok - $1"; PASS+=1 }
fail() { print -r -- "not ok - $1"; print -r -- "  $2"; FAIL+=1 }
assert_status() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "expected status $3, got $2" }
assert_contains() { [[ "$2" == *"$3"* ]] && pass "$1" || fail "$1" "expected output to contain: $3\noutput was: $2" }
assert_not_contains() { [[ "$2" != *"$3"* ]] && pass "$1" || fail "$1" "expected output not to contain: $3\noutput was: $2" }
assert_file_exists() { [[ -e "$2" ]] && pass "$1" || fail "$1" "missing file: $2" }
assert_file_absent() { [[ ! -e "$2" ]] && pass "$1" || fail "$1" "unexpected file exists: $2" }

cleanup() { rm -rf "$TMP" }
trap cleanup EXIT INT TERM

mkdir -p "$FIXTURE" "$FIXTURE/lib" "$HOME_DIR" "$HOME_DIR/goto-target" "$HOME_DIR/tilde-target" "$TMP/target-one" "$TMP/target-two" "$TMP/target with spaces" "$TMP/work" "$TMP/bin"
ln -s "$ROOT/loader.zsh" "$FIXTURE/loader.zsh"
ln -s "$ROOT/lib/kit-core.zsh" "$FIXTURE/lib/kit-core.zsh"
ln -s "$ROOT/functions" "$FIXTURE/functions"
ln -s "$ROOT/completions" "$FIXTURE/completions"
ln -s "$ROOT/categories.conf" "$FIXTURE/categories.conf"
ln -s "$ROOT/VERSION" "$FIXTURE/VERSION"
touch "$TMP/work/existing.txt"

cat > "$TMP/bin/fake-editor" <<'EOF'
#!/bin/zsh
print -r -- "$0|$*" >> "$KIT_FAKE_EDITOR_LOG"
print -r -- "CALL:${0:t}:argc=$#" >> "$KIT_FAKE_EDITOR_LOG"
local i=1
for arg in "$@"; do
  print -r -- "CALL:${0:t}:argv[$i]=$arg" >> "$KIT_FAKE_EDITOR_LOG"
  i=$((i + 1))
done
EOF
chmod +x "$TMP/bin/fake-editor"
cp "$TMP/bin/fake-editor" "$TMP/bin/fake-open"
cp "$TMP/bin/fake-editor" "$TMP/bin/fake editor"
chmod +x "$TMP/bin/fake-open" "$TMP/bin/fake editor"

write_configs() {
  local shortcuts="$1" editors="$2"
  print -rn -- "$shortcuts" > "$FIXTURE/shortcuts.conf"
  print -rn -- "$editors" > "$FIXTURE/editor.conf"
  : > "$TMP/editor.log"
}

run_zsh() {
  local code="$1"
  KIT_EXT_DIR="$FIXTURE" HOME="$HOME_DIR" PATH="$TMP/bin:$PATH" KIT_FAKE_EDITOR_LOG="$TMP/editor.log" \
    zsh -fc "emulate -L zsh; cd ${(q)TMP}/work; $code" 2>&1
}

# Shortcut behavior.
write_configs "proj|$TMP/target-one|Project shortcut
spaceproj|$TMP/target with spaces|Project shortcut with spaces
tildeproj|~/tilde-target|Project shortcut with tilde
" "edit|fake-editor|Fake editor
classic|fake-editor --classic|Fake editor with flag
quoted|fake-editor '--quoted arg'|Fake editor with quoted arg
openapp|fake-open -a \"Fake App\"|Fake open app
spaceexe|\"$TMP/bin/fake editor\" --flag|Fake executable path with spaces
"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit proj >/dev/null; print -r -- $PWD'); rc=$?
assert_status "kit <shortcut> changes PWD" "$rc" 0
assert_contains "kit <shortcut> entered target" "$out" "$TMP/target-one"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; proj >/dev/null; print -r -- $PWD'); rc=$?
assert_status "direct <shortcut> changes PWD" "$rc" 0
assert_contains "direct <shortcut> entered target" "$out" "$TMP/target-one"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit spaceproj >/dev/null; print -r -- $PWD'); rc=$?
assert_status "shortcut path with spaces changes PWD" "$rc" 0
assert_contains "shortcut path with spaces entered target" "$out" "$TMP/target with spaces"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit tildeproj >/dev/null; print -r -- $PWD'); rc=$?
assert_status "shortcut path with tilde changes PWD" "$rc" 0
assert_contains "shortcut path with tilde expands HOME" "$out" "$HOME_DIR/tilde-target"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; declare -f proj >/dev/null; print -r -- $?'); rc=$?
assert_status "shortcut function is generated" "$rc" 0
assert_contains "declare -f sees shortcut" "$out" "0"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; declare -f proj; print -r -- SPLIT; declare -f spaceproj')
assert_contains "shortcut wrapper delegates to _kit_run_shortcut" "$out" "_kit_run_shortcut proj"
assert_contains "shortcut path-with-spaces wrapper delegates to _kit_run_shortcut" "$out" "_kit_run_shortcut spaceproj"
assert_not_contains "shortcut wrapper does not embed target path" "$out" "$TMP/target-one"
assert_not_contains "shortcut path-with-spaces wrapper does not embed target path" "$out" "$TMP/target with spaces"

out=$(KIT_AUTO_SHORTCUTS=false run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; declare -f proj >/dev/null; print -r -- declare:$?; kit proj >/dev/null; print -r -- kit:$?')
assert_contains "KIT_AUTO_SHORTCUTS=false creates no shortcut function" "$out" "declare:1"
assert_contains "KIT_AUTO_SHORTCUTS=false makes kit shortcut return 127" "$out" "kit:127"

write_configs "dupe|$TMP/target-one|First
dupe|$TMP/target-two|Second
" ""
out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh"; dupe >/dev/null; print -r -- $PWD')
assert_contains "duplicate shortcut warns" "$out" "Duplicate shortcut 'dupe'"
assert_contains "duplicate shortcut first entry wins" "$out" "$TMP/target-one"

write_configs "1bad|$TMP/target-one|Invalid
unsafe|$TMP/\$(touch $TMP/pwned)|Unsafe
" ""
out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh"; declare -f 1bad >/dev/null; print -r -- bad:$?; declare -f unsafe >/dev/null; print -r -- unsafe:$?')
assert_contains "invalid shortcut name rejected" "$out" "Invalid shortcut name '1bad'"
assert_contains "invalid shortcut has no function" "$out" "bad:1"
assert_contains "unsafe shortcut path rejected" "$out" "Invalid path"
assert_contains "unsafe shortcut has no function" "$out" "unsafe:1"
assert_file_absent "unsafe shortcut path did not execute command substitution" "$TMP/pwned"

write_configs "move|$TMP/target-one|Move
" ""
out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; print -r -- "move|'$TMP'/target-two|Move" > "$KIT_EXT_DIR/shortcuts.conf"; source "$KIT_EXT_DIR/loader.zsh" >/dev/null; move >/dev/null; print -r -- $PWD')
assert_contains "re-sourcing updates kit-created shortcut" "$out" "$TMP/target-two"

write_configs "stale|$TMP/target-one|Stale before resourcing
" ""
out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; print -r -- "stale|'$TMP'/target-two|Stale after config edit" > "$KIT_EXT_DIR/shortcuts.conf"; stale >/dev/null; print -r -- $PWD')
assert_contains "config change without re-source keeps old embedded shortcut path" "$out" "$TMP/target-one"
assert_not_contains "config change without re-source does not use new shortcut path" "$out" "$TMP/target-two"

# Editor behavior.
write_configs "proj|$TMP/target-one|Project shortcut
" "edit|fake-editor|Fake editor
classic|fake-editor --classic|Fake editor with flag
quoted|fake-editor '--quoted arg'|Fake editor with quoted arg
"
print -r -- "openapp|fake-open -a \"Fake App\"|Fake open app" >> "$FIXTURE/editor.conf"
print -r -- "spaceexe|\"$TMP/bin/fake editor\" --flag|Fake executable path with spaces" >> "$FIXTURE/editor.conf"
out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit edit -h; edit -h')
assert_contains "kit <editor> -h shows usage" "$out" "Usage: kit edit <file|folder>"
assert_contains "direct <editor> -h shows usage" "$out" "Description: Open file or folder with Fake editor"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; declare -f edit; print -r -- SPLIT; declare -f classic; print -r -- SPLIT; declare -f quoted')
assert_contains "editor wrapper delegates to _kit_run_editor" "$out" "_kit_run_editor edit"
assert_not_contains "editor wrapper does not embed editor command" "$out" "fake-editor"
assert_not_contains "editor wrapper does not embed editor flag" "$out" "--classic"
assert_not_contains "editor wrapper does not embed quoted editor arg" "$out" "--quoted arg"
assert_not_contains "editor wrapper does not embed editor description" "$out" "Fake editor"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit edit existing.txt; edit existing.txt; classic existing.txt; quoted existing.txt; openapp existing.txt; spaceexe existing.txt; print -r -- LOG; cat "$KIT_FAKE_EDITOR_LOG"')
assert_contains "kit <editor> invokes fake editor" "$out" "fake-editor|existing.txt"
assert_contains "direct <editor> invokes fake editor" "$out" "fake-editor|existing.txt"
assert_contains "editor command with arguments works" "$out" "fake-editor|--classic existing.txt"
assert_contains "editor command with quoted argument is passed without executing shell syntax" "$out" "--quoted arg"
assert_contains "quoted editor fixed behavior keeps quoted arg and target" "$out" "CALL:fake-editor:argc=2"
assert_contains "quoted editor fixed argv keeps quoted arg as one item" "$out" "CALL:fake-editor:argv[1]=--quoted arg"
assert_contains "quoted editor target remains separate argv item" "$out" "CALL:fake-editor:argv[2]=existing.txt"
assert_not_contains "quoted editor fixed argv has no leading quote artifact" "$out" "CALL:fake-editor:argv[1]='\\\\--quoted"
assert_not_contains "quoted editor fixed argv has no trailing quote artifact" "$out" "CALL:fake-editor:argv[2]=arg'\\\\"
assert_contains "fake-open app flag is separate argv item" "$out" "CALL:fake-open:argv[1]=-a"
assert_contains "fake-open quoted app name is one argv item" "$out" "CALL:fake-open:argv[2]=Fake App"
assert_contains "fake-open target is separate argv item" "$out" "CALL:fake-open:argv[3]=existing.txt"
assert_contains "quoted executable path with spaces runs" "$out" "CALL:fake editor:argc=2"
assert_contains "quoted executable path with spaces preserves flag" "$out" "CALL:fake editor:argv[1]=--flag"
assert_contains "quoted executable path with spaces preserves target" "$out" "CALL:fake editor:argv[2]=existing.txt"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; edit >/dev/null; print -r -- missing:$?; edit nope >/dev/null; print -r -- nonexistent:$?')
assert_contains "editor missing target returns 2" "$out" "missing:2"
assert_contains "editor nonexistent target returns 1" "$out" "nonexistent:1"

out=$(KIT_AUTO_EDITORS=false run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; declare -f edit >/dev/null; print -r -- declare:$?; kit edit >/dev/null; print -r -- kit:$?')
assert_contains "KIT_AUTO_EDITORS=false creates no editor function" "$out" "declare:1"
assert_contains "KIT_AUTO_EDITORS=false makes kit editor return 127" "$out" "kit:127"

write_configs "" "1edit|fake-editor|Invalid
evil|fake-editor; touch $TMP/editor-pwned|Unsafe
"
out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh"; declare -f 1edit >/dev/null; print -r -- bad:$?; declare -f evil >/dev/null; print -r -- evil:$?')
assert_contains "invalid editor name rejected" "$out" "Invalid editor name '1edit'"
assert_contains "unsafe editor command rejected" "$out" "Invalid editor command"
assert_contains "unsafe editor has no function" "$out" "evil:1"
assert_file_absent "unsafe editor command did not execute" "$TMP/editor-pwned"

write_configs "" "dupeedit|fake-editor --first|First editor
dupeedit|fake-editor --second|Second editor
"
out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh"; dupeedit existing.txt; print -r -- LOG; cat "$KIT_FAKE_EDITOR_LOG"')
assert_contains "duplicate editor warns" "$out" "Duplicate editor 'dupeedit'"
assert_contains "duplicate editor first entry wins" "$out" "CALL:fake-editor:argv[1]=--first"
assert_not_contains "duplicate editor second entry is not used" "$out" "--second"

write_configs "" "editconf|fake-editor|Conflicting editor
"
out=$(run_zsh 'editconf() { print -r -- user-editor; }; source "$KIT_EXT_DIR/loader.zsh"; kit editconf; print -r -- LOG; cat "$KIT_FAKE_EDITOR_LOG"')
assert_contains "pre-existing function conflict warns for editor" "$out" "Editor 'editconf' conflicts with existing function"
assert_contains "pre-existing function wins over editor" "$out" "user-editor"
assert_not_contains "pre-existing editor conflict does not invoke fake editor" "$out" "CALL:fake-editor"

write_configs "" "snapedit|fake-editor --old|Snapshot editor
"
out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; print -r -- "snapedit|fake-editor --new|Snapshot editor changed" > "$KIT_EXT_DIR/editor.conf"; snapedit existing.txt; print -r -- LOG; cat "$KIT_FAKE_EDITOR_LOG"')
assert_contains "editor config change without re-source keeps old embedded command" "$out" "CALL:fake-editor:argv[1]=--old"
assert_not_contains "editor config change without re-source does not use new command" "$out" "--new"

write_configs "" "resedit|fake-editor --old|Resourced editor
"
out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; print -r -- "resedit|fake-editor --new|Resourced editor changed" > "$KIT_EXT_DIR/editor.conf"; source "$KIT_EXT_DIR/loader.zsh" >/dev/null; resedit existing.txt; print -r -- LOG; cat "$KIT_FAKE_EDITOR_LOG"')
assert_contains "re-sourcing updates kit-created editor command" "$out" "CALL:fake-editor:argv[1]=--new"
assert_not_contains "re-sourcing editor command no longer uses old command" "$out" "--old"

# Conflict, dispatcher, and help behavior.
write_configs "conflict|$TMP/target-one|Conflict shortcut
gotohome|$HOME_DIR/goto-target|Goto target under HOME
" "edit|fake-editor|Fake editor
"
out=$(run_zsh 'conflict() { print -r -- preexisting; }; source "$KIT_EXT_DIR/loader.zsh"; kit conflict')
assert_contains "pre-existing function conflict warns" "$out" "conflicts with existing function"
assert_contains "pre-existing function wins over shortcut" "$out" "preexisting"

write_configs "same|$TMP/target-one|Same name shortcut
" "same|fake-editor|Same name editor
"
out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh"; kit same >/dev/null; print -r -- pwd:$PWD; print -r -- LOG; cat "$KIT_FAKE_EDITOR_LOG"')
assert_contains "shortcut/editor same-name precedence warns for editor" "$out" "Editor 'same' conflicts with existing function"
assert_contains "shortcut/editor same-name precedence uses shortcut" "$out" "pwd:$TMP/target-one"
assert_not_contains "shortcut/editor same-name precedence does not invoke editor" "$out" "fake-editor"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit nope >/dev/null; print -r -- unknown:$?; kit --search >/dev/null; print -r -- search_missing:$?; kit --search resize')
assert_contains "unknown command returns 127" "$out" "unknown:127"
assert_contains "kit --search missing keyword returns 2" "$out" "search_missing:2"
assert_contains "kit --search resize remains function-oriented" "$out" "img-resize"
assert_not_contains "kit --search resize does not list shortcut descriptions" "$out" "Conflict shortcut"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit -h')
assert_contains "kit -h includes shortcut section when enabled" "$out" "Quick Navigation"
assert_contains "kit -h includes editor section when enabled" "$out" "Editor Shortcuts"
out=$(KIT_AUTO_SHORTCUTS=false KIT_AUTO_EDITORS=false run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit -h')
assert_not_contains "kit -h omits shortcut section when disabled" "$out" "Quick Navigation"
assert_not_contains "kit -h omits editor section when disabled" "$out" "Editor Shortcuts"

write_configs "gotohome|$HOME_DIR/goto-target|Goto target under HOME
" ""
out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit goto gotohome >/dev/null; print -r -- status:$?; print -r -- pwd:$PWD')
assert_contains "kit goto <shortcut> emits deprecation warning" "$out" "deprecated"
assert_contains "kit goto <shortcut> still changes directory" "$out" "pwd:$HOME_DIR/goto-target"

print -r -- ""
print -r -- "Passed: $PASS"
print -r -- "Failed: $FAIL"
(( FAIL == 0 ))
