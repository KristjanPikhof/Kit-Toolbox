# Kit Builder reference

Use this page while implementing. Read [SKILL.md](SKILL.md) for the full
workflow and [`kit_pattern.md`](../../../llm_prompts/kit_pattern.md) for the
canonical repository pattern.

## Command reference

| Task | Command | Shell note |
|------|---------|------------|
| Generate a skeleton | `bash scripts/new-function.sh <category> <name> "Description"` | Bash-only path detection; file is not executable |
| Validate a module | `zsh scripts/validate-pattern.sh functions/<category>.sh` | Zsh script; file is not executable |
| Verify completions | `./scripts/generate-completions.sh` | Executable Bash script; do not run with Zsh |
| Smoke-test loader | `zsh -fc 'export KIT_EXT_DIR=$PWD; source loader.zsh; kit -h'` | Isolated Zsh |
| Run focused suites | `zsh tests/test-<name>.zsh` | Hermetic except real FFmpeg/FFprobe in media suite |
| Run integration | `zsh tests/run-tests.sh` | Recreates assets, may use network, prompts for cleanup |

Never execute `tests/run-tests.sh` directly. Its Bash shebang cannot load Kit’s
Zsh-only functions.

## Required module header

```zsh
# category.sh - Brief category description
# Category: Display name
# Description: What this module provides
# Dependencies: tool1, tool2 (or "none")
# Functions: function-one, function-two
```

The loader and completion system discover public functions from `# Functions:`.
Keep this line synchronized with the implementations.

## Help and exit codes

```text
Usage: kit function-name [options] <required>
Description: One precise sentence.
Options:
  -o, --output FILE  Write to FILE
  -f, --force        Replace FILE only after successful processing
Examples:
  kit function-name input.ext
  kit function-name input.ext --output result.ext
```

| Code | Meaning |
|-----:|---------|
| `0` | Help displayed or operation completed successfully |
| `1` | Runtime failure, missing file/dependency, or destination conflict |
| `2` | Invalid syntax, missing option value, invalid number/enum, or input/output identity |

## Argument parsing

Check consuming options before shifting:

```zsh
-o|--output)
    if [[ $# -lt 2 || -z "$2" ]]; then
        echo "Error: $1 requires a file" >&2
        return 2
    fi
    output="$2"
    shift 2
    ;;
```

Reject unknown flags and unexpected extra positional arguments. Validate digit
syntax before arithmetic; use decimal coercion such as `$((10#$value))` when
leading zeros are allowed.

## Safe command execution

```zsh
local -a cmd=(required_tool --input "$input")
[[ -n "$optional" ]] && cmd+=(--option "$optional")
cmd+=(--output "$temporary")

if ! "${cmd[@]}"; then
    echo "Error: Processing failed" >&2
    return 1
fi
```

Quote paths, build argv arrays, and never evaluate user input. Shell characters
inside a quoted filename are data, not code, so do not reject them wholesale.

## Output safety

File-producing commands follow this sequence:

1. Normalize and compare input and output paths.
2. Refuse an existing destination unless `--force` is explicit.
3. Create a sibling temporary name that ends with the intended filename or
   extension.
4. Run the tool against that temporary path.
5. Verify the result before installation.
6. In normal mode, use a non-clobbering move and verify the temporary was
   consumed. This catches a destination created during processing.
7. In force mode, replace the destination only after processing succeeds.
8. Remove temporary output on failure.

Never pre-delete the destination. For FFmpeg work, call
`_kit_media_run_ffmpeg` instead of duplicating this sequence.

## Completion pattern

```zsh
if [[ "$previous_word" == "-o" || "$previous_word" == "--output" ]]; then
    _files
    return 0
fi
if [[ "$current_word" == -* ]]; then
    _values 'options' '-o' '--output' '-f' '--force'
    return 0
fi
```

Handle consuming options before positional completion. Add regression checks to
`tests/test-discovery-output.zsh`.

## Dependency helpers

| Helper | Use |
|--------|-----|
| `_kit_require <command>` | Standard public dependency error path |
| `_kit_require_imagemagick` | ImageMagick v7 requirement |
| `_kit_detect_os` | `macos`, `linux`, or `unknown` |
| `_kit_detect_package_manager` | Supported package-manager identifier |
| `_kit_get_package_install_cmd <package>` | Platform-specific install command |

Do not duplicate these helpers in a new module unless the existing behavior is
being intentionally refactored.

## Verification matrix

| Changed area | Required focused check |
|--------------|------------------------|
| Core parsers or module headers | `zsh tests/test-kit-core.zsh` |
| Loader wrappers or config lifecycle | `zsh tests/test-loader-config.zsh` |
| Help, search, categories, completions | `zsh tests/test-discovery-output.zsh` |
| Media codecs, streams, outputs, downloader args | `zsh tests/test-media.zsh` |
| Function module structure | `zsh scripts/validate-pattern.sh functions/<category>.sh` |
| Zsh sources | `zsh -n loader.zsh lib/kit-core.zsh functions/*.sh completions/_kit tests/*.zsh` |
| Bash scripts | `bash -n scripts/new-function.sh scripts/generate-completions.sh tests/run-tests.sh` |
| Formatting | `git diff --check` |

The full integration command is `zsh tests/run-tests.sh`. Use it when generated
asset and live dispatcher coverage is needed.

## Common failures

| Symptom | Cause and fix |
|---------|---------------|
| Generator looks outside the repository | It was run with Zsh. Use `bash scripts/new-function.sh ...`. |
| Pattern validator reports permission denied | Prefix the non-executable file with `zsh`. |
| Integration runner fails while sourcing | It followed the Bash shebang. Use `zsh tests/run-tests.sh`. |
| Output loses its container/format | Temporary filename no longer ends with the final extension. Preserve it. |
| Existing output disappears after failed force | Destination was deleted too early. Process to a temporary sibling first. |
| Subtitle stream disappears | FFmpeg mapping selected only video/audio. Map all streams, then exclude only the unwanted stream type. |
| Odd width fails in libx264 | Normalize scaled dimensions to even values. |
| `--output <TAB>` offers unrelated values | Completion handled position before the consuming option. Check the previous word first. |
