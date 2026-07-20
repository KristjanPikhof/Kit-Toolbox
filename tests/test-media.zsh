#!/bin/zsh
# Hermetic contract tests for media conversion commands.

emulate -L zsh
setopt no_unset pipe_fail

typeset -i PASS=0 FAIL=0
ROOT="${0:A:h:h}"
TMP="${${TMPDIR:-/tmp}%/}/kit-media-test.$$"
TMP="${TMP:A}"
MEDIA="$ROOT/functions/media.sh"

pass() { print -r -- "ok - $1"; PASS+=1 }
fail() { print -r -- "not ok - $1"; print -r -- "  $2"; FAIL+=1 }
assert_status() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "expected status $3, got $2" }
assert_contains() { [[ "$2" == *"$3"* ]] && pass "$1" || fail "$1" "expected output to contain: $3\noutput was: $2" }
assert_equals() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "expected: $3\nactual: $2" }
assert_file_exists() { [[ -f "$2" ]] && pass "$1" || fail "$1" "missing file: $2" }

cleanup() { rm -rf "$TMP" }
trap cleanup EXIT INT TERM

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    print -r -- "ok - media contracts skipped (ffmpeg and ffprobe required)"
    exit 0
fi

mkdir -p "$TMP/bin"
export KIT_YTDLP_LOG="$TMP/yt-dlp.args"

cat > "$TMP/bin/yt-dlp" <<'EOF'
#!/bin/zsh
: > "$KIT_YTDLP_LOG"
for arg in "$@"; do
    print -r -- "$arg" >> "$KIT_YTDLP_LOG"
done
EOF
chmod +x "$TMP/bin/yt-dlp"
PATH="$TMP/bin:$PATH"
rehash

source "$MEDIA"
_kit_require() { command -v "$1" >/dev/null 2>&1 }

ffmpeg -v error -nostdin \
    -f lavfi -i 'testsrc2=duration=2:size=640x360:rate=24' \
    -f lavfi -i 'sine=frequency=1000:duration=2' \
    -map 0:v:0 -map 1:a:0 \
    -c:v libx264 -preset ultrafast -crf 30 -pix_fmt yuv420p \
    -c:a aac -b:a 64k "$TMP/video.mp4"
fixture_rc=$?
assert_status "video fixture generation succeeds" "$fixture_rc" 0

ffmpeg -v error -nostdin -f lavfi -i 'sine=frequency=440:duration=2' \
    -c:a aac -b:a 64k "$TMP/voice sample.m4a"
fixture_rc=$?
assert_status "audio fixture generation succeeds" "$fixture_rc" 0

cat > "$TMP/caption.srt" <<'EOF'
1
00:00:00,000 --> 00:00:01,000
Test caption
EOF
ffmpeg -v error -nostdin \
    -f lavfi -i 'testsrc2=duration=2:size=640x360:rate=24' \
    -f lavfi -i 'sine=frequency=1000:duration=2' \
    -f srt -i "$TMP/caption.srt" \
    -map 0:v:0 -map 1:a:0 -map 2:s:0 \
    -c:v libx264 -preset ultrafast -crf 30 -pix_fmt yuv420p \
    -c:a aac -b:a 64k -c:s srt "$TMP/captioned.mkv"
fixture_rc=$?
assert_status "captioned fixture generation succeeds" "$fixture_rc" 0

out=$(convert-to-mp3 "$TMP/voice sample.m4a" --preset speech --output "$TMP/speech.mp3" 2>&1)
rc=$?
assert_status "convert-to-mp3 speech preset succeeds" "$rc" 0
assert_file_exists "convert-to-mp3 honors custom output" "$TMP/speech.mp3"
codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$TMP/speech.mp3" 2>/dev/null)
sample_rate=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "$TMP/speech.mp3" 2>/dev/null)
channels=$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=nw=1:nk=1 "$TMP/speech.mp3" 2>/dev/null)
assert_equals "speech preset produces MP3" "$codec" "mp3"
assert_equals "speech preset uses 24 kHz" "$sample_rate" "24000"
assert_equals "speech preset uses mono" "$channels" "1"

out=$(convert-to-mp3 "$TMP/voice sample.m4a" 2>&1)
rc=$?
assert_status "convert-to-mp3 standard default succeeds" "$rc" 0
assert_file_exists "convert-to-mp3 default output preserves spaces" "$TMP/voice sample.mp3"
standard_bitrate=$(ffprobe -v error -show_entries format=bit_rate -of default=nw=1:nk=1 "$TMP/voice sample.mp3" 2>/dev/null)
if [[ "$standard_bitrate" == <1-319999> ]]; then
    pass "standard default does not force 320 kbps"
else
    fail "standard default does not force 320 kbps" "bitrate was: ${standard_bitrate:-missing}"
fi

out=$(convert-to-mp3 "$TMP/voice sample.m4a" --output "$TMP/.hidden.mp3" 2>&1)
rc=$?
assert_status "convert-to-mp3 supports hidden output filenames" "$rc" 0
assert_file_exists "hidden MP3 output is created" "$TMP/.hidden.mp3"

out=$(convert-to-mp3 "$TMP/voice sample.m4a" --output "$TMP/.mp3" 2>&1)
rc=$?
assert_status "convert-to-mp3 supports a bare hidden MP3 output" "$rc" 0
assert_file_exists "bare hidden MP3 output is created" "$TMP/.mp3"

cp "$TMP/voice sample.m4a" "$TMP/.hidden-source.m4a"
out=$(convert-to-mp3 "$TMP/.hidden-source.m4a" 2>&1)
rc=$?
assert_status "convert-to-mp3 supports hidden input filenames" "$rc" 0
assert_file_exists "hidden input uses the correct default stem" "$TMP/.hidden-source.mp3"

out=$(convert-to-mp3 "$TMP/voice sample.m4a" --bitrate 64 --output "$TMP/custom.mp3" 2>&1)
rc=$?
assert_status "convert-to-mp3 custom bitrate succeeds" "$rc" 0
custom_bitrate=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=nw=1:nk=1 "$TMP/custom.mp3" 2>/dev/null)
assert_equals "custom bitrate is applied" "$custom_bitrate" "64000"

ffmpeg -v error -nostdin -f lavfi -i 'sine=frequency=880:duration=1' \
    -c:a libmp3lame -b:a 64k "$TMP/already.mp3"
before_checksum=$(cksum < "$TMP/already.mp3")
out=$(convert-to-mp3 "$TMP/already.mp3" --force 2>&1)
rc=$?
after_checksum=$(cksum < "$TMP/already.mp3" 2>/dev/null)
assert_status "same-path MP3 conversion is rejected" "$rc" 2
assert_equals "same-path rejection preserves input" "$after_checksum" "$before_checksum"

print -r -- "invalid media" > "$TMP/broken.m4a"
print -r -- "existing output" > "$TMP/protected.mp3"
out=$(convert-to-mp3 "$TMP/broken.m4a" --force --output "$TMP/protected.mp3" 2>&1)
rc=$?
assert_status "failed forced conversion returns failure" "$rc" 1
protected_contents=$(<"$TMP/protected.mp3")
assert_equals "failed forced conversion preserves existing output" "$protected_contents" "existing output"
temporary_count=$(find "$TMP" -name '*.kit-tmp.*' -type f | wc -l | tr -d ' ')
assert_equals "failed conversion cleans temporary output" "$temporary_count" "0"

out=$(convert-to-mp3 "$TMP/voice sample.m4a" --unknown 2>&1)
rc=$?
assert_status "convert-to-mp3 rejects unknown options" "$rc" 2
out=$(convert-to-mp3 "$TMP/voice sample.m4a" --bitrate 0 2>&1)
rc=$?
assert_status "convert-to-mp3 validates bitrate" "$rc" 2
out=$(convert-to-mp3 "$TMP/voice sample.m4a" --preset speech --bitrate 64 2>&1)
rc=$?
assert_status "convert-to-mp3 rejects conflicting quality controls" "$rc" 2

out=$(remove-audio "$TMP/video.mp4" --output "$TMP/muted.mp4" 2>&1)
rc=$?
assert_status "remove-audio stream copy succeeds" "$rc" 0
assert_file_exists "remove-audio honors custom output" "$TMP/muted.mp4"
audio_streams=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$TMP/muted.mp4" 2>/dev/null | wc -l | tr -d ' ')
assert_equals "remove-audio removes every audio stream" "$audio_streams" "0"
input_video_hash=$(ffmpeg -v error -nostdin -i "$TMP/video.mp4" -map 0:v:0 -c copy -f hash -hash sha256 - 2>/dev/null)
muted_video_hash=$(ffmpeg -v error -nostdin -i "$TMP/muted.mp4" -map 0:v:0 -c copy -f hash -hash sha256 - 2>/dev/null)
assert_equals "remove-audio preserves encoded video packets" "$muted_video_hash" "$input_video_hash"

out=$(remove-audio "$TMP/video.mp4" --reencode --output "$TMP/muted-reencoded.mp4" 2>&1)
rc=$?
assert_status "remove-audio explicit re-encode succeeds" "$rc" 0
reencoded_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$TMP/muted-reencoded.mp4" 2>/dev/null)
assert_equals "remove-audio re-encode uses H.264" "$reencoded_codec" "h264"

out=$(remove-audio "$TMP/captioned.mkv" --output "$TMP/captioned-muted.mkv" 2>&1)
rc=$?
assert_status "remove-audio succeeds with subtitle streams" "$rc" 0
subtitle_streams=$(ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "$TMP/captioned-muted.mkv" 2>/dev/null | wc -l | tr -d ' ')
assert_equals "remove-audio preserves subtitle streams" "$subtitle_streams" "1"
audio_streams=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$TMP/captioned-muted.mkv" 2>/dev/null | wc -l | tr -d ' ')
assert_equals "captioned remove-audio output has no audio" "$audio_streams" "0"

out=$(compress-video "$TMP/video.mp4" --preset ultrafast --output "$TMP/compressed.mp4" 2>&1)
rc=$?
assert_status "compress-video default succeeds" "$rc" 0
compressed_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$TMP/compressed.mp4" 2>/dev/null)
assert_equals "compress-video does not upscale" "$compressed_width" "640"

out=$(compress-video "$TMP/video.mp4" --preset ultrafast --width 320 --output "$TMP/compressed-320.mp4" 2>&1)
rc=$?
assert_status "compress-video maximum width succeeds" "$rc" 0
compressed_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$TMP/compressed-320.mp4" 2>/dev/null)
assert_equals "compress-video shrinks above maximum width" "$compressed_width" "320"

out=$(compress-video "$TMP/video.mp4" --preset ultrafast --width 319 --output "$TMP/compressed-odd-width.mp4" 2>&1)
rc=$?
assert_status "compress-video accepts an odd maximum width" "$rc" 0
compressed_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$TMP/compressed-odd-width.mp4" 2>/dev/null)
assert_equals "compress-video rounds an odd maximum width down" "$compressed_width" "318"

out=$(compress-video "$TMP/video.mp4" --width 0 --output "$TMP/invalid-width.mp4" 2>&1)
rc=$?
assert_status "compress-video rejects zero width" "$rc" 2
out=$(compress-video "$TMP/video.mp4" --width 1 --output "$TMP/too-small-width.mp4" 2>&1)
rc=$?
assert_status "compress-video rejects widths below two pixels" "$rc" 2
out=$(compress-video "$TMP/video.mp4" --bitrate nope --output "$TMP/invalid-bitrate.mp4" 2>&1)
rc=$?
assert_status "compress-video validates audio bitrate" "$rc" 2

print -r -- "input" > "$TMP/race-input.dat"
race_output="$TMP/race-output.dat"
(
    ffmpeg() {
        local destination="${@[-1]}"
        (sleep 0.05; print -r -- "protected" > "$race_output") &
        local creator_pid=$!
        sleep 0.1
        print -r -- "converted" > "$destination"
        wait "$creator_pid"
    }
    _kit_media_run_ffmpeg "$TMP/race-input.dat" "$race_output" false false
) > "$TMP/race.log" 2>&1
rc=$?
assert_status "non-force finalization rejects an output created during conversion" "$rc" 1
race_contents=$(<"$race_output")
assert_equals "non-force finalization preserves the concurrent output" "$race_contents" "protected"
temporary_count=$(find "$TMP" -name '*.kit-tmp.*' -type f | wc -l | tr -d ' ')
assert_equals "non-force race cleanup removes temporary output" "$temporary_count" "0"

out=$(yt-download mp3 "https://example.com/audio" 2>&1)
rc=$?
assert_status "yt-download MP3 invocation succeeds" "$rc" 0
yt_args=$(<"$KIT_YTDLP_LOG")
assert_contains "yt-download MP3 uses balanced quality" "$yt_args" $'--audio-quality\n5'
assert_contains "yt-download avoids overwrites by default" "$yt_args" "--no-overwrites"

out=$(yt-download mp4 "https://example.com/video" 2>&1)
rc=$?
assert_status "yt-download MP4 invocation succeeds" "$rc" 0
yt_args=$(<"$KIT_YTDLP_LOG")
assert_contains "yt-download requests MP4 merge output" "$yt_args" $'--merge-output-format\nmp4'
assert_contains "yt-download requests MP4 remux" "$yt_args" $'--remux-video\nmp4'

out=$(yt-download mp3 "https://example.com/audio" 11 2>&1)
rc=$?
assert_status "yt-download rejects invalid MP3 quality" "$rc" 2

print -r -- ""
print -r -- "Passed: $PASS"
print -r -- "Failed: $FAIL"
(( FAIL == 0 ))
