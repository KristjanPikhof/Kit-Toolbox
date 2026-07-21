# Kit Builder examples

These examples show the repository workflow and the contracts that commonly
need regression coverage. Use the closest production function as the final
source of style and behavior.

## Add an image command

Request: add `img-grayscale` to convert one image without modifying the input.

### Inspect and generate

Read a similar single-file function in `functions/images.sh`, then generate the
skeleton from the repository root:

```bash
bash scripts/new-function.sh images img-grayscale "Create a grayscale copy of an image"
```

The final interface might be:

```text
Usage: kit img-grayscale <input> [--output FILE] [--force]
Description: Create a grayscale copy without modifying the source image.
Examples:
  kit img-grayscale portrait.jpg
  kit img-grayscale portrait.jpg --output portrait-mono.jpg
```

Implementation checklist:

1. Parse `--output` only when a following value exists.
2. Reject extra positional arguments and unknown options with exit code `2`.
3. Use the shared ImageMagick dependency check.
4. Normalize and compare input/output paths.
5. Refuse an existing destination without `--force`.
6. Run ImageMagick with quoted argv, writing to a sibling temporary file.
7. Install the completed temporary file without clobbering a concurrent writer.
8. Add `img-grayscale` to the `# Functions:` header and README list.

Validate and smoke-test:

```zsh
zsh scripts/validate-pattern.sh functions/images.sh
zsh -fc 'export KIT_EXT_DIR=$PWD; source loader.zsh; kit img-grayscale -h'
```

Add a help entry to `tests/run-tests.sh` and focused or integration coverage for
spaces, an existing output, failed force behavior, and input/output identity.

## Add a safe media conversion

Request: add a media command that produces a local file with FFmpeg.

Reuse `_kit_media_run_ffmpeg` rather than rebuilding output handling. The helper
already checks path identity and existing destinations, preserves the output
extension in its temporary filename, verifies non-empty FFmpeg output, and
installs it with force or non-clobber semantics.

The implementation shape is:

```zsh
local -a ffmpeg_args=(<mapping and codec arguments>)
_kit_media_run_ffmpeg "$input" "$output" "$force" "$verbose" \
  "${ffmpeg_args[@]}" || return $?
_kit_media_report "Created" "$input" "$output"
```

Choose mapping deliberately. For example, removing audio should map all input
streams and then exclude audio, so subtitles and other non-audio streams are not
silently dropped:

```zsh
local -a ffmpeg_args=(
  -map 0
  -map -0:a
  -map_metadata 0
  -map_chapters 0
  -c copy
)
```

For H.264 scaling, keep both dimensions even and do not upscale:

```zsh
local scale_filter="scale='trunc(min(iw,$width)/2)*2':-2"
ffmpeg_args+=(-vf "$scale_filter")
```

Add regression assertions to `tests/test-media.zsh` for the exact stream or
dimension contract. The focused suite uses generated media and a fake `yt-dlp`,
so downloader argument checks do not need network access.

## Add command-specific completion

Request: complete presets and output paths for a new command.

Add a case in `_kit_get_custom_completion` and handle value-consuming options
before positional arguments:

```zsh
my-command)
    if [[ "$previous_word" == "-p" || "$previous_word" == "--preset" ]]; then
        _values 'preset' 'fast' 'balanced' 'quality'
        return 0
    fi
    if [[ "$previous_word" == "-o" || "$previous_word" == "--output" ]]; then
        _files
        return 0
    fi
    if [[ "$current_word" == -* ]]; then
        _values 'options' '-p' '--preset' '-o' '--output' '-f' '--force'
        return 0
    fi
    ;;
```

Add assertions to `tests/test-discovery-output.zsh` for:

- the preset value after `--preset`;
- path completion after `--output`;
- option completion for a leading `-`;
- positional completion before and after options.

Then run:

```zsh
zsh tests/test-discovery-output.zsh
./scripts/generate-completions.sh
```

## Add a category

Create a category only when no existing module owns the behavior. Start the file
with metadata used by loader discovery:

```zsh
# archive.sh - Archive creation and extraction utilities
# Category: Archive Processing
# Description: Create, inspect, and extract local archives
# Dependencies: tar
# Functions: archive-create
```

Register it in `categories.conf`:

```text
archive:Archive Processing:Create, inspect, and extract local archives
```

Add the implementation, discovery/completion assertions, README category, and
integration coverage before considering the category complete.

## Verify a completed change

```zsh
zsh scripts/validate-pattern.sh functions/<category>.sh

for test in tests/test-{kit-core,loader-config,discovery-output,media}.zsh; do
  zsh "$test" || break
done

zsh -n loader.zsh lib/kit-core.zsh functions/*.sh completions/_kit tests/*.zsh
bash -n scripts/new-function.sh scripts/generate-completions.sh tests/run-tests.sh
./scripts/generate-completions.sh
git diff --check
```

Use `zsh tests/run-tests.sh` when the change needs the live integration gate and
its asset recreation, network access, and cleanup prompt are acceptable.
