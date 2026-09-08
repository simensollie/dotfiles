---
name: trello-linear-reconcile
description: Use when comparing a customer Trello feedback board against Linear issues, aligning card status with engineering status, deciding whether a card is fixed but not yet live for the customer, moving cards to a fixed/awaiting-deployment column, or backlinking cards and issues. Covers a single card as well as a whole board, for any customer (Apotek 1, Risa, and others).
---

# Reconciling a customer Trello board against Linear

**Core principle: Linear `Done` is not "the customer can see it".** Tracker state proves a
decision was recorded. Only a merge timestamp compared against that customer's deploy
cut-off proves the fix is visible.

## Scope first

Pick the mode before touching anything. Subagent fan-out is for boards, not cards.

| The ask | Mode |
|---|---|
| One card: "what's the status of #54", "should #54 move", "update #54" | **Single card.** Read that card, its issues, their MRs, the cut-off. Inline, no subagents. |
| A handful, up to roughly ten | **Spot check.** Same reads, sequentially. No fan-out. |
| The whole board: "reconcile Risa", "which cards can move" | **Full sweep.** Staged gather, three subagents then one. See step 2. |

**Establish the deploy cut-off once per customer per session, then reuse it.** It is the
same answer for every card on that board. Re-deriving it per card is the main way this
work turns expensive for no gain.

## The verdict contract

Every card you classify produces a row with **all five cells filled**. A blank cell is not
a verdict, it is an unfinished lookup.

| Card | Linear issue(s) + state | Latest MR `merged_at` | Cut-off it is measured against | Verdict |
|---|---|---|---|---|

- A card often maps to several issues across several repos. List them all; use the
  **latest** `merged_at`, and measure each MR against **its own** repo/app cut-off.
- `merged_at`: a UTC timestamp, `no MR linked`, or `MR open`. Never blank.
- **The cut-off is not one timestamp.** It is one per app slot, plus the .NET hosts, plus
  V2 Angular bundles that can be frozen weeks earlier in the same repo, plus backend image
  tags that are not time-based at all. Name which cut-off the row uses. Margins are real:
  one app cleared a build by 33 seconds.
- The cut-off is also only a **lower bound**. The deploy leaves IIS sites stopped for a
  human to start, and that start is unlogged, so true go-live is "at or after" the deploy.
- Cannot establish it? Say so up front and label every verdict provisional. Do not quietly
  fall back to tracker state.

## Classification

First match wins.

| Evidence | Verdict |
|---|---|
| No Linear issue found | **Untracked.** Report it. Never move, never backlink a guess. |
| MR open or draft | **In progress.** Tracker state is irrelevant here. |
| Issue Done, no MR or branch anywhere | **Unverifiable.** Flag it; it cannot be placed against any build. |
| Issue Done, MR still open | **False Done.** Report the contradiction. |
| Card's actual ask was never built (issue closed on narrower scope) | **False Done.** Needs a follow-up issue, not a move. |
| MR merged **after** the cut-off | **Fixed, awaiting deployment.** |
| MR merged **before** the cut-off, customer says not fixed | **Not a deploy problem.** Say which: dark feature flag, config default, partial fix, or regression. |
| MR merged before the cut-off, but inert until a per-tenant flag, `appsettings` key, DB upgrade or background job is switched on — whether or not the customer has complained | **Live but inert.** Deploying changes nothing. Name the exact activation step. This is the most common real state; do not file it as awaiting deployment. |
| MR merged before the cut-off, customer accepted | **Done.** |

Merged-before plus customer-rejected is the row that gets misfiled as "awaiting
deployment" — which tells the customer to wait for a rollout that will change nothing.

## Process

1. **Resolve the board** from `boards.json` here: board id, list roles, Linear projects,
   deploy target, per-board conventions. Unknown customer, or a needed role absent (many
   boards have no awaiting-deployment column) → stop and report. Never invent a column.
2. **Gather** per the mode above. A full sweep is **staged, not four-way parallel**: MR
   lookups need the MR list Linear returns, so run three in parallel — Trello cards,
   Linear issues across **every** project in the register entry, and the deploy cut-off —
   then GitLab `merged_at` once the MR list exists. All four sources are required for a
   complete row.
3. **Join using the board's `joinKey`.** It is per board, not global: some boards number
   every card title, others number none and reuse `idShort` across imported duplicates.
   `shortLink` and url attachments are always unique; prefer them when in doubt. Never
   join on `idShort` without first checking it is unique on that board.
4. **Present the verdict table and stop.** No writes before the human confirms.
5. **Write Trello only**: move plus one comment per card, in the board's comment language.
   Then backlink both directions, idempotently.
6. **Report Linear problems, do not fix them** — stale states, mis-filed MR links, false
   Dones go in the report for a human.

## Backlinking

- Issue → card: `save_issue` with `links:`. `create_attachment` is file-upload only.
- Card → issue: follow the board's `backlinkStyle`. Silent url attachment where the
  customer should not be notified, comment where they should.
- Idempotency: match on the extracted `/c/<shortLink>` segment, never the full URL —
  Trello returns two URL shapes for the same card.
- Never link a merely nearest ticket. It poisons every later reconciliation.

## Hard rules

- Our own card comments ("Løst, kommer i neste oppdatering") are claims, not evidence.
- Customer accepted ≠ our Done, both directions. Customers pull cards back out of resolved
  columns; that is signal, not an error to correct.
- **Resolved → awaiting-deploy is allowed and is not "backward."** List order is not
  workflow truth: on some boards awaiting-deploy sits before the resolved column, so this
  move looks backward and is still correct — the card was marked resolved prematurely. What
  is forbidden is moving a resolved card back into an *in-flight* role (backlog,
  in-progress, bugs); that is the customer's call, not ours.
- **No awaiting-deploy column on this board?** The output is a comment plus the report. Do
  not create the column, and do not move the card somewhere approximate.
- Record deliberate exclusions: which cards you chose not to move or link, and why.
- Comments are customer-facing. Board's language, professional B2B tone, no internal
  blame, no employee names, no real customer data in examples.
- Flag anything touching audit trails, approval workflows or document control, and any
  BREAKING change whose migrations may already be applied.

## Red flags

| Thought | Reality |
|---|---|
| "Linear says Done, so it shipped" | Done is a recorded decision. Shipping is a timestamp. |
| "glab says Unauthenticated, the token expired" | `glab` defaults to gitlab.com, which has no token. Set `GITLAB_HOST`. |
| "I'll check the project named after the customer" | Work splits across projects and teams. Use every one in the register. |
| "The Trello connector 403s, so I have no access" | Two Trello servers exist. Fall back to the other. |
| "Linear's MR attachment shows merge state" | Subtitles are null. Merge state comes from GitLab only. |
| "I'll skip the deploy check and caveat it" | That is the step that turns a guess into an answer. |
| "The register lists the columns, so I can write" | Verify list ids against live data first. Boards gain columns. |
| "One card, so I'll fan out four agents" | Fan-out is for boards. One card is a handful of inline reads. |
| "The register says a number/slot, so it's true" | The register is a hint. A wrong `packageVersion` or `joinKey` biases the whole sweep. Verify, then correct the entry. |
| "It's merged and in the build, so it's delivered" | It may be inert behind a flag, an `appsettings` key, a DB upgrade or a stopped background job. |
| "No merge commit, so it never merged" | These repos squash-merge: `merge_commit_sha` is null on merged MRs. Use `squash_commit_sha`. |

## Reference

`reference.md` — tooling gotchas, ARIs, cheap activity harvesting, archived cards,
per-customer package slots, Linear write hazards, GDPR. Read before the first write.
