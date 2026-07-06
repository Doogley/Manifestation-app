# App Store Privacy Labels — App Store Connect Checklist

Step-by-step guide for filling out **App Store Connect → Your App → App Privacy**.
Answers below reflect what the app actually collects (Supabase account + content,
mood check-ins, usage counters) as of July 2026. Re-review this file whenever a new
SDK or data type is added.

---

## Step 1 — Get started

- [ ] App Store Connect → **Apps** → Already Mine → **App Privacy** (left sidebar).
- [ ] Privacy Policy URL: enter your hosted privacy policy URL (required before
      you can publish labels).
- [ ] Click **Get Started** and answer **"Do you or your third-party partners
      collect data from this app?"** → **Yes, we collect data from this app**.

## Step 2 — Select the data types collected

On the "What type of data do you collect?" screens, check **exactly** these:

### Contact Info
- [x] **Email Address** — required for account creation / login (Supabase Auth).

### Health & Fitness
- [x] **Health** — mood check-ins.

### User Content
- [x] **Photos or Videos** — optional avatar upload.
- [x] **Other User Content** — journal entries, intentions, mantras.

### Identifiers
- [x] **User ID** — Supabase user UUID (also used as the RevenueCat app user ID).

### Usage Data
- [x] **Product Interaction** — streaks, cinders, badges, feature usage counters.

> ⚠️ **Decision point — Purchases:** the list above assumes you declare Purchases as
> NOT collected because Apple processes payments. However, since the app uses the
> **RevenueCat SDK**, RevenueCat's own guidance is to also declare
> **Purchases → Purchase History** (collected, linked to user, app functionality,
> no tracking). Check RevenueCat's current App Privacy disclosure docs before
> submitting; if in doubt, declaring Purchase History is the safer choice.

Leave every other data type **unchecked** — see Step 4.

## Step 3 — Configure each collected data type

For **every** data type checked in Step 2, App Store Connect asks three questions.
Answer identically for all of them:

| Question | Answer |
|---|---|
| Why is this data collected? (purpose) | **App Functionality** only |
| Is this data linked to the user's identity? | **Yes** (all data is tied to the Supabase account) |
| Is this data used for tracking? | **No** |

Per-type checklist:

- [ ] Email Address → App Functionality / Linked / No tracking
- [ ] Health → App Functionality / Linked / No tracking
- [ ] Photos or Videos → App Functionality / Linked / No tracking
- [ ] Other User Content → App Functionality / Linked / No tracking
- [ ] User ID → App Functionality / Linked / No tracking
- [ ] Product Interaction → App Functionality / Linked / No tracking

Do **not** select any of the other purposes (Analytics, Advertising, Product
Personalization, Other) — nothing in the app uses them today. If you later add an
analytics SDK, come back and update this.

## Step 4 — Data types NOT collected (leave unchecked)

Confirm all of these remain **unchecked** — the app does not collect them:

- [ ] Location (precise or coarse) — not collected
- [ ] Browsing History — not collected
- [ ] Purchases — not collected (Apple processes payments; **but see the
      RevenueCat decision point in Step 2**)
- [ ] Financial Info — not collected (no payment details ever touch the app)
- [ ] Contacts — not collected
- [ ] Search History — not collected
- [ ] Diagnostics (crash data, performance data) — not collected (no crash/analytics SDK)
- [ ] Sensitive Info — not collected
- [ ] Also leave unchecked: Physical Address, Phone Number, Name*, Fitness,
      Emails or Messages, Audio Data, Gameplay Content, Customer Support,
      Advertising Data, Device ID, Purchase History*, Environment Scanning,
      Hands/Head movement

  \* unless you decide otherwise per the notes above (display name is
  user-chosen and cosmetic; Purchase History depends on the RevenueCat decision).

## Step 5 — Third-party sharing (Anthropic monthly summaries)

There is no separate "third-party sharing" toggle in App Store Connect — sharing
with service providers is covered by the collection declarations above. But
document it correctly elsewhere:

- **What happens:** journal entry data is sent to **Anthropic** (Claude API) to
  generate the user's **monthly summary** — that is the only third-party sharing
  of user content.
- **Consent:** this only happens **with the user's consent**; it is not used by
  Anthropic for advertising or tracking, so it does **not** change the
  "Used for tracking: No" answers.
- [ ] Make sure your **privacy policy** explicitly discloses: journal content may
      be processed by Anthropic to generate monthly summaries, only with consent,
      and is not used for advertising.
- [ ] Supabase (hosting/database) and RevenueCat (subscription management) are
      service providers acting on your behalf — no extra label needed beyond the
      data types already declared, but list them in the privacy policy too.

## Step 6 — Tracking question

- [ ] When asked **"Is this data used for tracking?"** for any type: **No**.
- [ ] The app must NOT show an App Tracking Transparency prompt (it doesn't track),
      and no ATT usage-description string is needed in Info.plist.

## Step 7 — Review and publish

- [ ] On the App Privacy summary screen, verify it shows only:
      **Email Address, Health, Photos or Videos, Other User Content, User ID,
      Product Interaction** — all under "Data Linked to You", none under
      "Data Used to Track You".
- [ ] Click **Publish**. Labels can be edited any time without a new build, but
      they must be accurate at submission.

---

## Quick reference table

| Data type | Collected? | Purpose | Linked to user | Tracking |
|---|---|---|---|---|
| Email Address | Yes | App Functionality | Yes | No |
| Health (mood check-ins) | Yes | App Functionality | Yes | No |
| Photos (avatar) | Yes (optional) | App Functionality | Yes | No |
| Other User Content (journal, intentions, mantras) | Yes | App Functionality | Yes | No |
| User ID | Yes | App Functionality | Yes | No |
| Product Interaction (streaks, cinders, badges) | Yes | App Functionality | Yes | No |
| Location | No | — | — | — |
| Browsing History | No | — | — | — |
| Purchases | No (see RevenueCat note) | — | — | — |
| Financial Info | No | — | — | — |
| Contacts | No | — | — | — |
| Search History | No | — | — | — |
| Diagnostics | No | — | — | — |
| Sensitive Info | No | — | — | — |
