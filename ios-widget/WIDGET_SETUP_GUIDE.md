# Already Mine — iOS Widget Setup Guide

Everything needed to add the home-screen widget on the Mac. All the code in
this folder is written and reviewed — this guide is the Xcode wiring, which
can't be done from Windows. Do this **after** the main `MAC_SESSION_GUIDE.md`
steps 0–3 (project cloned, `npx cap add ios` run, signing configured).

**What's in this folder:**

| File | Goes into | Purpose |
|---|---|---|
| `AlreadyMineWidget.swift` | Widget extension target | All three widget layouts + timeline provider |
| `AlreadyMineWidgetBundle.swift` | Widget extension target | `@main` entry point for the extension |
| `Models.swift` | **Both** targets | Shared keys + `WidgetData` (App Group UserDefaults) |
| `WidgetBridgePlugin.swift` | App target | Capacitor plugin: JS → shared UserDefaults → widget reload |
| `MainViewController.swift` | App target | Registers the plugin with the Capacitor bridge |

**Already wired on the web side (nothing to do):** `capacitor-init.js`
defines `window.AMWidget.sync()` and re-syncs on foreground; `index.html`
calls it on every home build and affirmation reveal. Before the daily
reveal, the widget shows an invitation line ("Today's affirmation is waiting
to be revealed.") so the in-app ritual isn't spoiled.

**Widgets the user will see in the gallery:**
- **Daily Affirmation** — small (✦, affirmation, brand) and medium (streak + flame on the left, affirmation on the right)
- **Affirmation Card** — medium, affirmation centered with its category

---

## 1. Add the widget extension target

1. Open the workspace: `npx cap open ios`
2. **File → New → Target…**
3. Pick **Widget Extension** (iOS tab), click **Next**.
4. Configure:
   - **Product Name:** `AlreadyMineWidget` (exactly — the bundle id becomes `app.alreadymine.AlreadyMineWidget`)
   - **Team:** your team
   - **UNCHECK "Include Configuration App Intent"** — these widgets are not user-configurable; the code uses `StaticConfiguration`.
   - Embed in Application: **App**
5. Click **Finish**. When Xcode asks *"Activate AlreadyMineWidget scheme?"* → **Activate**.
6. Xcode generated template files inside the new `AlreadyMineWidget/` group. **Delete** the generated `AlreadyMineWidget.swift` and `AlreadyMineWidgetBundle.swift` (Move to Trash). Keep the generated `Info.plist` and `Assets.xcassets`.

## 2. Set the deployment target

Select the project → **AlreadyMineWidget** target → **General → Minimum
Deployments** → set **iOS 17.0**. (The code uses `containerBackground(for:
.widget)` and `#Preview(as:)`, which are iOS 17 APIs. The main App target
can stay at whatever minimum it already has — the widget simply won't be
offered on older devices.)

## 3. Configure the App Group (both targets)

The app and the widget are separate processes; the App Group is the shared
storage they both read/write.

1. Select the **App** target → **Signing & Capabilities** → **+ Capability** → **App Groups**.
2. Click **+** under App Groups and enter exactly: `group.app.alreadymine`
3. Repeat for the **AlreadyMineWidget** target: + Capability → App Groups → tick the **same** `group.app.alreadymine`.
4. With automatic signing, Xcode registers the group and regenerates the provisioning profiles for both bundle ids. If it errors, register the group manually at developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → App Groups, then retry.

> The string must match `WidgetKeys.appGroup` in `Models.swift` character-for-character. A typo here is the #1 cause of a widget that only ever shows "Open Already Mine to reveal today's affirmation."

## 4. Add the Swift files

Drag the files from this `ios-widget/` folder into the Xcode project
navigator (or **File → Add Files to "App"…**), with **"Copy items if
needed"** checked, and set **Target Membership** per file (select the file →
File Inspector, right panel):

| File | App | AlreadyMineWidget |
|---|:-:|:-:|
| `AlreadyMineWidget.swift` | ☐ | ☑ |
| `AlreadyMineWidgetBundle.swift` | ☐ | ☑ |
| `Models.swift` | ☑ | ☑ |
| `WidgetBridgePlugin.swift` | ☑ | ☐ |
| `MainViewController.swift` | ☑ | ☐ |

Suggested placement: widget files into the `AlreadyMineWidget` group,
app-target files into the `App` group. Placement is cosmetic; **target
membership is what matters.**

## 5. Point the storyboard at MainViewController

Capacitor 6+ doesn't auto-discover local plugins — `MainViewController`
registers `WidgetBridgePlugin` when the bridge loads, but the storyboard has
to instantiate it:

1. Open **App → App → Base.lproj → Main.storyboard**.
2. Select the only view controller (currently `CAPBridgeViewController`).
3. Identity Inspector (⌥⌘3) → **Custom Class → Class:** `MainViewController`, **Module:** `App`.

## 6. Build check + widget preview

1. Scheme **App**, any simulator → **⌘B**. Fixes both-target compile issues early.
2. Scheme **AlreadyMineWidget** → **⌘B**.
3. Open `AlreadyMineWidget.swift` in the editor → **Editor → Canvas** (⌥⌘↩). The `#Preview` macros at the bottom render all three layouts against placeholder data — no device needed. Check: dark `#1a1610` background, gold ✦ and accents, cream serif affirmation text.

## 7. Test on a real device

Widget timelines are unreliable in the simulator — verify on hardware.

1. Plug in the iPhone, select it as the run destination, scheme **App**, **⌘R** (both the app and the embedded extension install together).
2. In the app: sign in and reveal today's affirmation (this triggers `AMWidget.sync()` → `WidgetBridgePlugin` → App Group write → `reloadAllTimelines`).
3. Home screen → long-press empty space → **+** (top-left) → search **Already Mine** → add the small widget, and swipe to add both medium ones.
4. Verify:
   - Widget shows today's actual affirmation, streak, and category (not the placeholder text).
   - Tap the widget → the app opens.
   - Reveal tomorrow's affirmation in the app → widget updates within seconds.
   - Before the daily reveal, the widget shows the "waiting to be revealed" line.
5. Debugging the extension: run the **AlreadyMineWidget** scheme directly (Xcode asks which app to attach to — pick the home screen widget). `print()` output from the provider lands in the Xcode console. To inspect what the app actually wrote, add a temporary print of `UserDefaults(suiteName: "group.app.alreadymine")?.dictionaryRepresentation()`.

## 8. Common pitfalls and fixes

| Symptom | Cause → Fix |
|---|---|
| Widget always shows "Open Already Mine to reveal…" | App Group missing on one target, or name mismatch. Check both targets' Signing & Capabilities against `WidgetKeys.appGroup`. Also confirm the app ran at least once *after* the group was added. |
| `Cannot find 'WidgetKeys' in scope` building the App | `Models.swift` isn't a member of the App target. Fix target membership (step 4). |
| `Cannot find 'WidgetKeys' in scope` building the extension | Same file missing from the AlreadyMineWidget target. |
| `'main' attribute can only apply to one type in a module` | The Xcode template's `AlreadyMineWidgetBundle.swift` wasn't deleted — there are two `@main`s. Delete the template one. |
| JS logs `[AMWidget] sync failed: "WidgetBridge" plugin is not implemented on ios` | Plugin never registered: storyboard still instantiates `CAPBridgeViewController` (step 5), or `MainViewController.swift` / `WidgetBridgePlugin.swift` missing from the App target. |
| `Please adopt containerBackground API` shown inside the widget | Only happens if the `.containerBackground` lines get removed — every layout in `AlreadyMineWidget.swift` already sets it. Don't replace them with plain `.background`. |
| Widget renders but never refreshes after reveals | `reloadAllTimelines()` runs in the plugin — confirm the reveal actually reached native (Safari → Develop → device → inspect the webview, check for `[AMWidget]` errors). Note iOS **throttles** background refreshes; app-triggered reloads while the app is foreground are honored quickly. |
| Widget missing from the gallery | Reboot the device or wait a minute after first install — the gallery index lags. Confirm deployment target ≤ device iOS version. |
| Signing errors on the extension | The extension has its own bundle id (`app.alreadymine.AlreadyMineWidget`) and needs its own profile — with automatic signing, select the team on the extension target too. |
| `npx cap sync` afterwards | Safe. Capacitor only regenerates the `App` group's web assets and Pods; it does not touch the extension target. **Don't** add any Capacitor pods to the widget target — the widget deliberately has zero dependencies. |
| Preview canvas crashes | Previews need the scheme's run destination to be an iOS 17+ simulator. Also make sure the canvas is previewing the widget extension scheme, not App. |

## 9. Data contract (reference)

Written by `WidgetBridgePlugin.setWidgetData` on every app open, foreground
resume, and affirmation reveal; read by `WidgetData.load()`:

| Key (`group.app.alreadymine`) | Type | Example |
|---|---|---|
| `todayAffirmation` | String | "Everything I need is already flowing gently toward me." |
| `todayCategory` | String | "Abundance" |
| `streakCount` | Int | 7 |
| `currentRank` | String | "Ember" |
| `unlockedCount` | Int | 12 |
| `lastSync` | Double (unix ts) | debugging only |

`currentRank` and `unlockedCount` aren't rendered by the current layouts —
they're synced so a future lock-screen widget or a rank-focused layout can
ship without touching the app-side bridge again.
