# Tutorial Verification & Refresh Playbook

This playbook documents the process used to verify and refresh a CloudBank Showcase tutorial end-to-end on its live cloud console, and to refresh the documentation so a beginner can still follow it today. It was written after the GPU Computing in Oceanography verification (issue #13) and is meant to be reused for the remaining tutorials.

## 1. Purpose and scope

**Goal.** For a given showcase tutorial: walk every guide literally on the real cloud console (fresh resources, no shortcuts), record what actually happens, fix any drift in the docs (commands, version pins, expected output), and finish with a live run that has no critical and no major findings.

**Trigger.** A GitHub issue titled "Verify & refresh: <tutorial>" is open in `cloudbank-project/cloudbank_showcase`. Examples: #13 GPU Computing in Oceanography (done; this playbook captures that process), #14 Knowledge Graphs for Chemistry, #15 Toy Data Portal for Hydrology.

**In scope.**

- guides, notebooks and project files in the tutorial folder (the single source of truth for content),
- repo README metadata (the `Last Verified` date, resource names in the tutorial table),
- `website/scripts/sync.mjs` when a guide is added, removed or renamed (the docs site is generated from the tutorial sources; `website/docs/tutorials/` is git-ignored and never hand-edited),
- the fix branch, the PR and the issue-comment workflow.

**Out of scope.**

- new features or new cloud resources beyond what the tutorial already uses,
- changes to the operator's cloud account, credentials or billing setup,
- anything that costs beyond the CloudBank award, and any long-running compute.

**Definition of done.** A live walkthrough with zero critical and zero major findings, a passing docs site build (`npm run sync && npm run build`), the branch pushed, and a PR that closes the issue.

**Where the process lives.** This playbook (`verification/README.md`), the repo `AGENTS.md`, and a per-tutorial state directory kept by the operator outside the public repo (private round reports and evidence).

## 2. Roles and the verify loop

Three roles take part in every verification:

- **Orchestrator.** The main agent session. It plans rounds, assigns work, reviews severity, decides to continue or stop, talks to the human when needed, and never edits the tutorial docs itself.
- **Improver agent.** A coding agent that works in the repo checkout: reads `AGENTS.md` and the tutorial guides, applies fixes on the branch, commits and pushes, and writes its round JSON. It never touches cloud resources and never runs anything in the cloud console.
- **Executor agent.** A browser-driven agent that follows the browser-automation skill to walk each guide literally in the live console the way a new user would, records evidence, cleans up, and never edits tutorial docs.

**The loop (improver and executor alternate):**

1. Baseline polish: the improver does a static review and a first round of fixes on branch `verify/<slug>` (created from `origin/main`), including a cross-guide consistency check.
2. Live walkthrough #1: the executor runs all guides end-to-end and returns the round JSON with per-guide status and severity.
3. Fix round: the improver addresses every critical and major finding (research-first for version drift), commits and pushes.
4. Live rerun: the executor repeats the walkthrough from a clean slate. Repeat steps 3 and 4 until a run is clean.
5. Final polish: expected-output blocks refreshed byte-exact, repo README `Last Verified` updated, docs site build verified, final commit and push.
6. Wrap-up: PR, issue comment, merge after human approval (see section 7).

**Stop rules.**

- Stop as soon as a live run has no critical and no major findings (a clean run), even if minor findings remain; collect them into the same round or a follow-up if cheap.
- Hard cap: 4 live walkthroughs per tutorial. After the cap, report the current status honestly and escalate to the human; do not burn more runs silently.
- If the same critical finding re-appears in two consecutive rounds (the fix did not take effect), mark the tutorial as blocked and report the concrete condition instead of continuing.
- The executor may mark a guide `partial` when the mechanism is verified but a specific UI step cannot be driven by automation (for example a desktop GUI client). That is a tooling note, not a doc finding, and it does not block the loop.

**Severity classification (applied to doc findings, not to agent tooling limits):**

- `critical`: the step fails as documented, so the user cannot complete the tutorial,
- `major`: the step works but misleads or would fail on a fresh account (missing prerequisite, wrong ordering, stale version pin, wrong value),
- `minor`: copy, formatting or polish that does not affect functionality.

## 3. Pre-flight

**Repo and branch.**

- Clone the public repo; create the branch from `origin/main` (never from an old stale state): `verify/<tutorial-slug>` for tutorial fixes, `docs/<topic>` for process or docs work such as this playbook.
- Read the repo `AGENTS.md` first; it holds the repo-specific conventions (beginner-friendly docs, docs site generation, browser patterns) and the external-dependency checklist for the cloud provider in use.

**Browser automation.**

- Use a dedicated, fresh automation browser profile (no saved logins) with a browser-automation CLI (for example browser-use over CDP) that drives the local Chrome over a fixed debug port; headless mode by default so nothing pops up.
- Check the CDP endpoint before starting (request the `json/version` endpoint); the start script must be idempotent.
- The profile is shared across rounds so the login session persists; using the same profile also protects against silently landing in a different account.

**One-time interactive logins (human gates).**

- The first access to the research cloud gateway account (CloudBank) goes through a federated login chain (institution identity provider, plus multi-factor). It cannot be automated.
- Protocol: the executor pauses; the human completes the login in the visible browser window (GUI mode for the first login only, headless afterwards); credentials come from a secrets manager CLI and are passed through environment variables, never pasted into the transcript; the agent never types credentials and never clicks consent or "Authorize" buttons.
- After the first login, continue headless with the same profile; cookies carry the session.

**Project golden check (mandatory, before creating anything).**

- Confirm the active cloud project is the CloudBank-provided project assigned to the tutorial (the billing-account access page row maps to a specific project id and project number in the console).
- Never create resources in a personal project. If the active project is not the tutorial project, abort with `needs_human` and create nothing.
- Never trust local CLI credentials: the operator's local machine may be authenticated as a different personal account pointing at a personal project. Do all CLI work inside the cloud provider's browser terminal (Cloud Shell) in the tutorial project, and verify the active account and project there each round (`auth list` and `config` style commands).

**State directory.**

- Create one state directory per tutorial outside the public repo (for example under the operator's notes, `notes/cloudbank-<slug>-verify/`); it holds the per-round JSON reports and the evidence files (screenshots, logs, executed notebooks).
- Never commit the state directory or its evidence to the public repo; evidence can contain resource identifiers and console details that should stay private.

**Session hygiene.**

- Create a long-lived goal so the session keeps working across rounds; keep only live subagents in the list and interrupt every agent as soon as it settles.

## 4. Live walkthrough protocol

**Execution rules for the executor.**

- Follow the guides literally, in order, the way a beginner would: no hidden steps, no skipped cells, no invented values. If automation forces a deviation (for example a guided wizard cannot be driven by an agent and the equivalent CLI command is used instead), record the deviation explicitly as an executor-only note; it is not a doc finding.
- Fresh start each round: resources created by the previous round must be gone before the walkthrough begins, so the run reproduces a brand-new user.

**Pre-existing resources.**

- Before creating anything, inventory the current state: instances, firewall rules, disks, buckets, images. Record the list (with identifiers) in the round JSON, in the `resources` field.
- Never delete or modify a pre-existing resource. Some tutorials assume a firewall rule does not exist; if it already exists (from an earlier run or another workload), apply the guide's skip-if-exists note, move on, and say so in the report.

**Evidence to collect (per step).**

- console screenshots at each meaningful state (login, dashboard, list, creation dialog, deletion dialog, empty list after cleanup),
- terminal outputs with exit codes, and logs (including the notebook-converter runs: exit code and elapsed time),
- resource identifiers (instance name, zone, project id, firewall rule names),
- the executed notebook saved to the state dir (the strongest evidence that the tutorial runs end-to-end),
- version truth: driver (`nvidia-smi`), package status after the install step, language runtime version.

**Cleanup (mandatory, in the same round, with proof).**

- Delete only the resources this run created: instance, boot disk, firewall rule(s); the ephemeral external IP is released with the instance.
- Prove deletion: a console or CLI listing showing zero instances and only the pre-existing resources remaining (screenshot or captured output).
- Never leave anything running, never leave a billable resource behind, never rely on "it will be deleted later".
- Do not touch credentials, consent dialogs, "Authorize" buttons or destructive confirmations; if one appears, record it, leave it unclicked, and hand off to the human.

**Per-guide verdicts.**

- `pass`: every step completed as documented, evidence captured, no doc defect,
- `partial`: the underlying mechanism is verified end-to-end but an accessory step (usually a desktop GUI client) cannot be driven by browser automation; mark severity `none` unless a real doc defect was also found,
- `fail`: a step cannot be completed as documented; attach the exact error and the doc finding (severity critical or major).

**Costs and safety.**

- No compute beyond what the guide instructs, no job submissions of any kind; costs stay on the CloudBank award.
- The agent never uses guessed credentials, never retries a login, and never clicks a destructive button as an experiment.

## 5. Report schema

Each round produces one JSON file in the private state directory, named `round_<N>_<model>_<phase>.json` (for example `round_1_<model>.json`).

```json
{
  "round": 1,
  "model": "<agent model id>",
  "phase": "baseline_polish|live_walkthrough|fix|final|docs_site_sync",
  "started_at": "2026-10-20T14:51:31Z",
  "commits": ["<short sha>: <message>"],
  "results": [
    {
      "guide": "1_create_gpu_instance.md",
      "status": "pass|fail|partial",
      "severity": "critical|major|minor|none",
      "detail": "what happened and how it differs from the docs",
      "evidence": "evidence/file.png; evidence/log.txt"
    }
  ],
  "resources": {
    "instance": "<name> (created by this run)",
    "firewall": "<rule names, pre-existing untouched>",
    "project_id": "<tutorial cloud project>",
    "note": "pre-existing resources listed before creation"
  },
  "actual_versions": {
    "pkg_or_tool": "<exact version observed>"
  },
  "cleaned_up": true,
  "needs_human": {"reason": "...", "url": "..."},
  "change_log": ["<file> <what changed>"],
  "summary": "..."
}
```

Field discipline:

- `results`: one entry per guide, always, even for pure passes; `severity` describes how bad the doc defect is for the user, not for the agent.
- `needs_human`: `null` when the human is not needed; otherwise a concrete reason and a URL. The orchestrator asks the user and resumes the same executor subagent (browser state persists).
- `cleaned_up`: must be `true` for a completed walkthrough round; `false` with a reason only if the human explicitly asked to keep a resource.
- `actual_versions`: exact resolved versions from the live environment, used later to refresh the expected-output blocks.

Verdict rules on a report:

- Clean: every guide `pass` or `partial` with severity `none` (partial alone is fine, it is a tooling note).
- Not clean: at least one finding with severity `critical` or `major`; the improver must fix all of them before the next live run.
- Minor findings do not block the loop but should be collected and fixed in the same fix round or in the final polish.

## 6. Fix round protocol

**Order of work.**

1. Read the last executor report; list every critical and major finding and map each to a specific fix in a specific file.
2. Fix the docs (guide text, commands, ordering, pins, expected values). Never patch cloud resources to make the docs "work".
3. Research first for any version drift (see below). Never pick a version by "latest looks fine".
4. Re-check cross-guide consistency after editing: instance name, zone, ports, firewall rule names, package pins, sequence references ("completed tutorial N") and guide numbering are all referenced from multiple files.
5. Register any new or renamed guide in `website/scripts/sync.mjs` (the `files` list with title and sidebar position; keep the explicit integer positions monotonic). Without that entry the guide never appears on the published docs site.
6. Verify the docs site: `cd website && npm run sync && npm run build` must succeed (generated files under `website/docs` are git-ignored). Do this before every push that touched a guide or notebook.
7. Commit with a message that references the issue, push the branch.

**Research-first approach to version drift (the pattern that matters).**

- A tutorial that lets libraries resolve "latest" drifts: a new release silently changes behavior and the notebook breaks on a fresh install while the operator's cached environment still works.
- Do not blindly bump to the newest version; find the last compatible release:
  - read the package registry commit history (the registry `Versions.toml` plus the commit that registered each version, and the GitHub compare API for a release range),
  - identify the upstream PR or commit that introduced the breaking behavior and the first release that contains it,
  - take the newest release strictly before that commit,
  - cross-check compat constraints from the registry (what the other packages in the set allow, for example a CUDA package capping a compiler version, or a downstream package requiring a minimum of another) so the pin resolves a consistent set without silently downgrading something needed.
- Pin explicitly in the guide's install step and document why next to the project file, with a short note that the version is pinned on purpose.
- After pinning, confirm the resolution with a live run: `actual_versions` must show the pinned version exactly.

**Expected-output blocks.**

- Refresh every expected-output block to the byte-exact observed values captured from the evidence files (`nvidia-smi`, package status, version-info output, device memory lines). Do not transcribe from memory; copy from the captured text files.
- Keep a one-line caveat in the guide that exact patch versions may differ slightly on a fresh install, while pinned versions should resolve as documented.
- If versions changed, refresh the executed notebook outputs too; the executed notebook is published on the docs site and is what users download and re-run.

**What the improver never does.**

- Never touches cloud resources, credentials or the live console.
- Never edits `website/docs/tutorials/` or `website/build/` by hand (generated, git-ignored).
- Never changes notebook code cells unless a real code bug is found; prefer a version pin over a code patch when the failure is drift.

## 7. Wrap-up

- Push the branch (automatic during the loop; never leave unpushed work behind).
- Open a pull request with a focused title and body that references the issue (`Closes #<issue>`), following the repo convention, and present it for explicit human approval before merging (squash merge is the usual mode in this repo).
- After the merge (or on the branch before it, per the human's choice), comment on the issue with per-guide results and the versions verified, and tick the issue checkboxes one by one as each guide is confirmed.
- Update the repo README `Last Verified` row in the final fix round (format `Month YYYY`); that row is the public signal that a tutorial is maintained.
- Time tracking: record the duration spent and the project it is charged to, per the operator's standing convention (propose a duration and a project, have the human confirm).
- Subagent hygiene: interrupt and clean up every finished subagent as soon as it settles; keep the agent list limited to live workers.
- Deliverables: the merged PR, the issue comment with ticked checkboxes, and the private round JSONs in the state dir for the record.

## 8. Lessons learned from issue #13 (GPU Computing in Oceanography)

Each pitfall below was hit during the live verification; the fix that landed is listed next to it.

| # | Pitfall observed | Fix adopted |
|---|---|---|
| 1 | The metadata-based auto-install of NVIDIA drivers does not work on the documented image (no driver packages, no `nvidia-smi` after creation). | Document an explicit apt install of the NVIDIA driver package, a reboot, then verify `nvidia-smi` as its own step; note that the exact driver version is not critical because the language GPU package ships its own CUDA runtime. |
| 2 | Installing the notebook converter package does NOT provide the notebook server; the documented launch command dies instantly and the port never opens. | Install the notebook server package too (the converter package alone is not enough), and verify the port is listening before pointing the browser at it. |
| 3 | Kernel registration was ordered before the Julia kernel-backend package was added, so the registration failed on a fresh install. | Registration must come after `Pkg.add` of the kernel backend, as the last step of the environment build. |
| 4 | `gcloud --image=<family>` fails on the current SDK ("referenced image resource cannot be found") even though the family exists. | Use `--image-family=<family> --image-project=<project>` (or a concrete image name), and add a note that the family flag is required on current SDKs. |
| 5 | The notebook's kernelspec metadata did not match the kernel a fresh install registers, so headless execution (`nbconvert --execute`) failed with NoSuchKernel even though the Jupyter UI fell back cleanly. | Fix the notebook metadata kernelspec (or pass the kernel name explicitly), and add a note that the metadata must match `jupyter kernelspec list`. |
| 6 | An unpinned GPU library drifted: the newest release introduced a strict check that rejected the tutorial's kernel arguments, and the notebook failed at the forward time-step on a fresh install (no figures, no error cell, only partial outputs). | Research the registry history, identify the breaking upstream change, pin to the last compatible release with documented evidence, cross-check the compat constraints of the rest of the dependency set, then confirm with a live run. |
| 7 | The provider's browser terminal is an ephemeral VM: it was recycled mid-run, a one-time "Authorize" consent dialog appeared, and the session authentication was lost. | Treat the consent dialog as a human gate (left unclicked by the agent), or finish the remaining steps via the console UI and direct SSH; record the event in the report. |
| 8 | The local CLI on the operator's machine was authenticated as a different, personal account pointing at a personal project. | Never use the local CLI for the tutorial; do CLI work in the browser terminal inside the tutorial project and verify the active account and project each round. |
| 9 | Firewall rules from earlier runs or other workloads already existed, so the create command would have failed on a fresh-looking project. | Record the pre-existing rules before creating anything, apply the skip-if-exists note, and never delete them. |

**Other process lessons.**

- The golden check (right project, never a personal one) must happen before the first resource is created, and the console's active project must be re-read at the start of every round; a one-time check is not enough.
- Cleanup is part of every round, not a final step: instance, disk and any rule created this round are deleted and proven gone (empty list) before the report closes.
- The executed notebook is the strongest end-to-end evidence; keep both the failed and the clean run in the state dir (the failed one explains the bug, the clean one proves the fix).
- Agent tooling limits (for example a desktop IDE window that cannot be driven) are reported as `partial` with the mechanism verified, not as doc defects; never raise a doc finding only because the agent could not click something.
- The executor should use the same kind of commands the docs show, not a richer operator environment; a "works for the operator" result is not a "works for the user" result.

## 9. Checklist for the next tutorial

Work through the open issues one at a time, oldest tutorial first (repo convention).

- [ ] Open issues identified: #14 Knowledge Graphs for Chemistry (AWS), #15 Toy Data Portal for Hydrology (Google Cloud); the seismology and GPU computing tutorials are already verified.
- [ ] Branch created from `origin/main` with a focused name (`verify/<slug>`).
- [ ] Repo `AGENTS.md` read; tutorial folder structure read (README + guides + notebooks).
- [ ] Browser automation up: dedicated profile, CDP endpoint answering, headless default.
- [ ] One-time interactive logins done with the human (gateway, identity provider, multi-factor), then headless with the same profile.
- [ ] Project golden check passed and recorded (CloudBank project, not a personal one); local CLI ignored.
- [ ] Pre-existing resources inventoried and recorded before anything is created.
- [ ] Baseline polish round done (static drift plus cross-guide consistency), pushed.
- [ ] Live walkthrough executed literally with evidence (screenshots, logs, executed notebook).
- [ ] Cleanup done and proven: no resources created by this run remain.
- [ ] Round JSON written to the private state dir.
- [ ] Fix round addressed every critical and major finding; version drift researched and pinned with evidence.
- [ ] Expected-output blocks refreshed byte-exact from captured evidence.
- [ ] New or renamed guides registered in `website/scripts/sync.mjs`.
- [ ] Docs site verified: `cd website && npm run sync && npm run build`.
- [ ] README `Last Verified` updated to the current month and year.
- [ ] Branch pushed; PR opened with `Closes #<issue>`; human approval before merge.
- [ ] Issue comment posted ticking the checkboxes with per-guide results.
- [ ] Time recorded (duration plus project) per the operator's convention.
- [ ] Subagents cleaned up.

**Conventions from repo AGENTS.md that apply every time.** The tutorial folders remain the single source of truth (the docs site is generated; never hand-edit `website/docs/tutorials/`); docs stay beginner-friendly (simple steps first, advanced material in a clearly marked appendix); run `npm run sync && npm run build` whenever a guide or notebook changes; make focused commits on a branch and open a PR that references the issue; verification work is tracked per tutorial in "Verify & refresh: <tutorial>" issues, and progress is logged as issue comments with checkboxes ticked as each guide is confirmed.
