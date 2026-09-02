#!/bin/zsh
# Hermetic batch input tests for image and PDF commands.

emulate -L zsh
setopt no_unset pipe_fail

typeset -i PASS=0 FAIL=0
ROOT="${0:A:h:h}"
TMP="${${TMPDIR:-/tmp}%/}/kit-file-transforms-test.$$"

pass() { print -r -- "ok - $1"; PASS+=1 }
fail() { print -r -- "not ok - $1"; print -r -- "  $2"; FAIL+=1 }
assert_status() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "expected status $3, got $2" }
assert_file() { [[ -f "$2" ]] && pass "$1" || fail "$1" "missing file: $2" }

cleanup() { rm -rf "$TMP" }
trap cleanup EXIT INT TERM

mkdir -p "$TMP/bin" "$TMP/images/nested" "$TMP/pdfs/nested"

cat > "$TMP/bin/magick" <<'EOF'
#!/bin/zsh
args=("$@")
output="${args[-1]}"
mkdir -p "${output:h}"
: > "$output"
EOF

cat > "$TMP/bin/qpdf" <<'EOF'
#!/bin/zsh
for arg in "$@"; do
    if [[ "$arg" == "--show-npages" ]]; then
        print -r -- 2
        exit 0
    fi
done
args=("$@")
output="${args[-1]}"
output="${output//\%d/1}"
mkdir -p "${output:h}"
: > "$output"
EOF

chmod +x "$TMP/bin/magick" "$TMP/bin/qpdf"
PATH="$TMP/bin:$PATH"
rehash

source "$ROOT/lib/kit-files.zsh"
source "$ROOT/functions/images.sh"
source "$ROOT/functions/pdf.sh"
_kit_require() { command -v "$1" >/dev/null 2>&1 }

touch "$TMP/images/a.jpg" "$TMP/images/b.png" "$TMP/images/skip.txt"
touch "$TMP/images/nested/c.webp"
touch "$TMP/pdfs/a.pdf" "$TMP/pdfs/b.PDF" "$TMP/pdfs/skip.txt"
touch "$TMP/pdfs/nested/c.pdf"

img-resize 100x100 "$TMP/images/a.jpg" "$TMP/images/b.png" >/dev/null; rc=$?
assert_status "img-resize accepts multiple files" "$rc" 0
assert_file "img-resize creates first output" "$TMP/images/a-resized.jpg"
assert_file "img-resize creates second output" "$TMP/images/b-resized.png"

img-resize 100x100 "$TMP/images" >/dev/null; rc=$?
assert_status "img-resize accepts a folder without output options" "$rc" 0
assert_file "img-resize creates its default result folder" "$TMP/images/resized/a-resized.jpg"

img-thumbnail 80x80 "$TMP/images/nested" --recursive --output-dir "$TMP/thumbs" >/dev/null; rc=$?
assert_status "img-thumbnail accepts a directory" "$rc" 0
assert_file "img-thumbnail creates directory output" "$TMP/thumbs/c-resized.webp"

img-convert jpg webp "$TMP/images/a.jpg" --output-dir "$TMP/converted" >/dev/null; rc=$?
assert_status "img-convert accepts a file" "$rc" 0
assert_file "img-convert creates converted output" "$TMP/converted/a.webp"

mkdir -p "$TMP/image-convert/nested"
touch "$TMP/image-convert/one.jpg" "$TMP/image-convert/nested/two.jpg"
img-convert jpg webp "$TMP/image-convert" --recursive >/dev/null; rc=$?
assert_status "img-convert uses a default folder" "$rc" 0
assert_file "img-convert creates a folder result" "$TMP/image-convert/converted/one.webp"
assert_file "img-convert preserves nested paths" "$TMP/image-convert/converted/nested/two.webp"

pdf-compress "$TMP/pdfs/a.pdf" "$TMP/pdfs/b.PDF" --output-dir "$TMP/compressed" >/dev/null; rc=$?
assert_status "pdf-compress accepts multiple files" "$rc" 0
assert_file "pdf-compress creates first output" "$TMP/compressed/a_compressed.pdf"
assert_file "pdf-compress creates second output" "$TMP/compressed/b_compressed.pdf"

mkdir -p "$TMP/pdf-default/nested"
touch "$TMP/pdf-default/one.pdf" "$TMP/pdf-default/nested/two.pdf"
pdf-compress "$TMP/pdf-default" --recursive >/dev/null; rc=$?
assert_status "pdf-compress uses a default folder" "$rc" 0
assert_file "pdf-compress creates a folder result" "$TMP/pdf-default/compressed-pdf/one_compressed.pdf"
assert_file "pdf-compress preserves nested paths" "$TMP/pdf-default/compressed-pdf/nested/two_compressed.pdf"

pdf-split --pages 1 "$TMP/pdfs/a.pdf" "$TMP/pdfs/b.PDF" --output-dir "$TMP/split" >/dev/null; rc=$?
assert_status "pdf-split accepts multiple files" "$rc" 0
assert_file "pdf-split creates first output" "$TMP/split/a_pages_1.pdf"
assert_file "pdf-split creates second output" "$TMP/split/b_pages_1.pdf"

pdf-rotate --degrees 90 "$TMP/pdfs" --recursive --output-dir "$TMP/rotated" >/dev/null; rc=$?
assert_status "pdf-rotate accepts a recursive directory" "$rc" 0
assert_file "pdf-rotate creates nested-source output" "$TMP/rotated/c_rotated.pdf"

pdf-merge "$TMP/pdfs" --output "$TMP/merged.pdf" >/dev/null; rc=$?
assert_status "pdf-merge expands a directory" "$rc" 0
assert_file "pdf-merge creates one output" "$TMP/merged.pdf"

pdf-burst "$TMP/pdfs/a.pdf" "$TMP/pdfs/b.PDF" --pages-per-file 2 --output-dir "$TMP/burst" >/dev/null; rc=$?
assert_status "pdf-burst accepts multiple files" "$rc" 0
assert_file "pdf-burst keeps first input outputs separate" "$TMP/burst/a_burst/page_1.pdf"
assert_file "pdf-burst keeps second input outputs separate" "$TMP/burst/b_burst/page_1.pdf"

print -r -- ""
print -r -- "Passed: $PASS"
print -r -- "Failed: $FAIL"
(( FAIL == 0 ))
