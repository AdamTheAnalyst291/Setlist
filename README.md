# Crowd Setlists

A tool for a solo acoustic guitar player: find the songs each crowd wants to hear, learn them, track practice, and build setlists.

The prototype is a single page, [`crowd-setlists.html`](packages/artifact/crowd-setlists.html), published as a claude.ai artifact at <https://claude.ai/artifact/5PwVhu5KTpTwiLMnSYhvyk>. It uses the [Crowd Setlists Google Sheet](https://docs.google.com/spreadsheets/d/1lKH0HdpqFFAiq90JxJMtxhMh2hSE2st72W0oayqNxSM/edit) as its database.

## Repository layout

A TypeScript monorepo using pnpm workspaces and Turborepo.

| Path | What it is |
|---|---|
| `apps/web` | React (Vite) web app, a stub for now |
| `apps/api` | API on Azure Functions (Node), with a `GET /api/health` endpoint |
| `packages/shared` | Types shared by the web app and API |
| `packages/artifact` | The original claude.ai page. It is published by hand and has no scripts, so no pipeline runs it |
| `infra` | Terraform for the Azure environments; see [`infra/README.md`](infra/README.md) |

## Install, build and test

You need Node 24 and pnpm 12.

```bash
pnpm install
pnpm build
pnpm lint
pnpm typecheck
pnpm test
```

Each script runs `turbo run <task>` across all packages. Turborepo caches results, so unchanged packages replay instantly. To run only what a change affects (and its dependants), add `--affected`. Packages that an affected package depends on are built first, because Turborepo's `build` task depends on `^build`:

```bash
pnpm exec turbo run build lint typecheck test --affected
```

## Pull request checks

Every pull request to `main` runs the `Pull request` workflow: lint, typecheck and tests, limited to affected packages and with Turborepo's cache restored between runs.

Pull requests that touch `infra/` also run the `Infrastructure` workflow, which checks the Terraform and posts a Dev plan. Merging them applies Dev.

## How the page works

The page runs inside claude.ai and uses two runtime capabilities:

- **`mcp`** (Google Sheets connector, tools `get_values`, `update_values`, `append_values`): it watches each tab and writes changes back with the viewer's own Google sign-in.
- **`sample`**: it asks Claude for suggestion cards, using the viewer's own Claude usage.

It has three views:

- **Discover:** pick a crowd and vote on suggestion cards one at a time.
  - 👍 adds the song to Songs as *Wishlist* for that crowd.
  - ⏭ skips it for now (it can come back after a week).
  - 👎 asks *not my song* (never suggested again) or *wrong crowd* (choose another crowd or create a new one).
  - After a vote you can tap one optional reason.
  - Each card has Listen links (YouTube, Spotify) and a **Learn** button that shows chords and lesson links.
- **Library:** set a song's status, edit its crowds, save your own chords and lesson links, and log practice sessions.
- **Setlist:** build an ordered set from songs at *Comfortable* or above, with total run time and copy-to-clipboard. Setlists are kept in the browser (localStorage), not in the sheet.

The header shows points, the day streak, today's count, and a meter per crowd (ready songs against the crowd's goal).

### Suggestions

Each request sends Claude:
- the crowd's name and description
- the library (title, artist, status, crowds)
- a practice summary for each song (latest rating, confidence, focus area, total minutes, last note)
- the last 200 votes, with reasons
- a fixed taste profile

The crowd's taste comes first, and `taste_match` marks songs that also fit the player's taste. Songs already in the library, songs voted *not my song*, songs voted *wrong crowd* for this crowd, and songs skipped for this crowd in the last 7 days are never suggested.

### Points and streak

Points are worked out from the Events and Practice tabs every time the page draws, so no score is stored anywhere.

| Action | Points |
|---|---|
| Vote (⏭ or 👎) | 1 |
| 👍 | 2 |
| Each step up in status | 5 |
| Reaching Performance-Ready | 20 (plus 5 for each extra step) |
| Practice session | 1 per 5 minutes, up to 6 |

The streak counts consecutive days with at least one event or practice session.

## Sheet layout

Every tab has one header row. The page finds columns by their header names.

### Songs

| Column | Notes |
|---|---|
| `song_id` | Permanent ID, never reused. New songs get the highest ID plus one. |
| `title`, `artist`, `genre` | |
| `length` | Text, `m:ss` |
| `difficulty` | 1–10 |
| `status` | Wishlist, Struggling, Learning, Comfortable, Solid or Performance-Ready. Comfortable and above count as ready. |
| `crowds` | Comma-separated crowd names |
| `chords_url`, `lesson_url` | Links you picked. Blank means the page uses Ultimate Guitar and YouTube search links. |
| `vocal_ease` | Optional, 1–5 |
| `source` | `original` or `suggested` |
| `added_at` | Text, `YYYY-MM-DD` |

### Crowds

`crowd_id` · `name` · `description` (sent to Claude) · `color` (hex) · `ready_goal` · `active` (TRUE/FALSE)

### Events

`event_id` · `timestamp` (ISO, UTC) · `type` · `song_id` · `title` · `artist` · `crowd` · `value` · `note`

| `type` | `value` | `note` |
|---|---|---|
| `vote` | `up`, `skip`, `down_not_mine` or `down_wrong_crowd` | optional reason |
| `status_change` | new status | `from: <old status>` |
| `crowd_added` | crowd name | |

### Practice

`date` · `song_id` · `song` · `minutes` · `tempo_bpm` · `focus_area` · `goal` · `self_rating` (1–10) · `confidence` · `notes`

### Lists

Values for the dropdowns: `status`, `focus_area`, `confidence`, `genre`, `vote_reason`.

## Writing to the sheet

Both Sheets write tools parse input the way the Sheets UI does, so the page puts an apostrophe in front of every text value (for example `'4:18`). That keeps lengths, dates and timestamps stored as text.

## Publishing

Edit `packages/artifact/crowd-setlists.html`, then publish it to the artifact URL above with the same capabilities:

```json
{"mcp": {"servers": [{"server": "Google Sheets", "tools": ["get_values", "update_values", "append_values"]}]}, "sample": {}}
```

## Later

- 30-second previews played right on the card, from Apple's iTunes Search API
- Popularity data from Spotify, Last.fm or Ultimate Guitar
- Badges
- Saving setlists to the sheet
- A standalone app that imports these tabs as they are
