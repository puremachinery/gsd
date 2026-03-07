# Smoke Testing

## Contract Smoke

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

The smoke script lives at `scripts/smoke/bootstrap-contract.sh`. `nimble smoke` builds `installer/gsd` first, then runs the script against that binary in a fresh temp `HOME` and temp project directory:

1. Uses the provided `gsd` binary.
2. Installs GSD locally for both Claude Code and Codex CLI.
3. Verifies the managed runtime exists at `.gsd/runtime/bin/gsd`.
4. Verifies Claude and Codex command/prompt files were installed.
5. Verifies the prompt-referenced bundled files actually exist:
   - `.gsd/references/questioning.md`
   - `.gsd/references/ui-brand.md`
   - `.gsd/templates/project.md`
   - `.gsd/templates/requirements.md`
6. Verifies local installs rewrite `@~/.gsd/...` references to `@.gsd/...`.
7. Verifies installed hook/statusline commands point at the managed runtime binary.
8. Verifies `.gsd/gsd-config.json` records the expected local install metadata.
9. Exercises the deterministic setup contract from `gsd:new-project` by:
   - initializing git in the temp project
   - checking that brownfield detection reports an empty project
10. Runs the managed binary for:
   - `doctor --platform=claude`
   - `doctor --platform=codex`
   - `update --platform=both --dry-run`
   - `statusline --config-dir ...`
11. Verifies the statusline renders project/task/context information from the temp project.

This is intentionally a contract smoke, not a model-behavior test. It proves that a fresh install produces the artifacts and deterministic runtime behavior that an assistant needs before `/gsd:new-project` can succeed.

## Live Smoke

GSD also has a real model-driven smoke for `gsd:new-project` using headless Codex execution.

Run it locally after authenticating Codex:

```bash
cd installer
nimble build -y
cd ..
./scripts/smoke/live-new-project.sh installer/gsd
```

For local debugging, preserve artifacts with `GSD_SMOKE_PRESERVE_TMP=1` for the contract smoke or `GSD_LIVE_SMOKE_PRESERVE=1` for the live smoke.

Or run the manual GitHub Actions workflow:

- workflow: `Live Smoke`
- trigger: `workflow_dispatch`
- secret required: `OPENAI_API_KEY`

The live smoke script at `scripts/smoke/live-new-project.sh` does this:

1. Creates a fresh temp project.
2. Installs GSD locally for Codex.
3. Runs headless `codex exec` against the installed `.codex/prompts/gsd-new-project.md`.
4. Supplies a fixed project brief for a tiny `todo-smoke` Python CLI.
5. Forces the run to stop once the initialization workflow is complete.
6. Verifies the real workflow outputs exist:
   - `.planning/PROJECT.md`
   - `.planning/config.json`
   - `.planning/REQUIREMENTS.md`
   - `.planning/ROADMAP.md`
   - `.planning/STATE.md`
   - `.git/`
7. Verifies the planning docs mention the seeded project brief and requirement IDs.
8. Verifies the workflow made at least one git commit.
9. Fails if the model drifts into implementation or optional research.

This is the test that actually smokes the `new-project` workflow end to end.

## Why PR CI Still Stops At The Contract Layer

A true end-to-end `/gsd:new-project` smoke still depends on an external assistant runtime that can:

1. run headlessly
2. authenticate non-interactively
3. accept scripted answers deterministically
4. stay stable enough to gate every PR

That is not a reasonable required check yet. Putting a live LLM in required CI would turn unrelated PRs red because of auth drift, provider outages, or prompt nondeterminism.

## Provider Coverage

Current live coverage is Codex because it has a reliable headless execution path for automation. Claude can be added later as a second manual smoke once its non-interactive flow is scripted with the same level of determinism.
