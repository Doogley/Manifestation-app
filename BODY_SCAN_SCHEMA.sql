-- ═══════════════════════════════════════════════════════════════════
-- BODY_SCAN_SCHEMA.sql — persists Body Scan session notes for Already Mine
-- Run once in the Supabase SQL Editor. Safe to re-run (idempotent).
--
-- Body Scan completion counts/streaks already live on profiles
-- (body_scan_count, last_body_scan_date). This table adds the actual
-- written notes from each session, previously held only in an in-memory
-- array (bodyScanSessions in index.html) that was lost on reload.
--
-- One row per completed session; sections is a JSON array of
-- {title, note} — mirrors the shape completeScan() already builds
-- client-side, so no reshaping is needed on write.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS body_scan_sessions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  session_date date not null,
  sections jsonb not null,
  created_at timestamptz default now()
);

ALTER TABLE body_scan_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own body scan sessions" ON body_scan_sessions;
CREATE POLICY "Users can view own body scan sessions" ON body_scan_sessions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own body scan sessions" ON body_scan_sessions;
CREATE POLICY "Users can insert own body scan sessions" ON body_scan_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own body scan sessions" ON body_scan_sessions;
CREATE POLICY "Users can delete own body scan sessions" ON body_scan_sessions
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS body_scan_sessions_user_date_idx
  ON body_scan_sessions (user_id, session_date);
