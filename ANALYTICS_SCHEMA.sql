-- ═══════════════════════════════════════════════════════════════════
-- ANALYTICS_SCHEMA.sql — first-party event tracking for Already Mine
-- Run once in the Supabase SQL Editor. Safe to re-run (idempotent).
--
-- The app batches events client-side (trackEvent in index.html) and
-- inserts them in groups; users can only insert their own rows and can
-- never read anyone's. Reading is done by you via the SQL Editor /
-- service role (see ANALYTICS_QUERIES.sql).
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS analytics_events (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  event_name text not null,
  event_data jsonb default '{}',
  created_at timestamptz default now()
);

ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own events" ON analytics_events;
CREATE POLICY "Users can insert own events" ON analytics_events
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Belt-and-braces: the service role bypasses RLS anyway, but an explicit
-- SELECT policy documents that no ordinary user role can ever read events.
DROP POLICY IF EXISTS "Service role can read all" ON analytics_events;
CREATE POLICY "Service role can read all" ON analytics_events
  FOR SELECT USING (auth.role() = 'service_role');

-- Indexes for the queries in ANALYTICS_QUERIES.sql (event + time range
-- scans, and per-user funnels). Kept to two so writes stay cheap.
CREATE INDEX IF NOT EXISTS analytics_events_name_time_idx
  ON analytics_events (event_name, created_at);
CREATE INDEX IF NOT EXISTS analytics_events_user_idx
  ON analytics_events (user_id, event_name);

-- ── Event catalogue (all fired from index.html) ─────────────────────
-- signup_complete       account created
-- onboarding_complete   finished onboarding questions (first goToHome)
-- affirmation_revealed  daily unlock            { day }
-- journal_saved         NEW journal entry (not edits)
-- intention_set         intention added
-- intention_received    intention marked received
-- foundation_added      habit/foundation created
-- foundation_completed  all daily foundations done (once per day)
-- body_scan_complete    finished the body scan flow
-- mantra_set            weekly mantra set (once per week)
-- upgrade_tapped        tapped subscribe        { platform }
-- upgrade_completed     purchase succeeded      { plan }
-- share_card            shared an affirmation card
-- badge_earned          badge unlocked          { badge }
-- rank_up               new cinders rank        { rank }
-- app_open              once per user per local calendar day
-- day_2_return          app opened on 2nd day after signup
-- day_7_return          app opened on 7th day after signup
-- day_30_return         app opened on 30th day after signup
