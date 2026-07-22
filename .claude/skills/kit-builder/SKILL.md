---
name: kit-builder
description: Add or modify Kit Toolbox shell functions, categories, completions, and tests. Use for new Kit commands, changes to existing public functions, function migrations, or requests that mention kit_pattern.md. Keep Zsh behavior, output safety, discovery metadata, and focused tests in sync.
---

# Kit Builder

Extend Kit by matching the live repository, then verify the public `kit`
interface. Treat [`llm_prompts/kit_pattern.md`](../../../llm_prompts/kit_pattern.md)
as the canonical structural and safety guide.

## Read before editing

Inspect these files in order:

1. The closest existing function in `functions/*.sh`.
2. `llm_prompts/kit_pattern.md` for interface and output contracts.
3. `lib/kit-core.zsh` when config parsing or module metadata is involved.
4. `completions/_kit` when the command accepts options or positional values.
5. The focused suite that owns the behavior under `tests/test-*.zsh`.

Use `examples.md` for worked scenarios and `reference.md` for command and
pattern lookup.

## Plan the command

Confirm the required inputs, outputs, dependencies, destructive behavior, and
success/failure conditions. Ask only when a missing choice would materially
change the interface; otherwise follow the closest existing command.

Choose the category that owns the behavior:

| Category file | Scope | Typical public names |
|---------------|-------|----------------------|
| `images.sh` | Image conversion, resizing, optimization | `img-*` |
| `media.sh` | Video/audio conversion and downloads | `compress-video`, `convert-to-mp3` |
| `pdf.sh` | PDF transformation | `pdf-*` |
| `system.sh` | Shell and filesystem utilities | Action-oriented names |
| `aliases.sh` | Navigation helper | `goto` and config-backed shortcuts |
| `lsd.sh` | Enhanced listing | `list-*` |
| `deps.sh` | Dependency checks and installation | `deps-*` |

Create a new category only when the behavior does not fit an existing one.
Register it in `categories.conf` and include the four required module headers:
`Category`, `Description`, `Dependencies`, and `Functions`.

Use lowercase hyphenated public names. Match the category’s existing family,
such as `img-resize`, rather than forcing a universal verb-first convention.

## Generate or edit

For an existing category, generate a skeleton from the repository root:

```bash
bash scripts/new-function.sh <category> <function-name> "<description>"
```

The generator is a Bash script and is not executable in Git. Do not invoke it
with Zsh: its `BASH_SOURCE` path detection resolves the wrong directory.

The skeleton is only a starting point. Replace placeholders and remove dead
validation. If a manual edit is clearer, add the function directly and update
the category’s `# Functions:` header.

## Preserve the public contracts

### Help and exit codes

- Support `-h` and `--help` with usage, a short description, and real examples.
- Return `2` for invalid syntax or values.
- Return `1` for runtime failures, missing files, and missing dependencies.
- Return `0` only after the requested operation succeeds.
- No-argument help may return `0` only when that behavior is documented.
- Send errors to stderr.

### Arguments and command execution

- Check that value-consuming options have a following value before `shift 2`.
- Reject unknown options and unexpected extra positional arguments.
- Validate numbers and enums before arithmetic or command execution.
- Quote path expansions and use arrays for complex argv construction.
- Never `eval` user input.
- Accept safely quoted filenames with spaces, leading dots, and shell
  characters. Validate meaning, not characters that are harmless in argv.
- Use `_kit_require` or the existing dependency helper for public commands.

### File outputs

- Reject input/output identity after normalizing paths.
- Refuse an existing output unless `--force` is explicit.
- Do not delete an existing output before processing.
- Write to a sibling temporary path whose final suffix preserves the intended
  extension or container.
- Verify the temporary output, then install it. Use a non-clobbering move for
  normal mode and confirm that the temporary file was consumed so a concurrent
  writer cannot be overwritten. Use forced replacement only after success.
- Remove temporary output on every failure path. A failed forced operation must
  leave the original destination intact.
- Reuse the helpers in `functions/media.sh` for FFmpeg commands.

### Media behavior

- Map streams explicitly when stream preservation matters. Removing audio must
  keep subtitles, metadata, chapters, attachments, and other non-audio streams
  supported by the output container.
- Keep H.264 dimensions even. A maximum width must not upscale smaller input,
  and odd limits must normalize to an encoder-safe even result.
- Use `-1` only when the command documents scaling as disabled.

### Loader and config behavior

- Parse shortcut/editor entries through `lib/kit-core.zsh`; descriptions may
  contain `|`.
- Do not add `eval` or shell expansion to editor commands.
- Generated wrappers use source-time registries, refresh on re-source, remove
  deleted entries, and never replace existing user functions.

## Update completion

Functions listed in a category header are discovered automatically. Edit
`_kit_get_custom_completion` only for command-specific arguments or options.

Handle options that consume values before positional completion. For example,
`--output <TAB>` must offer files or output templates, not media qualities.
When the current token starts with `-`, offer options.

Verify the dynamic completion system with:

```bash
./scripts/generate-completions.sh
```

This Bash script is executable. Do not invoke it with Zsh because it uses
`BASH_SOURCE` for repository discovery.

## Add tests

Put deterministic contracts in the focused suite that owns the behavior:

| Change | Focused command |
|--------|-----------------|
| Config parsing or module headers | `zsh tests/test-kit-core.zsh` |
| Loader wrappers or re-source behavior | `zsh tests/test-loader-config.zsh` |
| Help, discovery, or completion | `zsh tests/test-discovery-output.zsh` |
| FFmpeg or `yt-dlp` arguments | `zsh tests/test-media.zsh` |

Add an entry to `tests/run-tests.sh` when the behavior needs generated assets
or the public dispatcher. Cover help, success, invalid usage, and the relevant
edge cases. File-producing commands need tests for spaces/leading dots,
existing output, failed force, input/output identity, and concurrent creation.

Run the focused suites:

```zsh
for test in tests/test-{kit-core,loader-config,discovery-output,media}.zsh; do
  zsh "$test" || break
done
```

Run the interactive integration suite only when its external effects are
appropriate:

```zsh
zsh tests/run-tests.sh
```

Never use `./tests/run-tests.sh` or Bash. The runner sources Zsh-only code,
deletes and recreates `tests/assets`, may perform a live YouTube download, and
prompts before cleanup.

## Validate the change

Run the smallest relevant checks first, then the complete set justified by the
change:

```zsh
zsh scripts/validate-pattern.sh functions/<category>.sh
zsh -n loader.zsh lib/kit-core.zsh functions/*.sh completions/_kit tests/*.zsh
bash -n scripts/new-function.sh scripts/generate-completions.sh tests/run-tests.sh
./scripts/generate-completions.sh
git diff --check
```

`validate-pattern.sh` is a non-executable Zsh script, so always prefix it with
`zsh`.

## Update documentation

Update the function help and category header for every public change. Update
`README.md`, `tests/README.md`, and completion examples when behavior or usage
changes. Change `VERSION` and the changelog only when the task includes release
preparation; do not bump them for an ordinary implementation edit.

Before finishing, inspect `git diff` and `git status`. Preserve unrelated user
changes and do not edit or commit Trekoon database, WAL, SHM, or migration state.
