# Kit's Toolkit test suite

The repository has four hermetic focused suites and one interactive integration runner.

> **Run the integration suite with Zsh from the repository root.** Do not use
> `./tests/run-tests.sh`: its Bash shebang cannot load the Zsh-only toolkit.
> The integration runner deletes and recreates `tests/assets`, may access
> YouTube, and prompts before final cleanup.

## Run the tests

Use the focused suites for fast, repeatable checks:

```zsh
for test in tests/test-{kit-core,loader-config,discovery-output,media}.zsh; do
  zsh "$test" || break
done
```

Run the full integration suite when external tools and interactive prompts are
appropriate:

```zsh
zsh tests/run-tests.sh          # Run all integration entries
zsh tests/run-tests.sh -v       # Re-run failures with detailed output
zsh tests/run-tests.sh -h       # Show runner help
```

## Choose the right suite

| Suite | Assertions or entries | What it covers | External requirements |
|-------|----------------------:|----------------|-----------------------|
| `test-kit-core.zsh` | 43 assertions | Config parsing, identifiers, module headers | None |
| `test-loader-config.zsh` | 89 assertions | Shortcut/editor dispatch, conflicts, re-source behavior | None |
| `test-discovery-output.zsh` | 43 assertions | Help, search, categories, and completion positions | None |
| `test-media.zsh` | 55 assertions | FFmpeg output safety, codecs, streams, sizing, and fake `yt-dlp` arguments | `ffmpeg`, `ffprobe` |
| `run-tests.sh` | Up to 51 entries | Cross-category integration plus all four focused suites | Toolkit dependencies; network for live YouTube coverage |

The integration total is conditional. Functional entries run only when their
assets and dependencies are available, and the live YouTube entry can be
skipped when `yt-dlp`, the network, or the test video is unavailable.

## Understand the integration run

The runner performs these steps:

1. Sources `loader.zsh` and runs `kit deps-check`.
2. Prompts before continuing when dependencies are missing.
3. Deletes and recreates `tests/assets`.
4. Generates image, video, audio, and PDF fixture directories.
5. Runs help, functional, dispatcher, focused, and file-listing checks.
6. Downloads a short YouTube video when possible, then compresses it, extracts
   MP3 audio, and removes its audio streams.
7. Prints totals and generated files, then asks whether to delete the assets.

### Generated assets

| Directory | Typical fixtures |
|-----------|------------------|
| `tests/assets/images/` | JPEG/WebP inputs, including spaces and special characters |
| `tests/assets/video/` | Five-second 640x360 video with AAC audio; optional YouTube outputs |
| `tests/assets/audio/` | Audio workspace |
| `tests/assets/pdf/` | Two-page PDF and split, merged, compressed, rotated, and burst outputs |

The live network test uses `https://youtu.be/1SBxsv_T_Jw`. A failed or missing
download is reported as skipped rather than failed.

## Read the output

Each integration entry is reported as `[PASS]`, `[FAIL]`, or `[SKIP]`. A
successful fully provisioned run currently ends with:

```text
All tests passed!
Total:   51
Passed:  51
Failed:  0
Skipped: 0
```

Counts can be lower when dependency-gated functional entries are not created,
or include skips when the live download is unavailable. With `--verbose`, a
failed entry is repeated without output suppression.

## Run a manual fixture check

Generate the fixtures with the integration runner and choose `N` at the cleanup
prompt. Then run commands from the repository root or the relevant asset
directory:

```zsh
cd tests/assets/images
kit img-resize-width 400 test_input_800x600.jpg
test -f test_input_800x600-resized.jpg
```

The next integration run removes any retained `tests/assets` directory before
creating fresh fixtures.

## Add coverage

Add focused assertions for contracts that can be tested hermetically. Add an
integration entry when the behavior needs generated assets or the public
`kit <command>` dispatch path.

```zsh
# Help entry in tests/run-tests.sh
run_test "my-function: help works" "kit my-function -h"

# Functional entry inside the appropriate asset-directory guard
run_test "my-function: functional test" \
  "kit my-function test_input.txt && [[ -f 'expected_output.txt' ]]"
```

Cover invalid values, filenames with spaces or leading dots, existing outputs,
failed force operations, input/output identity, and completion positions when
those contracts apply.

## Troubleshoot failures

| Symptom | Action |
|---------|--------|
| Toolkit fails while loading | Confirm the command starts with `zsh tests/run-tests.sh`, not `./tests/run-tests.sh` or `bash tests/run-tests.sh`. |
| Dependencies are missing | Run `kit deps-check`, then `kit deps-install` if you want the full integration coverage. |
| YouTube entry skips | Check `command -v yt-dlp` and network access; the focused media suite tests downloader arguments without the network. |
| Personal shortcuts/editors fail validation | Run `zsh tests/test-loader-config.zsh`; personal config paths are outside the hermetic repository gate. |
| Retained assets are in the way | Inspect anything needed, then run the integration suite, which recreates the directory itself. |

## Test files

```text
tests/
├── run-tests.sh               # Interactive integration runner
├── test-kit-core.zsh          # Core helper assertions
├── test-loader-config.zsh     # Shortcut/editor lifecycle assertions
├── test-discovery-output.zsh  # Help and completion assertions
├── test-media.zsh             # Media contract assertions
├── README.md                  # This guide
└── assets/                    # Generated and ignored
```
