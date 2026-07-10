-- ═══════════════════════════════════════════════════════════════════
-- ANALYTICS_QUERIES.sql — saved queries for Already Mine analytics
-- Run any block in the Supabase SQL Editor (it runs as service role,
-- which bypasses RLS). Requires ANALYTICS_SCHEMA.sql.
-- Timestamps are UTC; "day" below means UTC day.
-- ═══════════════════════════════════════════════════════════════════


-- ── 1a. Daily active users, last 7 days ─────────────────────────────
SELECT created_at::date AS day,
       count(DISTINCT user_id) AS active_users
FROM analytics_events
WHERE event_name = 'app_open'
  AND created_at >= now() - interval '7 days'
GROUP BY 1
ORDER BY 1 DESC;

-- ── 1b. Daily active users, last 30 days ────────────────────────────
SELECT created_at::date AS day,
       count(DISTINCT user_id) AS active_users
FROM analytics_events
WHERE event_name = 'app_open'
  AND created_at >= now() - interval '30 days'
GROUP BY 1
ORDER BY 1 DESC;

-- ── 1c. Rolled-up actives: DAU today / WAU / MAU ────────────────────
SELECT
  count(DISTINCT user_id) FILTER (WHERE created_at >= date_trunc('day', now()))      AS dau_today,
  count(DISTINCT user_id) FILTER (WHERE created_at >= now() - interval '7 days')  AS wau_7d,
  count(DISTINCT user_id) FILTER (WHERE created_at >= now() - interval '30 days') AS mau_30d
FROM analytics_events
WHERE event_name = 'app_open';


-- ── 2. Signup → onboarding completion rate ──────────────────────────
SELECT
  count(DISTINCT user_id) FILTER (WHERE event_name = 'signup_complete')     AS signups,
  count(DISTINCT user_id) FILTER (WHERE event_name = 'onboarding_complete') AS completed_onboarding,
  round(100.0 * count(DISTINCT user_id) FILTER (WHERE event_name = 'onboarding_complete')
      / nullif(count(DISTINCT user_id) FILTER (WHERE event_name = 'signup_complete'), 0), 1)
    AS completion_pct
FROM analytics_events;


-- ── 3. Day 2 / 7 / 30 retention ─────────────────────────────────────
-- Denominator counts only users who signed up long enough ago to have
-- had the chance to return (otherwise young cohorts drag the rate down).
WITH signups AS (
  SELECT user_id, min(created_at) AS signed_up
  FROM analytics_events
  WHERE event_name = 'signup_complete'
  GROUP BY 1
),
milestones(name, event_name, min_age) AS (
  VALUES ('day 2',  'day_2_return',  interval '1 day'),
         ('day 7',  'day_7_return',  interval '6 days'),
         ('day 30', 'day_30_return', interval '29 days')
)
SELECT m.name AS milestone,
       count(s.user_id) AS eligible_users,
       count(r.user_id) AS returned,
       round(100.0 * count(r.user_id) / nullif(count(s.user_id), 0), 1) AS retention_pct
FROM milestones m
CROSS JOIN signups s
LEFT JOIN LATERAL (
  SELECT 1 AS user_id
  FROM analytics_events e
  WHERE e.user_id = s.user_id AND e.event_name = m.event_name
  LIMIT 1
) r ON true
WHERE s.signed_up <= now() - m.min_age
GROUP BY m.name
ORDER BY min(m.min_age);


-- ── 4. Drop-off map: % of users who ever did each event ─────────────
-- Read top-to-bottom as a funnel: big gaps between adjacent lifecycle
-- events show where users fall out of the product.
WITH total AS (
  SELECT count(DISTINCT user_id) AS n FROM analytics_events
)
SELECT event_name,
       count(DISTINCT user_id) AS users_did_it,
       round(100.0 * count(DISTINCT user_id) / (SELECT n FROM total), 1) AS pct_of_all_users
FROM analytics_events
GROUP BY event_name
ORDER BY users_did_it DESC;


-- ── 5. Upgrade funnel ────────────────────────────────────────────────
SELECT
  count(DISTINCT user_id) FILTER (WHERE event_name = 'upgrade_tapped')    AS tapped_upgrade,
  count(DISTINCT user_id) FILTER (WHERE event_name = 'upgrade_completed') AS completed_upgrade,
  round(100.0 * count(DISTINCT user_id) FILTER (WHERE event_name = 'upgrade_completed')
      / nullif(count(DISTINCT user_id) FILTER (WHERE event_name = 'upgrade_tapped'), 0), 1)
    AS conversion_pct
FROM analytics_events;


-- ── 6. Share rate: % of active users who have ever shared ───────────
SELECT
  count(DISTINCT user_id) FILTER (WHERE event_name = 'share_card') AS sharers,
  count(DISTINCT user_id) FILTER (WHERE event_name = 'app_open')   AS active_users,
  round(100.0 * count(DISTINCT user_id) FILTER (WHERE event_name = 'share_card')
      / nullif(count(DISTINCT user_id) FILTER (WHERE event_name = 'app_open'), 0), 1)
    AS share_rate_pct
FROM analytics_events;


-- ── 7. Top earned badges ─────────────────────────────────────────────
SELECT event_data->>'badge' AS badge_id,
       count(*)             AS times_earned,
       count(DISTINCT user_id) AS unique_users
FROM analytics_events
WHERE event_name = 'badge_earned'
GROUP BY 1
ORDER BY times_earned DESC
LIMIT 25;


-- ── 8. Average journal entries per user per week ─────────────────────
-- Averaged over each user's active journaling weeks.
WITH per_user_week AS (
  SELECT user_id,
         date_trunc('week', created_at) AS week,
         count(*) AS entries
  FROM analytics_events
  WHERE event_name = 'journal_saved'
  GROUP BY 1, 2
)
SELECT round(avg(entries), 2) AS avg_entries_per_user_per_week,
       count(DISTINCT user_id) AS journaling_users
FROM per_user_week;
