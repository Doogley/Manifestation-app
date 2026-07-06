# Apple Reviewer Demo Account Setup

Apple requires a working demo account so the App Review team can test the full app,
including paid/premium features, without making a purchase. Complete ALL steps below
**before** submitting the build in App Store Connect.

---

## 1. Create the reviewer account

- [ ] Sign up in the app (or via Supabase Auth) with a dedicated reviewer email:

  ```
  Email:    review@alreadymine.app   (or similar dedicated address you control)
  Password: <choose a strong password and record it — you'll paste it into Review Notes>
  ```

- Use an address you actually control in case Apple's review triggers a
  confirmation email or password reset.
- Complete onboarding once yourself so the account lands on the main app screen,
  not a half-finished onboarding flow.

## 2. Grant the account premium access (`is_paid_member = true`)

The reviewer must see the paid experience without buying anything. Set the flag
manually in Supabase.

- [ ] Find the reviewer's user ID: Supabase Dashboard → **Authentication → Users** →
  copy the `id` (UUID) for `review@alreadymine.app`.
- [ ] Open **SQL Editor** in the Supabase dashboard and run:

  ```sql
  UPDATE profiles SET is_paid_member = true WHERE id = '<reviewer_user_id>';
  ```

  (Replace `<reviewer_user_id>` with the UUID copied above.)

> **Why this must be done via the Supabase dashboard:** the
> `protect_privileged_profile_columns` trigger (see `SECURITY_FIXES.sql`) raises an
> exception if any client role (`authenticated` / `anon`) tries to change
> `is_paid_member`. Only `service_role` may modify it — and the dashboard SQL Editor
> runs with elevated privileges, so this is the supported path. Do **not** try to
> flip the flag from the app or from a client API call; it will fail by design.

- [ ] Verify in the app: log in as the reviewer and confirm premium features are
  unlocked and no paywall appears where it shouldn't.

## 3. Pre-populate the account with content

An empty account makes the app look broken or unfinished. Before submitting:

- [ ] Add **several journal entries** (spread over a few days if possible, so lists,
  streaks, and history views have real data).
- [ ] Add **a few intentions** in various states (active, completed) so the reviewer
  sees the full lifecycle.
- [ ] Set a display name / avatar so profile areas aren't blank.
- [ ] Walk through every main tab as the reviewer and confirm nothing is empty or
  in an error state.

## 4. App Store Connect — "App Review Information" (Review Notes)

In App Store Connect → your app → the version being submitted →
**App Review Information**:

- [ ] Check **"Sign-in required"** and enter:

  ```
  Username: review@alreadymine.app
  Password: <the password from step 1>
  ```

- [ ] In the **Notes** field, paste something like:

  ```
  Demo account (credentials above) is pre-configured with an active premium
  membership, so all paid features are unlocked — no purchase is needed to
  review them.

  The account is pre-populated with sample journal entries and intentions so
  you can see the full experience immediately after login.

  Premium is normally unlocked via an auto-renewing subscription (handled by
  RevenueCat / StoreKit). To test the purchase flow itself, use a sandbox
  Apple ID; the paywall appears for any non-premium account.

  No special hardware, location, or configuration is required.
  ```

- [ ] Add a contact phone number and email in the same section (Apple sometimes
  calls or emails during review).

## 5. Final pre-submission checklist

- [ ] Reviewer account exists and can log in with the exact credentials in Review Notes.
- [ ] `is_paid_member = true` confirmed (premium visible in-app).
- [ ] Journal entries + intentions populated.
- [ ] Credentials in App Store Connect match exactly (watch for trailing spaces).
- [ ] Log out of the reviewer account on your own devices so session state doesn't
      interfere, and don't change the password after submitting.
