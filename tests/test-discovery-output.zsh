#!/bin/zsh
# Hermetic characterization tests for help/search/category/completion discovery output.

emulate -L zsh
setopt no_unset pipe_fail

typeset -i PASS=0 FAIL=0
ROOT="${0:A:h:h}"
TMP="${${TMPDIR:-/tmp}%/}/kit-discovery-output-test.$$"
TMP="${TMP:A}"
FIXTURE="$TMP/kit"
HOME_DIR="$TMP/home"

pass() { print -r -- "ok - $1"; PASS+=1 }
fail() { print -r -- "not ok - $1"; print -r -- "  $2"; FAIL+=1 }
assert_status() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "expected status $3, got $2" }
assert_contains() { [[ "$2" == *"$3"* ]] && pass "$1" || fail "$1" "expected output to contain: $3\noutput was: $2" }
assert_not_contains() { [[ "$2" != *"$3"* ]] && pass "$1" || fail "$1" "expected output not to contain: $3\noutput was: $2" }

cleanup() { rm -rf "$TMP" }
trap cleanup EXIT INT TERM

mkdir -p "$FIXTURE" "$FIXTURE/lib" "$HOME_DIR" "$TMP/work" "$TMP/project" "$TMP/bin"
ln -s "$ROOT/loader.zsh" "$FIXTURE/loader.zsh"
ln -s "$ROOT/lib/kit-core.zsh" "$FIXTURE/lib/kit-core.zsh"
ln -s "$ROOT/functions" "$FIXTURE/functions"
ln -s "$ROOT/completions" "$FIXTURE/completions"
ln -s "$ROOT/categories.conf" "$FIXTURE/categories.conf"
ln -s "$ROOT/VERSION" "$FIXTURE/VERSION"

cat > "$TMP/bin/fake-editor" <<'EOF'
#!/bin/zsh
return 0
EOF
chmod +x "$TMP/bin/fake-editor"

write_configs() {
  print -r -- "proj|$TMP/project|Fixture project shortcut" > "$FIXTURE/shortcuts.conf"
  print -r -- "edit|fake-editor|Fixture fake editor" > "$FIXTURE/editor.conf"
}

run_zsh() {
  local code="$1"
  KIT_EXT_DIR="$FIXTURE" HOME="$HOME_DIR" PATH="$TMP/bin:$PATH" \
    zsh -fc "emulate -L zsh; cd ${(q)TMP}/work; $code" 2>&1
}

write_configs

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit -h'); rc=$?
assert_status "kit -h exits 0" "$rc" 0
assert_contains "kit -h includes Image Processing category" "$out" "Image Processing"
assert_contains "kit -h includes System Utilities category" "$out" "System Utilities"
assert_contains "kit -h includes Quick Navigation when shortcuts enabled" "$out" "Quick Navigation"
assert_contains "kit -h includes Editor Shortcuts when editors enabled" "$out" "Editor Shortcuts"
assert_contains "kit -h includes configured shortcut name" "$out" "proj"
assert_contains "kit -h includes configured shortcut description" "$out" "Fixture project shortcut"
assert_contains "kit -h includes configured editor name" "$out" "edit"
assert_contains "kit -h includes configured editor description" "$out" "Fixture fake editor"

out=$(KIT_AUTO_SHORTCUTS=false KIT_AUTO_EDITORS=false run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit -h'); rc=$?
assert_status "kit -h with auto config disabled exits 0" "$rc" 0
assert_not_contains "kit -h omits Quick Navigation when shortcuts disabled" "$out" "Quick Navigation"
assert_not_contains "kit -h omits Editor Shortcuts when editors disabled" "$out" "Editor Shortcuts"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit --search resize'); rc=$?
assert_status "kit --search resize exits 0" "$rc" 0
assert_contains "kit --search resize includes function result" "$out" "img-resize"
assert_contains "kit --search resize includes function category" "$out" "Image Processing"
assert_not_contains "kit --search resize excludes shortcut descriptions" "$out" "Fixture project shortcut"
assert_not_contains "kit --search resize excludes editor descriptions" "$out" "Fixture fake editor"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit --search >/dev/null; print -r -- status:$?')
assert_contains "kit --search missing keyword returns 2" "$out" "status:2"

out=$(run_zsh 'source "$KIT_EXT_DIR/loader.zsh" >/dev/null; kit --list-categories'); rc=$?
assert_status "kit --list-categories exits 0" "$rc" 0
assert_contains "kit --list-categories includes Image Processing" "$out" "Image Processing"
assert_contains "kit --list-categories includes System Utilities" "$out" "System Utilities"
assert_contains "kit --list-categories includes function counts" "$out" "functions)"

out=$(run_zsh '
  path=(/bin /usr/bin /usr/local/bin "$path[@]")
  _describe() { local group="$1" array_name="$2"; print -r -- "DESCRIBE:$group"; eval "printf '\''%s\\n'\'' \"\${${array_name}[@]}\""; }
  _files() { print -r -- "FILES"; }
  _values() { print -r -- "VALUES:$*"; }
  source_completion() {
    local CURRENT=2
    local -a words=(kit "")
    source "$KIT_EXT_DIR/completions/_kit"
    print -r -- HELPERS
    _kit_get_commands
    print -r -- SHORTCUTS
    _kit_get_shortcuts
    print -r -- EDITORS
    _kit_get_editors
    CURRENT=4
    words=(kit convert-to-mp3 --preset "")
    _kit_get_custom_completion convert-to-mp3 "$CURRENT"
    CURRENT=3
    words=(kit remove-audio -)
    _kit_get_custom_completion remove-audio "$CURRENT"
    CURRENT=4
    words=(kit compress-video --preset "")
    _kit_get_custom_completion compress-video "$CURRENT"
    print -r -- YT_MP3_OPTIONS
    CURRENT=5
    words=(kit yt-download mp3 https://example.com --)
    _kit_get_custom_completion yt-download "$CURRENT"
  }
  source_completion
')
assert_contains "completion source emits controlled command describe output" "$out" "DESCRIBE:kit commands"
assert_contains "completion source includes --search special command" "$out" "--search:Search functions by keyword"
assert_contains "completion source includes --list-categories special command" "$out" "--list-categories:List all categories"
assert_contains "completion source includes -h special command" "$out" "-h:Show help"
assert_contains "completion source includes --help special command" "$out" "--help:Show help"
assert_contains "completion _kit_get_commands includes module function" "$out" "img-resize"
assert_contains "completion _kit_get_shortcuts includes fixture shortcut" "$out" $'SHORTCUTS\nproj'
assert_contains "completion _kit_get_editors includes fixture editor" "$out" $'EDITORS\nedit'
assert_contains "completion command list includes function entry" "$out" "img-resize"
assert_contains "completion command list includes function category" "$out" "Image Processing"
assert_contains "completion command list includes shortcut entry" "$out" "proj:Fixture project shortcut"
assert_contains "completion command list includes editor entry" "$out" "edit:Fixture fake editor"
assert_contains "completion includes MP3 speech preset" "$out" "speech"
assert_contains "completion includes MP3 standard preset" "$out" "standard"
assert_contains "completion includes remove-audio reencode option" "$out" "--reencode"
assert_contains "completion includes video encoder presets" "$out" "veryslow"
assert_contains "yt-download option prefix takes priority over quality values" "$out" $'YT_MP3_OPTIONS\nVALUES:options'
assert_not_contains "completion helper output has no unexpected missing-file noise" "$out" "no such file"
assert_not_contains "completion helper output has no command-not-found noise" "$out" "command not found"

print -r -- ""
print -r -- "Passed: $PASS"
print -r -- "Failed: $FAIL"
(( FAIL == 0 ))
