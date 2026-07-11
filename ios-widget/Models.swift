//
//  Models.swift
//  Already Mine
//
//  Shared data models for the home-screen widget.
//
//  ⚠️ TARGET MEMBERSHIP: this file must be a member of BOTH the app target
//  ("App") and the widget extension target ("AlreadyMineWidget"). The app
//  writes through WidgetKeys (via WidgetBridgePlugin); the widget reads
//  through WidgetData.load(). If they ever disagree on a key name the
//  widget silently shows stale/placeholder data, so both sides share this
//  single source of truth.
//

import Foundation

/// App Group container and UserDefaults keys shared by the app and widget.
enum WidgetKeys {
    /// Must match the App Group enabled on BOTH targets in
    /// Signing & Capabilities, and the suite name used by WidgetBridgePlugin.
    static let appGroup = "group.app.alreadymine"

    static let todayAffirmation = "todayAffirmation"
    static let todayCategory = "todayCategory"
    static let streakCount = "streakCount"
    static let currentRank = "currentRank"
    static let unlockedCount = "unlockedCount"
    /// Unix timestamp of the last successful sync from the app. Not shown in
    /// the UI — useful when debugging "why is my widget stale?".
    static let lastSync = "lastSync"
}

/// Snapshot of everything the widget can render. Loaded fresh on every
/// timeline refresh.
struct WidgetData {
    let todayAffirmation: String
    let todayCategory: String
    let streakCount: Int
    let currentRank: String
    let unlockedCount: Int

    /// Shown in the widget gallery and while the real data is loading.
    static let placeholder = WidgetData(
        todayAffirmation: "Everything I need is already making its way to me.",
        todayCategory: "Abundance",
        streakCount: 7,
        currentRank: "Ember",
        unlockedCount: 12
    )

    /// Shown when the app has never synced (fresh install, or the App Group
    /// is misconfigured). Deliberately an invitation rather than fake data.
    static let empty = WidgetData(
        todayAffirmation: "Open Already Mine to reveal today's affirmation.",
        todayCategory: "Daily Practice",
        streakCount: 0,
        currentRank: "Ember",
        unlockedCount: 0
    )

    /// Reads the latest values the app wrote to the shared App Group suite.
    static func load() -> WidgetData {
        guard let defaults = UserDefaults(suiteName: WidgetKeys.appGroup),
              let affirmation = defaults.string(forKey: WidgetKeys.todayAffirmation),
              !affirmation.isEmpty else {
            return .empty
        }
        return WidgetData(
            todayAffirmation: affirmation,
            todayCategory: defaults.string(forKey: WidgetKeys.todayCategory) ?? "",
            streakCount: defaults.integer(forKey: WidgetKeys.streakCount),
            currentRank: defaults.string(forKey: WidgetKeys.currentRank) ?? "Ember",
            unlockedCount: defaults.integer(forKey: WidgetKeys.unlockedCount)
        )
    }
}
