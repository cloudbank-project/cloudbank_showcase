# AGENTS.md

Guidelines for working in this repository.

## Repo overview

- `cloud_analysis_seismology/`, `gpu_computing_oceanography/`, `knowledge_graphs_chemistry/`, `toy_data_portal_hydrology/` — tutorial source folders (markdown guides + notebooks). **These are the single source of truth** for content.
- `website/` — Docusaurus docs site. It is generated from the tutorial folders; never hand-edit `website/docs/tutorials/` (git-ignored).
- The docs site publishes to GitHub Pages on every push to `main` (`.github/workflows/docs.yml`).

## Changes

- Do not edit files ad hoc on `main`. Create a branch, make a focused commit, open a PR that references the issue (e.g. `Closes #12`).
- Documentation for tutorials must stay beginner-friendly: simple steps first, advanced/optional content in a clearly marked appendix.

## Building the docs site

```bash
cd website
npm install
npm run sync     # regenerates docs/tutorials from tutorial sources (run before building)
npm run build    # verify the site compiles
```

Always run `npm run sync && npm run build` when a guide/notebook changes.

## Verifying tutorials

Verification work is tracked in GitHub issues ("Verify & refresh: <tutorial>"). Work through them one at a time, oldest tutorial first, and log progress as issue comments (and tick the issue checkboxes) as each guide is verified.

When verifying, check these external dependencies (all were confirmed reachable for the seismology tutorial; re-check them if they change):

- `s3://scedc-pds` — public SCEDC dataset. Anonymous access: `aws s3 ls s3://scedc-pds --no-sign-request`
- `ghcr.io/seisscoped/noisepy:centos7_jupyterlab` — container image (bundle may change; it ships its own `noisepy` with the `noisepy.seis.io.*` API)
- PyPI: `noisepy-seis` splits its IO layer into `noisepy-seis-io` (install `noisepy-seis` pulls it)

## Browser automation of the AWS console (ai-browser-control-chromeos)

The ChromeOS browser skill is used to walk tutorials in the real AWS console. Key patterns that work (the vanilla `click` on many Cloudscape controls times out on "stable"; use these instead):

1. **Session**: `ai-browser-control-chromeos status` → `connect`/`reconnect` if disconnected → `wait 180` → `verify` before relying on it. Scrollable coordinates are viewport-relative; call `el.scrollIntoView({block:'center'})` (via `eval`) before coordinate clicks.
2. **Reading state**: prefer `find`/`snapshot` (these pierce iframes/shadow DOM) over `eval` on `document` (which only sees same-origin, non-shadow content). For `eval`, walk iframes explicitly:
   ```js
   const walk=(n,ctx,acc)=>{ if(!n) return; if(n.nodeType===1){ acc.push({n,ctx}); if(n.shadowRoot) walk(n.shadowRoot,ctx+'-sh',acc); } for(const ch of (n.children||[])) walk(ch,ctx,acc); };
   const all=[]; walk(document,'top',all); [...document.querySelectorAll('iframe')].forEach((f,i)=>{ try{ walk(f.contentDocument,'if'+i,all); }catch(e){} });
   ```
3. **Clicking Cloudscape buttons/radios/options** — when `click`/`check` time out, use `eval` to dispatch a full PointerEvent + MouseEvent sequence on the element (`pointerdown`/`mousedown`/`pointerup`/`mouseup` + `click()`, all `bubbles:true`). This works for radios in tables, dropdown options, and dialog buttons.
4. **Filling inputs**: use the `fill` command with refs where possible (works even for CodeMirror/autosuggest inputs). For React-controlled inputs not reachable by `fill`, set the value with the native setter + `input` event:
   ```js
   const setter=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;
   setter.call(input,'value'); input.dispatchEvent(new Event('input',{bubbles:true}));
   ```
5. **Destructive confirmations** (remember to keep the user safe — never click "Delete user" etc. by accident):
   - IAM user delete: dialog first requires **Deactivate access keys**, then typing `confirm` into the text field.
   - S3 bucket delete: must be **Empty** (type `permanently delete`) before **Delete** (type the bucket name).
   - Key pair delete: type `Delete`.
6. **CloudShell**: the terminal is an iframe and does not accept `type`/keyboard reliably — prefer the console UI patterns above.
7. After cleanup, verify with `aws` CLI + `--no-sign-request` for public resources, or by re-opening the relevant console list.

## Cleanup

When a verification run is finished, offer/perform cleanup of created AWS resources (instance, bucket, key pair, security group, IAM user) unless the user wants to keep them.
