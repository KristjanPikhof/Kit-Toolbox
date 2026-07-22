# Kit Builder skill

Kit Builder guides changes to Kit’s public shell functions, category metadata,
completion behavior, documentation, and tests.

## Start here

Read [SKILL.md](SKILL.md) for the workflow. It routes to:

| File | Use it for |
|------|------------|
| [examples.md](examples.md) | Worked function, media-output, and completion scenarios |
| [reference.md](reference.md) | Commands, exit codes, safety rules, and verification matrix |
| [`llm_prompts/kit_pattern.md`](../../../llm_prompts/kit_pattern.md) | Canonical repository pattern |
| [`tests/README.md`](../../../tests/README.md) | Focused and integration test behavior |

## Typical workflow

```bash
# Generate inside an existing category. This script requires Bash.
bash scripts/new-function.sh images img-example "Process an image"
```

Implement the command, update its category header and custom completion if
needed, then validate with the script’s actual shell:

```zsh
zsh scripts/validate-pattern.sh functions/images.sh

for test in tests/test-{kit-core,loader-config,discovery-output,media}.zsh; do
  zsh "$test" || break
done
```

The full runner is interactive and can access the network:

```zsh
zsh tests/run-tests.sh
```

Do not execute `tests/run-tests.sh` directly. Its Bash shebang cannot load the
Zsh-only toolkit. The runner also recreates `tests/assets` and prompts before
cleanup.

## Core expectations

| Area | Contract |
|------|----------|
| Interface | Lowercase hyphenated name, clear help, exit codes 0/1/2 |
| Execution | Quoted paths, argv arrays, no `eval` of user input |
| Outputs | Temporary sibling, no pre-delete, race-safe install, failed force preserves original |
| Discovery | Function listed in `# Functions:`; custom argument completion when needed |
| Tests | Focused regression coverage plus integration entry when generated assets are required |
| Docs | Help, README, test guide, and examples match actual behavior |

Kit itself requires Zsh. The generator and completion verifier are Bash scripts;
the pattern validator and toolkit tests must run with Zsh as documented above.
