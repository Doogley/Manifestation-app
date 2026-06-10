-- ============================================================================
-- Already Mine — server-side security fixes
-- Run this in the Supabase Dashboard → SQL Editor.
-- These cannot be fixed in the client; they are database/RLS/storage settings.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. CRITICAL — stop users granting themselves premium.
--
-- Today any logged-in user can call the REST API directly and flip their own
-- profiles.is_paid_member to true (verified during the audit). RLS lets a user
-- update their own row, and there is no column-level protection, so the paid
-- gate is trivially bypassable.
--
-- Fix: a trigger that blocks the authenticated/anon roles from changing
-- entitlement / counter columns. Only the service_role (your server, app-store
-- webhook, or dashboard) may change them. Add/remove columns as needed.
-- ----------------------------------------------------------------------------
create or replace function public.protect_privileged_profile_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- service_role bypasses all checks (use it for receipt validation / webhooks)
  if auth.role() = 'service_role' then
    return new;
  end if;

  if new.is_paid_member is distinct from old.is_paid_member then
    raise exception 'is_paid_member cannot be modified by clients';
  end if;

  -- Optional but recommended: freeze server-owned counters so badges/stats
  -- cannot be forged from the client. Comment out any the client must write.
  if new.intentions_received_count is distinct from old.intentions_received_count
     or new.body_scan_count        is distinct from old.body_scan_count
     or new.mood_checkin_count     is distinct from old.mood_checkin_count
     or new.mantra_week_count      is distinct from old.mantra_week_count
     or new.foundation_days_count  is distinct from old.foundation_days_count
     or new.journal_entry_count    is distinct from old.journal_entry_count
     or new.cinders                is distinct from old.cinders then
    raise exception 'server-owned counter columns cannot be modified by clients';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_protect_privileged_profile_columns on public.profiles;
create trigger trg_protect_privileged_profile_columns
  before update on public.profiles
  for each row execute function public.protect_privileged_profile_columns();

-- NOTE: the client currently writes several of those counter columns directly
-- (cinders, *_count). If you enable the counter checks above, those writes will
-- start failing. Either:
--   (a) move counter updates server-side (recommended), or
--   (b) keep only the `is_paid_member` check and drop the counter block.
-- The is_paid_member check is the one that must ship.


-- ----------------------------------------------------------------------------
-- 2. HIGH — lock down the `avatars` storage bucket.
--
-- The bucket is public AND listable. Anonymous callers can list every user's
-- folder, which enumerates real user UUIDs (verified during the audit).
--
-- Option A (simplest): make the bucket non-listable but keep public reads of
-- individual files (the app uses getPublicUrl). This stops enumeration.
-- ----------------------------------------------------------------------------
-- Remove any policy that grants SELECT (list) on the avatars bucket to anon.
-- Inspect first:
--   select * from storage.policies where bucket_id = 'avatars';
-- Then drop overly-broad list policies. Replace with: anon may read a file only
-- if it knows the exact path (no listing), authenticated users manage their own.

-- Make the bucket private (recommended). The app must then use createSignedUrl
-- instead of getPublicUrl for avatars.
-- update storage.buckets set public = false where id = 'avatars';

-- Restrict writes to each user's own folder (path = "<uid>/..."):
drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Do NOT create a broad SELECT-to-anon policy on storage.objects for this
-- bucket; that is what enables enumeration. Keep reads to public-file fetch or
-- signed URLs only.


-- ----------------------------------------------------------------------------
-- 3. Clean up audit test rows (fake example.com accounts created while testing).
-- ----------------------------------------------------------------------------
delete from public.profiles
where id in (
  '1590ffd2-c765-478b-b4ce-417501e8492e',
  '48bb6526-aac4-4699-9ee9-c505b3ae8720'
);
-- Also delete the matching auth users (Dashboard → Authentication → Users,
-- search "audit_probe" / "audit_victim"), since deleting the profile row does
-- not remove the auth.users entry.


-- ----------------------------------------------------------------------------
-- 4. MEDIUM — require email confirmation.
--
-- Auth settings show mailer_autoconfirm = true, so anyone can sign up with an
-- email they do not own and the account is instantly active. This allows
-- spoofed-identity and throwaway accounts.
--
-- Fix in Dashboard → Authentication → Providers → Email:
--   turn OFF "Confirm email" auto-confirm (require email confirmation).
-- (No SQL; it is a project auth setting.)
-- ----------------------------------------------------------------------------
