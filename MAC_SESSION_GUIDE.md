# Mac Session Guide — Already Mine iOS Build

Everything that must happen on a Mac to take Already Mine from this repo to
the App Store. All the Windows-side work (Capacitor setup, plugins,
RevenueCat wiring, config) is already done and committed — this guide picks
up from there.

**What's already in place:**
- `capacitor.config.json` — app id `app.alreadymine`, name "Already Mine", dark theme, plugin config
- All plugins installed: status-bar, splash-screen, keyboard, haptics, app, push-notifications, local-notifications, share, filesystem, RevenueCat (share + filesystem power the affirmation share-card feature — `npx cap sync ios` pulls in their pods, no extra setup)
- `capacitor-init.js` — native shell setup (status bar, keyboard, splash, back button)
- `revenuecat-handler.js` — purchase/restore flows (needs the real API key, step 6)
- `index.html` — platform detection, native subscribe flow, Restore Purchases button (auto-hidden on web)
- `stage-www.mjs` — copies the web files into `www/` automatically on every `npx cap copy`/`sync`

---

## 0. Prerequisites (one-time Mac setup)

| Requirement | Notes |
|---|---|
| Xcode 16+ | Mac App Store. Launch once and accept the license. |
| Xcode Command Line Tools | `xcode-select --install` |
| Node 20+ | `brew install node` (or nvm) |
| CocoaPods | `sudo gem install cocoapods` — Capacitor's default iOS dependency manager |
| Apple Developer Program | $99/yr, enrolled at developer.apple.com — required for App Store submission |

Sign into Xcode with your Apple ID: **Xcode → Settings → Accounts → + → Apple ID**.

## 1. Get the project onto the Mac

```bash
git clone <your-repo-url> already-mine
cd already-mine
npm install
```

## 2. Add the iOS platform

```bash
npx cap add ios
npx cap sync ios
```

`cap add ios` generates the `ios/` folder (native Xcode project). `cap sync`
stages the web files into `www/` (via the pre-copy hook), copies them into
the iOS project, and installs the native pods for every plugin.

**Commit the `ios/` folder** — it's part of the project from now on:

```bash
git add ios && git commit -m "add iOS native project"
```

> After any future change to `index.html`, `capacitor-init.js`,
> `revenuecat-handler.js`, or `capacitor.config.json`, re-run
> `npx cap sync ios` before building.

## 3. Open in Xcode and configure signing

```bash
npx cap open ios
```

In Xcode:
1. Select the **App** project in the left sidebar → **App** target → **Signing & Capabilities** tab.
2. Check **Automatically manage signing**.
3. **Team**: select your Apple Developer team.
4. **Bundle Identifier**: confirm it is `app.alreadymine`.
5. Xcode will create the provisioning profile automatically.

Also on the **General** tab:
- **Display Name**: `Already Mine`
- **Version**: `1.0.0`, **Build**: `1` (bump Build for every upload)
- **Minimum Deployments**: iOS 14.0 is Capacitor 8's floor; leave the default.
- **Device Orientation**: Portrait only (uncheck landscape) — the app is a portrait experience.

## 4. App icon and splash screen

Easiest path — the official generator. Create two source images first:

- `resources/icon.png` — 1024×1024, no transparency, no rounded corners (Apple rejects alpha channels in app icons)
- `resources/splash.png` — 2732×2732, the `#1a1610` background with the logo centered in the middle ~1200px (gets cropped to every device size)

```bash
mkdir -p resources
# put icon.png and splash.png in resources/, then:
npm install -D @capacitor/assets
npx capacitor-assets generate --ios
npx cap sync ios
```

This fills in `ios/App/App/Assets.xcassets` (icon + splash) automatically.
Verify in Xcode: **App → Assets.xcassets → AppIcon** shows the icon.

Splash behavior (2s display, auto-hide, `#1a1610` background, no spinner) is
already configured in `capacitor.config.json`.

## 5. First build and test

1. In Xcode's toolbar pick a simulator (e.g. **iPhone 16 Pro**) and press **⌘R**.
2. The app should boot: splash → dark status bar → the web app served from `capacitor://localhost`.

Smoke-test checklist:
- [ ] Sign up / log in (Supabase network calls work)
- [ ] Daily affirmation unlocks; journal entry saves
- [ ] Keyboard pushes content up instead of covering inputs
- [ ] Status bar text is light over the dark theme
- [ ] Upgrade screen shows the **Restore Purchases** button (native-only UI — proves the Capacitor bridge is live)
- [ ] Monthly summary works for a paid/test account (calls `https://alreadymine.app/api/summary`)

To test on a real iPhone: plug it in, select it as the run target, ⌘R. First
run requires trusting the developer cert on the phone (**Settings → General →
VPN & Device Management**).

## 6. RevenueCat + App Store subscriptions

### 6a. Create the subscriptions in App Store Connect

appstoreconnect.apple.com → **My Apps → + → New App** (if not created yet:
platform iOS, name "Already Mine", bundle ID `app.alreadymine`, SKU
`alreadymine`).

Then **App → Monetization → Subscriptions**:
1. Create a Subscription Group: `Already Mine Membership`.
2. Add two subscriptions inside it:
   | Reference name | Product ID | Duration | Price |
   |---|---|---|---|
   | Member Monthly | `am_member_monthly` | 1 month | $2.99 |
   | Member Annual | `am_member_annual` | 1 year | $21.49 |
3. Each needs a localized display name, description, and a review screenshot before submission.

> The product IDs above are already hardcoded in `revenuecat-handler.js`
> (`RC_PRODUCTS`). If you choose different IDs, update that file.

Also complete **Business → Agreements, Tax, and Banking** — paid apps can't
be submitted until the Paid Applications agreement is active.

### 6b. Configure RevenueCat

app.revenuecat.com:
1. Create project **Already Mine** → add an **App Store** app, bundle ID `app.alreadymine`.
2. Upload the **In-App Purchase Key** (App Store Connect → Users and Access → Integrations → In-App Purchase → generate key) — RevenueCat needs it to validate receipts.
3. **Entitlements**: create one with identifier `member` (must match `RC_ENTITLEMENT_ID` in `revenuecat-handler.js`).
4. **Products**: import `am_member_monthly` and `am_member_annual`, attach both to the `member` entitlement.
5. **Offerings**: create a `default` offering with a Monthly package (`$rc_monthly` → `am_member_monthly`) and an Annual package (`$rc_annual` → `am_member_annual`).
6. Copy the **public Apple API key** (starts with `appl_`) from Project Settings → API Keys.

### 6c. Paste the API key

In `revenuecat-handler.js`, replace:

```js
var RC_API_KEY_IOS = 'REVENUECAT_IOS_API_KEY_PLACEHOLDER';
```

with the real `appl_...` key (it's a public key, safe to ship in the JS).
Then `npx cap sync ios` and rebuild.

### 6d. Test purchases in sandbox

1. App Store Connect → **Users and Access → Sandbox Testers** → create a sandbox Apple ID.
2. On a real device (simulator can't complete purchases), sign into the sandbox account: **Settings → App Store → Sandbox Account**.
3. Run the app, go to the upgrade screen, tap **Start My Member Journey** → the native Apple purchase sheet should appear with the sandbox price.
4. Complete the purchase → the app should show "Your library is now open" and `is_paid_member` should flip to `true` in the Supabase `profiles` table.
5. Delete + reinstall the app, log in, tap **Restore Purchases** → membership should come back.

### 6e. Keep Supabase in sync (important follow-up)

The app sets `is_paid_member = true` at purchase/restore time, but nothing
flips it back when a subscription **expires or is refunded**. Before or
shortly after launch, set up a **RevenueCat webhook** (Project Settings →
Integrations → Webhooks) pointing at a small server endpoint (Supabase Edge
Function or a Vercel `api/` function) that updates `profiles.is_paid_member`
on `EXPIRATION`, `CANCELLATION` (refund), and `RENEWAL` events. Until then,
a lapsed subscriber keeps web access.

## 7. Notifications

**Local daily reminders (active in v1):** `@capacitor/local-notifications`
is installed and wired up in `push-notifications.js`. It needs **no Xcode
capability, no APNs key, and no extra setup** — `npx cap sync ios` pulls in
the pod and it just works. The app only prompts for notification permission
when the user turns on the "Notifications" toggle in Profile → My
Preferences (Apple's preferred UX: prompt on user action, not at launch).

**Remote push (deferred — plugin installed, not active):**
`@capacitor/push-notifications` is installed for later. When you're ready:
1. Xcode → **Signing & Capabilities → + Capability → Push Notifications**.
2. Also add **Background Modes → Remote notifications**.
3. Create an APNs key at developer.apple.com → Keys.
4. Wire up registration in `capacitor-init.js`.

Skip the remote-push steps for v1 — do **not** add the Push Notifications
capability now. (Local notifications don't need it.)

## 8. Archive and upload

1. In Xcode, set the run destination to **Any iOS Device (arm64)**.
2. **Product → Archive**.
3. When the Organizer opens: **Distribute App → App Store Connect → Upload** (accept defaults for signing).
4. Wait ~15 min for the build to finish processing in App Store Connect (you'll get an email).

Optional but recommended: add the build to **TestFlight** first and use the
app for a day on your own phone before submitting.

## 9. App Store listing and submission

All the listing copy (description, subtitle, keywords, what's-new) is
already written in **`APPSTORE.md`** — paste from there.

In App Store Connect → your app → **1.0 Prepare for Submission**:

1. **Screenshots**: required for 6.9" (iPhone 16 Pro Max) and 6.5" displays. Take them in the simulator with **⌘S** (File → Save Screen). 3–5 screens: today/affirmation, journal, intentions, library, upgrade.
2. **Description / Keywords / Subtitle**: from `APPSTORE.md`.
3. **Support URL**: `https://alreadymine.app` (make sure a contact route exists). **Marketing URL**: `https://alreadymine.app`.
4. **Privacy Policy URL**: the app's privacy policy page.
5. **App Privacy** (nutrition labels): declare — Contact Info (email, account), User Content (journal entries, linked to user), Identifiers (user ID), Purchases. Data is **not** used for tracking.
6. **Age Rating**: complete the questionnaire (should land at 4+ or 12+).
7. **In-App Purchases**: attach both subscriptions to the version.
8. **App Review Information**: provide a **test account login** (email + password for a working account) — Apple will reject without one since the app requires sign-in. In the notes, mention: "Subscriptions are processed by RevenueCat/StoreKit. Restore Purchases is on the membership screen."
9. **Version Release**: choose manual or automatic release after approval.
10. **Add for Review → Submit to App Review.**

Review usually takes 1–3 days. Common first-submission rejections to
pre-empt:
- **Guideline 2.1** — broken login for the reviewer → double-check the test account.
- **Guideline 3.1.2** — subscription terms: the upgrade screen must show price, duration, and links to Terms of Use + Privacy Policy near the purchase button (the fine print already references them — make sure they're tappable links in the app).
- **Missing Restore Purchases** — already handled ✓.

## 10. After approval

- Switch RevenueCat from sandbox to production monitoring (happens automatically; check the first real purchases land).
- Set up the webhook from step 6e if not done.
- For every future update: bump **Build** number, `npx cap sync ios`, Archive, upload, submit.

---

## Quick reference — every command in order

```bash
# one-time
git clone <repo> && cd already-mine && npm install
npx cap add ios
npm install -D @capacitor/assets && npx capacitor-assets generate --ios

# every build cycle
npx cap sync ios     # stages www/ + copies into iOS project + pods
npx cap open ios     # open Xcode → ⌘R to run, Product → Archive to ship
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `pod install` fails during `cap add ios` | `sudo gem install cocoapods`, then `cd ios/App && pod install` |
| White screen on launch | `npx cap sync ios` was skipped — the `www/` copy is stale/missing |
| Supabase requests fail in-app | Check `server.allowNavigation` in `capacitor.config.json` includes `*.supabase.co` |
| Purchase sheet never appears | Products not "Ready to Submit" in ASC, or Paid Apps agreement not signed, or testing in simulator (use a device) |
| `Purchases` plugin undefined | Pods out of date — `npx cap sync ios`, clean build (⇧⌘K), rebuild |
| Monthly summary fails in-app | It calls `https://alreadymine.app/api/summary` — confirm the Vercel deployment is live |
