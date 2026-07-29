# PAYDIRT daily leaderboard

A ~100-line Cloudflare Worker + D1 database. Free tier covers this game's
traffic by orders of magnitude. The game treats it as strictly optional: with
no URL configured the whole system is dormant, and an unreachable board is one
quiet line on the records screen.

## One-time setup (Dustin, ~10 minutes)

1. **Create the database** (needs `npm i -g wrangler`, then `wrangler login`):

   ```bash
   cd server/leaderboard
   wrangler d1 create paydirt-leaderboard
   ```

   Paste the printed `database_id` into `wrangler.toml`, then load the schema:

   ```bash
   wrangler d1 execute paydirt-leaderboard --remote --file schema.sql
   ```

2. **Wire up CI** so pushes deploy it (leaning into the existing GH Actions
   setup): in the GitHub repo settings add two Actions secrets —
   - `CLOUDFLARE_API_TOKEN` (dash.cloudflare.com → My Profile → API Tokens →
     "Edit Cloudflare Workers" template, plus D1 edit permission)
   - `CLOUDFLARE_ACCOUNT_ID` (dashboard sidebar)

   From then on `.github/workflows/deploy-leaderboard.yml` deploys on every
   push that touches `server/leaderboard/`.

3. **Point the game at it**: the first deploy prints the worker URL
   (`https://paydirt-leaderboard.<account>.workers.dev`). Paste it into
   `SERVICE_URL` in `src/autoload/leaderboard.gd` and commit. That commit is
   the launch switch — records screen grows the day-board section, ranked
   dailies start submitting.

## API

- `POST /submit` — `{date, handle, haul, depth, survived}`. One row per
  (date, handle); resubmits only ever improve a row. Dates must be within a
  day of the server's UTC today.
- `GET /board?date=YYYY-MM-DD&limit=50` — `{rows: [{handle, haul, depth,
  survived}], total}`, ranked by haul then depth.

## Stance

Anti-cheat is plausibility clamps only (caps on haul/depth, handle and date
validation). A friendly board for a daily seed, not an anti-tamper system —
if it ever gets griefed, the next steps are a submit token baked per-build
and a report/hide list, both server-side only.
