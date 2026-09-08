# Tooling reference

Everything here was paid for once already. Read it before the first write.

## Trello: two servers, not one

Two MCP servers can reach Trello and they do not cover the same boards:

- `mcp__claude_ai_Trello__*` — works for some boards (Apotek 1). Requires ARIs for writes.
- `mcp__trello__*` — the local server. Needed for boards where the first one reports
  "could not verify workspace permissions" / "could not be found, or you do not have
  access" (Risa). That error is **not** a permissions problem to escalate; it is a signal
  to switch servers.

`boards.json` records which server works per board. If a board's entry is wrong, fix it.

## ARIs are mandatory for claude.ai Trello writes

```
ari:cloud:trello::card/workspace/<workspaceId>/<cardId>
ari:cloud:trello::list/workspace/<workspaceId>/<listId>
```

Short links (`trello.com/c/jjEskCPo`) and card URLs are rejected. So a read pass to collect
ids is mandatory before any batch write — which is free, because it is the same read that
verifies the register.

- `move` echoes the full card back, including its new list. Use that as verification.
- `add_comment` returns only a `commentId`.
- Trello `add_comment` works under the auto-mode classifier. Linear's `save_comment` does
  not, so plan Linear-side notes as attachments or leave them to a human.
- Bash commands that read the Trello credential file are also classifier-blocked. If a raw
  API call is unavoidable, the human runs it (`! python3 …`).

## Card identity is per board

There is no universal join key. Check which case you are in before matching:

- **Boards that number every card title** (Apotek 1): join on the title number. `idShort`
  diverges there — deleting the card at `idShort` 60 shifted everything after it, so title
  60 = idShort 61 up to title 68 = idShort 69. Linear's existing `Trello card #NN` rows
  were written from title numbers, so `idShort` disagrees with the links already in Linear.
- **Boards that number nothing** (Risa): titles have no leading number and `idShort` is
  **not unique** — duplicates exist from board templates and from cards imported off the
  closed test-phase board. Join on `shortLink` or the url attachment only.

`shortLink` is always unique. Prefer it whenever the board's convention is unclear, and
never join on `idShort` without confirming uniqueness on that specific board first.

## Harvesting comments and history cheaply

Per-card reads do not scale past a few dozen cards. On the local server:

```
get_recent_activity(limit=1000, since=<ISO date>)
```

spills to a file. Mine it with `jq` for three things in one pass: every list move, every
comment, every url attachment. That is where card↔issue joins and customer verdicts come
from. One call replaces roughly 80.

## Archived cards are easy to miss

Resolved work leaves some boards by **archival**, not by sitting in a resolved column
(Risa). An archived card can still be awaiting deployment, and:

- the local server has no archived filter, so archived cards are not enumerable there;
- `mcp__claude_ai_Trello__trelloReadCard` with `action: "list_by_board"` accepts
  `filter: "archived"` or `"all"`;
- `trelloSearch` with an `is:archived` term scoped to the board also works.

Counting only the resolved column understated delivery roughly threefold on the Risa board.

## GitLab: set the host or lose the answer

`glab` is authenticated for `git.bs.netpower.no`. It **defaults to gitlab.com**, which has
no token, and the resulting error reads `Unauthenticated` — which looks exactly like an
expired token and has caused a reconciliation to abandon deploy verification entirely.

```bash
export GITLAB_HOST=git.bs.netpower.no
glab api "projects/<url-encoded-path>/merge_requests/<iid>" \
  | jq '{iid, title, state, target_branch, merged_at, detailed_merge_status, draft}'
```

Project paths, url-encoded:

| Repo | Path | Default target |
|---|---|---|
| frontend monorepo | `certain-qms%2Ffrontend%2Fnetpower.qms.frontend` | `main` |
| qms monorepo | `certain-qms%2Fnetpower.qms` | `beta/1.40.0.0-new` |
| Control backend | `certain-qms%2Fbackend%2Fnetpower.qms.backend.checklist` | `main` |

Linear's MR attachments carry `subtitle: null` on every issue, and the Bitbucket ones carry
only a generic product blurb. **Merge state is not readable from Linear at all.**

### Squash merges and ancestry

These repos **squash-merge**, so `merge_commit_sha` is `null` on every merged MR. A null
merge commit is not evidence the MR never merged — check `state` and `merged_at`, and use
`squash_commit_sha` when you need the commit that actually landed.

To ask "is this MR's commit in the deployed build", use merge-base, not compare:

```bash
glab api "projects/<enc>/repository/merge_base?refs[]=<squash_sha>&refs[]=<deployed_sha>" \
  | jq -r .id
```

If the result equals `<squash_sha>`, the commit is an ancestor of the deployed sha and is
in the build. Do **not** reach for `repository/compare` for this: its default non-straight
mode makes an empty commit list ambiguous, and reading empty as "is an ancestor" inverts
every in-build verdict.

## The deploy cut-off is not the deploy timestamp

Deployments live in `deployment/prod/deployment-qms` (project 50), one customer per
pipeline run selected by the `TARGET` variable, with `PACKAGE_VERSION` choosing the package
slot. **The slot is per-customer**: a customer on `1.34.6.0` has a completely different
cut-off from one on `1.40.0.0`, so never reuse another customer's answer.

```bash
P=deployment%2Fprod%2Fdeployment-qms
glab api "projects/$P/pipelines?updated_after=<date>&per_page=100" \
  | jq -r '.[] | "\(.id) \(.status) \(.created_at)"'
glab api "projects/$P/pipelines/<id>/variables"   # TARGET / PACKAGE_VERSION
glab api "projects/$P/pipelines/<id>/jobs"
glab api "projects/$P/jobs/<jobid>/trace"
```

Then the part that is easy to get wrong: `assemble:package` pulls each app's **mutable**
generic-package slot, so the deployed build is a mix of per-app publish times, not one
commit. A frontend MR merged two hours before the deploy job ran can still have missed the
build. Reconstruct per-app publish times from the **full paginated** `package_files` upload
history (project 55), not page 1.

**Retention defeats this for older deploys.** The frontend app slots keep 84–134 files
each, so they reconstruct fine. The `qms-package` slot keeps only about **5 files**, so
anything older than roughly two weeks is already pruned and the .NET side has to be
reconstructed from CI job history instead (`build:dotnet:hosts`, `assemble:package` on the
qms project). If a slot has been pruned, say so rather than reporting the oldest surviving
file as the publish time.

The cut-off is genuinely **seven-plus values**, not one: each V3 app slot, the .NET hosts,
the V2 Angular bundles (which can be frozen weeks earlier in the same repo), and the k3s
backend images, which are pinned by **tag** and carry no timestamp at all. Compare each MR
against the slot its code actually ships in.

Three failure modes worth checking rather than assuming success:

- the deploy leaves IIS sites and the Windows service **stopped**, to be started by hand;
- `deploy-backend` (k3s) can fail while `edge-deploy` proceeds anyway and cuts traffic over
  to the failed namespace;
- `migrate-backend` can apply DB migrations to a backend that never started, which is an
  audit-trail exposure when the migration is BREAKING.

A pipeline that "succeeded" is not the same as an environment that serves the fix.

Because the sites are started by hand and that start is unlogged, the deploy timestamp is a
**lower bound** on go-live, never the moment itself. Report it as "at or after".

## What this recipe cannot reach

Two whole classes of work are invisible to the pipeline recipe above. Classify them
**Unverifiable** and say why; do not stretch the qms-package evidence to cover them.

- **SPFx webparts** ship through the SharePoint app catalog as `.sppkg`, not through
  `qms-package`. There is no version or publish timestamp to compare against, so "fixed in
  code, old package still installed" is plausible and unprovable with these tools.
- **NP365 / P365 work** links **Azure DevOps**, not GitLab. The `glab` merge-state recipe
  cannot see those MRs at all. On boards where P365 is a large share of the cards (Risa,
  roughly 40 percent), say up front which portion of the board you could not evidence.

## Linear write mechanics

- **URL attachment:** `save_issue` with `links:`. This works.
- `create_attachment` is **file-upload only**. For files: `prepare_attachment_upload` →
  `curl -X PUT --data-binary` to the signed URL → `create_attachment_from_upload`. The
  signed URL lives 60 seconds and MCP calls serialize at roughly 30 seconds each, so never
  issue two prepares before their PUTs and never batch a finalize with a PUT.
- **Do not rewrite issue descriptions** that embed `uploads.linear.app` images: the body
  carries expiring `signature=` / `exp=` params, and a rewrite persists the read-time
  signature and permanently breaks the images.
- `save_customer_need` with a `source` URL already attached to the issue fails with
  "already been linked". Put the URL in the body instead.

## GDPR

Customer screenshots on these boards contain employee names and real case data. Keep them
out of anything published. Attach to Linear only when the issue genuinely needs the
evidence, and remember the reversal path is deleting the attachment rows. Examples in
reports and specs use synthetic data.
