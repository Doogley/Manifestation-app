-- ============================================================================
-- Already Mine — schema changes for the June 2026 functional-audit fixes.
-- Run this in the Supabase Dashboard → SQL Editor (safe to run more than once).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Persist the once-per-day gate for foundation completions.
--
-- The client previously kept lastFoundationDate only in memory, so reloading
-- the page let foundation_days_count be incremented multiple times per day
-- (inflating the Foundations badges). The client now reads and writes this
-- column on every completed foundation day.
-- ----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists last_foundation_date date;

-- ----------------------------------------------------------------------------
-- 2. Persist which streak milestones each habit has already paid out.
--
-- Milestone cinders (7/21/30-day streaks) were re-awarded every time a habit
-- was unchecked and re-checked at a milestone streak. The client now records
-- awarded milestones per habit (e.g. [7, 21]) and each milestone pays out
-- once per habit ever.
-- ----------------------------------------------------------------------------
alter table public.habits
  add column if not exists milestones_awarded jsonb not null default '[]'::jsonb;
