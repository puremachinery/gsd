# Smoke Testing

## Current Automated Smoke

GSD now has a deterministic bootstrap smoke contract that runs in local developer checks and PR CI on Linux and macOS.

Run it locally:

```bash
cd installer
nimble smoke
```

Or run the full gated check:

```bash
cd installer
nimble verify
```

The smoke script lives at `scripts/smoke/bootstrap-contract.sh` and does this in a fresh temp `HOME` and temp project directory:

1. Builds or uses the current `gsd` binary.
2. Installs GSD locally for both Claude Code and Codex CLI.
3. Verifies the managed runtime exists at `.gsd/runtime/bin/gsd`.
4. Verifies Claude and Codex command/prompt files were installed.
5. Verifies local installs rewrite `@~/.gsd/...` references to `@.gsd/...`.
6. Verifies installed hook/statusline commands point at the managed runtime binary.
7. Verifies `.gsd/gsd-config.json` records the expected local install metadata.
8. Exercises the deterministic setup contract from `gsd:new-project` by:
   - initializing git in the temp project
   - checking that brownfield detection reports an empty project
9. Runs the managed binary for:
   - `doctor --platform=claude`
   - `doctor --platform=codex`
   - `update --platform=both --dry-run`
   - `statusline --config-dir ...`
10. Verifies the statusline renders project/task/context information from the temp project.

This is intentionally a contract smoke, not a model-behavior test. It proves that a fresh install produces the artifacts and deterministic runtime behavior that an assistant needs before `/gsd:new-project` can succeed.

## Why PR CI Stops Here

A true end-to-end `/gsd:new-project` smoke depends on an external assistant runtime that can:

1. run headlessly
2. authenticate non-interactively
3. accept scripted answers deterministically
4. stay stable enough to gate every PR

That is not a reasonable required check yet. Putting a live LLM in required CI would turn unrelated PRs red because of auth drift, provider outages, or prompt nondeterminism.

## Recommended Next Layer

The next layer should be a separate manual `workflow_dispatch` workflow, not a required PR check.

Recommended shape:

1. Create a fresh temp repo.
2. Install GSD from the release bundle being tested.
3. Start the target assistant in headless mode.
4. Invoke `/gsd:new-project` with a fixed prompt and fixed answers.
5. Assert the expected outputs exist:
   - `.planning/PROJECT.md`
   - `.planning/config.json`
   - `.planning/REQUIREMENTS.md`
   - `.planning/ROADMAP.md`
   - `.planning/STATE.md`
   - `.git/`
6. Assert the generated docs mention the seeded project goal and that requirement/roadmap artifacts are non-empty.
7. Store the generated project as a workflow artifact for inspection on failure.

That would give us real agent-driven coverage without making routine PRs depend on external model behavior.
