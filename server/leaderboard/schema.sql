-- PAYDIRT daily leaderboard schema (Cloudflare D1).
-- One row per (date, handle); worker.js upserts keep the better result.
CREATE TABLE IF NOT EXISTS scores (
  date TEXT NOT NULL,
  handle TEXT NOT NULL,
  haul INTEGER NOT NULL,
  depth INTEGER NOT NULL,
  survived INTEGER NOT NULL,
  created TEXT NOT NULL,
  PRIMARY KEY (date, handle)
);

CREATE INDEX IF NOT EXISTS idx_scores_board ON scores (date, haul DESC, depth DESC);
