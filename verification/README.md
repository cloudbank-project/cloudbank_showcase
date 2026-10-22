# Tutorial Verification & Refresh Playbook

This playbook documents the process used to verify and refresh a CloudBank Showcase tutorial end-to-end on its live cloud console, and to refresh the documentation so a beginner can still follow it today. It is meant to be reused for every tutorial, whatever the cloud provider, and it deliberately stays free of tutorial-specific and provider-specific detail: the concrete facts (login chain, exact commands, observed versions) are discovered live and recorded in the private state directory of each tutorial.

## 1. Purpose and scope

**Goal.** For a given showcase tutorial: walk every guide literally on the real cloud console (fresh resources, no shortcuts), record what actually happens, fix any drift in the docs (commands, version pins, expected output), and finish with a live run that has no critical and no major findings.

**Trigger.** A GitHub issue titled "Verify & refresh: <tutorial>" is open in the public showcase repo.

**In scope.**

- guides, notebooks and project files in the tutorial folder (the single source of truth for content),
- repo README metadata (the `Last Verified` date, resource names in the tutorial table),
- the docs-site generator configuration when a guide is added, removed or renamed (the docs site is generated from the tutorial sources; generated files are git-ignored and never hand-edited),
- the fix branch, the PR and the issue-comment workflow.

**Out of scope.**

- new features or new cloud resources beyond what the tutorial already uses,
- changes to the operator's cloud account, credentials or billing setup,
- anything that costs beyond the public award, and any long-running compute.

**Definition of done.** A live walkthrough with zero critical and zero major findings, a passing docs site build, the branch pushed, and a PR that closes the issue.

**Where the process lives.** This playbook, the repo `AGENTS.md`, and a per-tutorial state directory kept by the operator outside the public repo (private round reports and evidence).

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

- First access to the research cloud gateway account goes through a federated login chain (identity provider, plus multi-factor). It cannot be automated.
- Before the first walkthrough, discover and RECORD the exact working login chain for the provider in the state directory (entry point, identity provider to choose, MFA flow, and the dead ends to avoid). Do not re-derive it in later rounds; the guides are often stale on this exact point, and the wrong identity provider or a missing prerequisite step yields an account-level denial that costs time to diagnose.
- Protocol: the executor pauses; the human completes the login in the visible browser window (GUI mode for the first login only, headless afterwards); credentials come from a secrets manager CLI and are passed through environment variables, never pasted into the transcript; the agent never types credentials and never clicks consent or "Authorize" buttons (with explicit per-case human approval it may click a benign confirmation, for example a one-time service authorization).
- One-time confirmation screens on the identity-provider side often have short-lived tokens: complete them (human, or agent with approval) promptly, or re-run the flow to get a fresh token.
- After the first login, continue headless with the same profile; cookies carry the session.

**Project golden check (mandatory, before creating anything).**

- Confirm the active cloud project (or billing account) is the one assigned to the tutorial by the access portal; record the project id and project number.
- Never create resources in a personal project. If the active project is not the tutorial project, abort and create nothing.
- Never trust local CLI credentials: the operator's local machine may be authenticated as a different personal account pointing at a personal project. Do all CLI work inside the cloud provider's browser terminal in the tutorial project, and verify the active account and project there each round.

**Browser terminal (provider) reliability.**

- Web-based terminals are the most fragile surface of the whole walkthrough. Before starting, verify the terminal is drivable: type one trivial command and confirm it echoes. Do not start a walkthrough on an unverified terminal.
- Keep the terminal tab active/foregrounded while typing; a backgrounded tab can freeze the terminal.
- Generic automation input is often ignored by web terminals (for example they use a hidden textarea and a custom renderer). Known working methods are per-character trusted key events and, most reliably, a per-line synthetic paste event delivered to the terminal's textarea followed by a trusted Enter. Record the working method for the provider in the state dir.
- A broken terminal may be tied to the terminal session or machine, not to the browser profile: a fresh profile can still "recover" the same dead session. The reliable fix is restarting the terminal environment from its own control; a fresh browser profile alone is not sufficient.
- After the one-time authorization/consent dialog, confirm the CLI is actually authenticated inside the terminal (an `auth list` must show the tutorial identity). A failed consent dialog can leave the CLI unauthenticated even though the web UI works; complete a CLI login through the browser in that case.

**State directory.**

- Create one state directory per tutorial outside the public repo (for example under the operator's notes). It holds the per-round JSON reports, the evidence files (screenshots, logs, executed notebooks), the recorded login chain, and the working input method for the terminal.
- Never commit the state directory to the public repo; evidence can contain resource identifiers and console details that should stay private. When archiving it into the operator's private notes, exclude secrets, private keys and large binaries.

**Session hygiene.**

- Create a long-lived goal so the session keeps working across rounds; keep only live subagents in the list and interrupt every agent as soon as it settles.

## 4. Live walkthrough protocol

**Execution rules for the executor.**

- Follow the guides literally, in order, the way a beginner would: no hidden steps, no skipped cells, no invented values. If automation forces a deviation (for example a guided wizard cannot be driven by an agent and the equivalent CLI command is used instead), record the deviation explicitly as an executor-only note; it is not a doc finding.
- Fresh start each round: resources created by the previous round must be gone before the walkthrough begins, so the run reproduces a brand-new user.
- Environment first, budget second: a walkthrough attempt does not count against the live-run cap until the environment is confirmed working (valid session, golden check passed, terminal verified with an echo). Environment-only failures (dead terminal, lost session, transient capacity error) are repaired (restart the terminal environment, redo the login, retry once) rather than treated as a failed run; if repair is not possible, stop with `needs_human` instead of consuming the cap.

**Pre-existing resources.**

- Before creating anything, inventory the current state of EVERY nameable resource class the tutorial touches or might collide with: compute instances/workers, storage buckets, service accounts, persistent disks, firewall rules, ingress/load balancers, endpoints, registries, and pipelines. Record the list (with identifiers) in the round JSON, in the `resources` field.
- Never delete or modify a pre-existing resource. Some tutorials assume a resource does not exist; if it already exists (from an earlier run or another workload), apply the guide's skip-if-exists or documented fallback name, move on, and say so in the report. If the guide has no fallback for a nameable resource (bucket, service account, disk), that is a doc finding: add a documented name-taken fallback used consistently by every later command that references the name.

**Evidence to collect (per step).**

- console screenshots at each meaningful state (login, dashboard, list, creation dialog, deletion dialog, empty list after cleanup),
- terminal outputs with exit codes, and logs (including any notebook-converter runs: exit code and elapsed time),
- resource identifiers (instance name, zone, project id, rule names),
- the executed notebook saved to the state dir (the strongest evidence that the tutorial runs end-to-end),
- version truth: driver or runtime version, package status after the install step, language runtime version,
- the resolved versions of every tool the guides mention (CLI, chart, image, dependencies), used later to refresh expected-output blocks.

**Cleanup (mandatory, in the same round, with proof).**

- Delete only the resources this run created; ephemeral public IPs are released with the resource they belong to.
- Prove deletion: a console or CLI listing showing zero of the created resources and only the pre-existing resources remaining (screenshot or captured output).
- Never leave anything running, never leave a billable resource behind, never rely on "it will be deleted later".
- Cleanup must stay possible without the browser terminal: if the CLI stops responding mid-round, finish the deletion through the console UI and record the deviation. Provider-specific residuals that are not violations (for example a bucket kept in a soft-delete state for a few days, an inactive cluster record) are expected: record them and move on.
- Remove the operator artifacts left inside the terminal environment used for the walkthrough: config files, TLS key/cert pairs, and any generated credential or password written to the terminal home.
- Do not touch credentials, consent dialogs, "Authorize" buttons or destructive confirmations; if one appears, record it, leave it unclicked, and hand off to the human.

**Per-guide verdicts.**

- `pass`: every step completed as documented, evidence captured, no doc defect,
- `partial`: the underlying mechanism is verified end-to-end but an accessory step (usually a desktop GUI client) cannot be driven by browser automation; mark severity `none` unless a real doc defect was also found,
- `fail`: a step cannot be completed as documented; attach the exact error and the doc finding (severity critical or major).

**Transient provider errors.**

- Single-create failures that happen during provisioning (for example a transient capacity or quota error) are environment issues, not doc findings: record the exact error, delete the failed resource if it was created, and retry once. Only if the same failure repeats in two consecutive attempts does it become a candidate doc finding.

**Costs and safety.**

- No compute beyond what the guide instructs, no job submissions of any kind; costs stay on the public award.
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
- Record the provider login chain and the working terminal input method in the state dir (a small `facts` file or the first round JSON), so later rounds and later tutorials do not rediscover them.

Verdict rules on a report:

- Clean: every guide `pass` or `partial` with severity `none` (partial alone is fine, it is a tooling note).
- Not clean: at least one finding with severity `critical` or `major`; the improver must fix all of them before the next live run.
- Minor findings do not block the loop but should be collected and fixed in the same fix round or in the final polish.

## 6. Fix round protocol

**Order of work.**

1. Read the last executor report; list every critical and major finding and map each to a specific fix in a specific file.
2. Fix the docs (guide text, commands, ordering, pins, expected values). Never patch cloud resources to make the docs "work".
3. Research first for any version drift (see below). Never pick a version by "latest looks fine".
4. Re-check cross-guide consistency after editing: instance names, zones, ports, firewall rule names, package pins, sequence references ("completed tutorial N") and guide numbering are all referenced from multiple files.
5. Register any new or renamed guide in the docs-site generator (`files` list with title and sidebar position; keep the explicit integer positions monotonic). Without that entry the guide never appears on the published docs site.
6. Verify the docs site: run the project's sync + build commands; they must succeed (generated files are git-ignored). Do this before every push that touched a guide or notebook.
7. Commit with a message that references the issue, push the branch.

**Research-first approach to version drift (the pattern that matters).**

- A tutorial that lets libraries resolve "latest" drifts: a new release silently changes behavior and the notebook breaks on a fresh install while the operator's cached environment still works.
- Do not blindly bump to the newest version; find the last compatible release:
  - read the package registry commit history and the GitHub compare API for a release range,
  - identify the upstream PR or commit that introduced the breaking behavior and the first release that contains it,
  - take the newest release strictly before that commit,
  - cross-check compat constraints from the registry (what the other packages in the set allow) so the pin resolves a consistent set without silently downgrading something needed.
- Pin explicitly in the guide's install step and document why, with a short note that the version is pinned on purpose.
- After pinning, confirm the resolution with a live run: `actual_versions` must show the pinned version exactly.

**Expected-output blocks.**

- Refresh every expected-output block to the byte-exact observed values captured from the evidence files. Do not transcribe from memory; copy from the captured text files.
- Keep a one-line caveat in the guide that exact patch versions may differ slightly on a fresh install, while pinned versions should resolve as documented.
- If versions changed, refresh the executed notebook outputs too; the executed notebook is published on the docs site and is what users download and re-run.

**What the improver never does.**

- Never touches cloud resources, credentials or the live console.
- Never edits generated docs files by hand.
- Never changes notebook code cells unless a real code bug is found; prefer a version pin over a code patch when the failure is drift.

## 7. Wrap-up

- Push the branch (automatic during the loop; never leave unpushed work behind).
- Open a pull request with a focused title and body that references the issue (`Closes #<issue>`), following the repo convention, and present it for explicit human approval before merging.
- After the merge (or on the branch before it, per the human's choice), comment on the issue with per-guide results and the versions verified, and tick the issue checkboxes one by one as each guide is confirmed.
- Update the repo README `Last Verified` row in the final fix round (format `Month YYYY`); that row is the public signal that a tutorial is maintained.
- Time tracking: record the duration spent and the project it is charged to, per the operator's standing convention (propose a duration and a project, have the human confirm).
- Subagent hygiene: interrupt and clean up every finished subagent as soon as it settles; keep the agent list limited to live workers.
- Deliverables: the merged PR, the issue comment with ticked checkboxes, and the private round JSONs in the state dir for the record.

## 8. Operating rules that apply every time

These rules are provider- and tutorial-neutral; they were all learned the hard way and should be applied proactively.

**Documentation gets stale faster than you think.**

- The access/entry-point instructions in tutorials are the most likely to be wrong: portals change login chains, identity providers and consent screens. Always verify the login path live and record it; never assume the guide's first steps are correct.
- Version pins and sample output blocks drift silently. Treat every expected-output block as suspect until refreshed from live evidence.

**Environment failures are not doc findings.**

- Broken browser terminals, lost sessions, transient capacity errors and consent failures are environment problems: repair them (restart the terminal environment, redo the login, retry once) before drawing conclusions about the docs. Do not convert an environment failure into a guide defect, and do not let it consume the live-run budget.
- Conversely, a guide that fails on a genuinely fresh environment (a brand-new user 404s, a create command rejects a name the guide hardcodes) IS a doc finding, usually `major` or `critical`.

**Everything nameable can collide.**

- Re-runs and author testing leave behind buckets, service accounts, disks, rules and pipelines with the exact names the guides use. Inventory all of them before creating anything, and make sure guides document a name-taken fallback for every nameable resource they create.

**Long runs need a heartbeat.**

- Long autonomous runtimes stall without printing anything. The orchestrator keeps a status cadence (check evidence timestamps and console state every ~15 minutes) with a stuck rule: no new evidence for a long interval, or a resource stuck mid-state, means investigate; on a broken environment, repair or abort and clear anything created; on a dead agent, relaunch with the recorded facts (login chain, working input method, current browser state).

**Cleanup is a hard requirement, not a final step.**

- Delete everything the run created in the same round with proof, keep cleanup possible without the CLI, and treat provider residuals (soft-deletes, inactive records) as documented non-issues.

## 9. Checklist for the next tutorial

Work through the open issues one at a time, oldest tutorial first (repo convention).

- [ ] Open issues identified; the next unverified tutorial is chosen (oldest first).
- [ ] Branch created from `origin/main` with a focused name (`verify/<slug>`).
- [ ] Repo `AGENTS.md` read; tutorial folder structure read (README + guides + notebooks).
- [ ] Browser automation up: dedicated profile, CDP endpoint answering, headless default.
- [ ] Provider login chain discovered live and recorded (entry point, identity provider, MFA, dead ends); one-time interactive logins done with the human, then headless with the same profile.
- [ ] Browser terminal verified: input method known, one echo observed, CLI identity confirmed inside the terminal; environment restarted if stale.
- [ ] Project golden check passed and recorded (grant-provided project, not a personal one); local CLI ignored.
- [ ] Pre-existing resources inventoried and recorded before anything is created, for every nameable resource class.
- [ ] Baseline polish round done (static drift plus cross-guide consistency), pushed.
- [ ] Live walkthrough executed literally with evidence (screenshots, logs, executed notebook); environment failures repaired first and not counted against the live-run cap.
- [ ] Orchestrator status cadence in place (check evidence + console state roughly every 15 minutes; on stuck, repair or abort and clear created resources).
- [ ] Cleanup done and proven: no resources created by this run remain (console-only cleanup acceptable with proof; provider residuals recorded; terminal-home artifacts removed).
- [ ] Round JSON written to the private state dir.
- [ ] Fix round addressed every critical and major finding; version drift researched and pinned with evidence.
- [ ] Expected-output blocks refreshed byte-exact from captured evidence.
- [ ] New or renamed guides registered in the docs-site generator.
- [ ] Docs site verified (sync + build).
- [ ] README `Last Verified` updated to the current month and year.
- [ ] Branch pushed; PR opened with `Closes #<issue>`; human approval before merge.
- [ ] Issue comment posted ticking the checkboxes with per-guide results.
- [ ] Time recorded (duration plus project) per the operator's convention.
- [ ] Subagents cleaned up; private state dir archived into the operator's notes (secrets, keys and large binaries excluded).
- [ ] Browser tabs swept (or the automation browser stopped) after the run.

**Conventions from repo AGENTS.md that apply every time.** The tutorial folders remain the single source of truth (the docs site is generated; never hand-edit generated files); docs stay beginner-friendly (simple steps first, advanced material in a clearly marked appendix); run the docs sync + build whenever a guide or notebook changes; make focused commits on a branch and open a PR that references the issue; verification work is tracked per tutorial in "Verify & refresh: <tutorial>" issues, and progress is logged as issue comments with checkboxes ticked as each guide is confirmed.
