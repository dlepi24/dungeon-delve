// PAYDIRT daily leaderboard — a Cloudflare Worker over D1.
//
// Two endpoints, no accounts, no PII:
//   POST /submit          {date, handle, haul, depth, survived}
//   GET  /board?date=YYYY-MM-DD&limit=50
//
// One row per (date, handle); a resubmit only ever IMPROVES a row (the game
// sends one ranked run a day, so this only matters for retries and clock
// skew). Anti-cheat is plausibility clamps and nothing more, by design: this
// is a friendly board for a daily seed, not an anti-tamper system, and the
// game states that stance in leaderboard.gd too.
//
// Deploys from GitHub Actions (.github/workflows/deploy-leaderboard.yml) —
// see README.md for the one-time setup.

const HANDLE_RE = /^[A-Za-z0-9_-]{1,12}$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const MAX_HAUL = 1_000_000;
const MAX_DEPTH = 99;
const MAX_LIMIT = 100;
// Accept a submission dated within a day of the server's UTC today: covers
// a run finishing just past midnight and offline retries from yesterday,
// while refusing backfill of arbitrary history.
const DATE_SLACK_DAYS = 1;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}

function dateWithinSlack(date) {
  const submitted = Date.parse(date + "T00:00:00Z");
  if (Number.isNaN(submitted)) return false;
  const today = new Date();
  const todayUtc = Date.parse(today.toISOString().slice(0, 10) + "T00:00:00Z");
  const days = Math.abs(todayUtc - submitted) / 86_400_000;
  return days <= DATE_SLACK_DAYS;
}

async function submit(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "bad json" }, 400);
  }
  const date = String(body.date ?? "");
  const handle = String(body.handle ?? "");
  const haul = Math.trunc(Number(body.haul ?? -1));
  const depth = Math.trunc(Number(body.depth ?? -1));
  const survived = body.survived ? 1 : 0;
  if (!DATE_RE.test(date) || !dateWithinSlack(date)) return json({ error: "bad date" }, 400);
  if (!HANDLE_RE.test(handle)) return json({ error: "bad handle" }, 400);
  if (haul < 0 || haul > MAX_HAUL) return json({ error: "bad haul" }, 400);
  if (depth < 1 || depth > MAX_DEPTH) return json({ error: "bad depth" }, 400);

  // Keep the better result: haul first, depth breaks ties — the same ordering
  // the board reads with, so an upsert can never worsen a rank.
  await env.DB.prepare(
    `INSERT INTO scores (date, handle, haul, depth, survived, created)
     VALUES (?1, ?2, ?3, ?4, ?5, datetime('now'))
     ON CONFLICT(date, handle) DO UPDATE SET
       haul = excluded.haul, depth = excluded.depth,
       survived = excluded.survived, created = excluded.created
     WHERE excluded.haul > scores.haul
        OR (excluded.haul = scores.haul AND excluded.depth > scores.depth)`
  ).bind(date, handle, haul, depth, survived).run();
  return json({ ok: true });
}

async function board(url, env) {
  const date = url.searchParams.get("date") ?? "";
  if (!DATE_RE.test(date)) return json({ error: "bad date" }, 400);
  const limit = Math.min(MAX_LIMIT, Math.max(1, Number(url.searchParams.get("limit") ?? 50) | 0));
  const rows = await env.DB.prepare(
    `SELECT handle, haul, depth, survived FROM scores
     WHERE date = ?1
     ORDER BY haul DESC, depth DESC, created ASC
     LIMIT ?2`
  ).bind(date, limit).all();
  const total = await env.DB.prepare(
    `SELECT COUNT(*) AS n FROM scores WHERE date = ?1`
  ).bind(date).first();
  return json({
    rows: rows.results.map((r) => ({ ...r, survived: !!r.survived })),
    total: total?.n ?? rows.results.length,
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });
    if (request.method === "POST" && url.pathname === "/submit") return submit(request, env);
    if (request.method === "GET" && url.pathname === "/board") return board(url, env);
    return json({ error: "not found" }, 404);
  },
};
