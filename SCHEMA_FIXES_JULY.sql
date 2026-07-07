-- ============================================================================
-- Already Mine — missing profile columns (July 2026 journey audit).
-- Run in Supabase Dashboard → SQL Editor. Safe to run more than once.
--
-- Verified against the live database on 2026-07-07: these columns do NOT
-- exist, and the client already writes two of them.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CRITICAL — foundation_days_count is missing.
--
-- toggleHabitComplete() updates { foundation_days_count, last_foundation_date }
-- in ONE statement; because the column doesn't exist the whole update fails,
-- so: (a) the Foundations day-count badges (7/30/90/180 days) can never be
-- earned, and (b) last_foundation_date never persists either — which was the
-- entire point of AUDIT_FIXES.sql item 1.
-- ----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists foundation_days_count integer not null default 0;

-- ----------------------------------------------------------------------------
-- 2. journal_entry_count is missing.
--
-- saveJournal() writes it after every new entry (the write currently 400s on
-- every save — harmless but noisy). Badge logic counts journal_entries rows
-- directly, so this column is informational; adding it stops the failing
-- write and makes SECURITY_FIXES.sql installable (see note below).
-- ----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists journal_entry_count integer not null default 0;

-- Backfill from actual entries so it doesn't start at 0 for existing users.
update public.profiles p
set journal_entry_count = coalesce(j.n, 0)
from (select user_id, count(*)::int as n from public.journal_entries group by user_id) j
where j.user_id = p.id;

-- ----------------------------------------------------------------------------
-- 3. IMPORTANT NOTE about SECURITY_FIXES.sql (still pending).
--
-- Its trigger function references new.foundation_days_count and
-- new.journal_entry_count. If that trigger were installed BEFORE these columns
-- exist, EVERY profile update would error at runtime ("record new has no field
-- ..."). Run this file first. Also remember the already-noted conflict: the
-- trigger's counter block will reject the client's direct writes to cinders
-- and the *_count columns — keep only the is_paid_member check, or move
-- counter updates server-side, before enabling it.
-- ----------------------------------------------------------------------------
