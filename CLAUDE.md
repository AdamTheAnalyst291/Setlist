## Agent skills

### Issue tracker

Issues live in GitHub Issues for AdamTheAnalyst291/Setlist, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default triage labels: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Working with agents

Tickets are the sub-issues of the spec, #3. A ticket can start only when every ticket blocking it is merged.

### Roles

- **Parent session (quarterback).** Picks the next unblocked tickets, proposes a child session for each, answers the children's questions or passes them to the user, reviews each pull request, and keeps the issues and #3 up to date. It never writes ticket code. The only files it changes itself are agent and planning docs such as this one.
- **Child session.** Builds exactly one ticket, on one branch, ending in one pull request that closes its issue.
- **Subagents.** Short helper jobs inside a turn only: checking a fact on a web page, searching the code, an independent review. Never a ticket.

### Starting children

- The parent proposes each child session as a card with its brief, and the user starts it. Don't start children automatically unless the user changes this rule.
- At most two children run at once. Two children never work on the same files.
- Each child runs locally in its own git worktree, branched from the latest `main`, with a fresh context. The brief points to the ticket and starts with `/mattpocock-skills:implement #N`. If that doesn't start the skill, the brief lists the steps below.
- Models: the parent uses Claude Opus 5.5. Children use Claude Sonnet 5.5, except Claude Opus 5.5 for #6, #16 and #21. Subagents use Claude Haiku 5.5 or Claude Sonnet 5.5.

### How a child builds a ticket

1. Assign the issue to the user. Read it, the spec (#3), `GLOSSARY.md` and this file.
2. Build test-first with the `tdd` skill at the seams the spec names. Typecheck and run single test files often, and run the full test suite at the end.
3. Review the diff with the `code-review` skill and fix what it finds.
4. Rebase onto the latest `main`, fix any conflicts, and rerun the tests.
5. Commit, push, and open a pull request named after the ticket, with `Closes #N` and the acceptance criteria as a checklist.
6. Turn on Auto-fix for the pull request, wait for CI to pass, then report back to the parent.

### When a child stops and asks

A child decides everything else itself, but asks the parent first:

- before creating or changing anything that could cost money (Azure resources, Anthropic API calls such as the prompt eval)
- before changing GitHub or Azure settings (branch protection, environments, identities, permissions)
- before anything destructive (deleting resources, data or branches, force pushes)
- when the ticket is unclear, or conflicts with the spec, an ADR or the glossary
- when the same blocker has failed twice

The parent passes on to the user whatever only the user can decide.

### Review and merge

- The parent reviews every pull request:
  - CI checks pass
  - each acceptance criterion is met
  - a `code-review` run against `main` covers the repo's standards and the spec
  - for tickets that deploy, the change works in Dev
- The parent reports the result to the user in one short message, recommending merge or fix first. Nothing is posted on GitHub unless the user asks.
- Findings go back to the child that built the ticket, which fixes them on the same branch and reports again.
- Only the user decides to merge. Children never merge.

### After a merge

The user has given the parent standing permission to do these without asking each time:

- pull `main`
- delete the merged branch locally and on GitHub
- remove the child's worktree
- archive the child session
