//
//  AlreadyMineWidget.swift
//  AlreadyMineWidget extension
//
//  Home-screen widgets for Already Mine (iOS 17+):
//    • AlreadyMineWidget          — small (affirmation) + medium (streak | affirmation)
//    • AlreadyMineAffirmationWidget — medium variant with the affirmation centered
//
//  Data arrives via the shared App Group suite (see Models.swift); the app
//  forces a refresh by calling WidgetCenter.reloadAllTimelines() from
//  WidgetBridgePlugin whenever it writes new values. Between app opens, the
//  timeline asks iOS to refresh roughly every 2 hours.
//
//  TARGET MEMBERSHIP: widget extension target only.
//

import WidgetKit
import SwiftUI

// MARK: - Theme (matches the web app's CSS variables)

extension Color {
    /// #1a1610 — app background
    static let amBackground = Color(red: 26 / 255, green: 22 / 255, blue: 16 / 255)
    /// #c9a96e — gold accent
    static let amGold = Color(red: 201 / 255, green: 169 / 255, blue: 110 / 255)
    /// #f5f0e8 — cream text
    static let amCream = Color(red: 245 / 255, green: 240 / 255, blue: 232 / 255)
}

/// Tapping any widget opens the app. The scheme is not currently handled in
/// JS, which is fine — iOS launches the app either way; the URL is there so
/// index.html can deep-link to the reveal card later via the App plugin's
/// `appUrlOpen` event.
private let widgetTapURL = URL(string: "alreadymine://today")

// MARK: - Timeline

struct AffirmationEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct AffirmationProvider: TimelineProvider {
    func placeholder(in context: Context) -> AffirmationEntry {
        AffirmationEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (AffirmationEntry) -> Void) {
        // The gallery preview should always look good, so it uses placeholder
        // data; a real snapshot uses whatever the app last synced.
        let data: WidgetData = context.isPreview ? .placeholder : .load()
        completion(AffirmationEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AffirmationEntry>) -> Void) {
        let entry = AffirmationEntry(date: .now, data: .load())
        // One entry, re-requested every ~2 hours. iOS treats this as a hint
        // and batches refreshes; the app-triggered reloadAllTimelines() is
        // what makes reveals show up immediately.
        let refresh = Calendar.current.date(byAdding: .hour, value: 2, to: .now)
            ?? .now.addingTimeInterval(2 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Shared pieces

/// "ALREADY MINE" footer used by every layout.
struct BrandFooter: View {
    var symbol = false

    var body: some View {
        Text(symbol ? "✦ ALREADY MINE" : "ALREADY MINE")
            .font(.system(size: 8, weight: .medium))
            .tracking(2)
            .foregroundStyle(Color.amGold.opacity(0.55))
            .lineLimit(1)
    }
}

// MARK: - Small: symbol, affirmation, brand

struct SmallAffirmationView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("✦")
                .font(.system(size: 15))
                .foregroundStyle(Color.amGold)

            Spacer(minLength: 8)

            Text(data.todayAffirmation)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(Color.amCream)
                .lineSpacing(2)
                .lineLimit(5)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            BrandFooter()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color.amBackground, for: .widget)
        .widgetURL(widgetTapURL)
    }
}

// MARK: - Medium: streak on the left, affirmation on the right

struct MediumStreakView: View {
    let data: WidgetData

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                VStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.amGold)
                    Text("\(data.streakCount)")
                        .font(.system(size: 34, weight: .light, design: .serif))
                        .foregroundStyle(Color.amCream)
                        .contentTransition(.numericText())
                    Text("DAY STREAK")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(1.6)
                        .foregroundStyle(Color.amGold.opacity(0.75))
                }
                .frame(width: 84)

                Rectangle()
                    .fill(Color.amGold.opacity(0.18))
                    .frame(width: 1)
                    .padding(.vertical, 4)

                Text(data.todayAffirmation)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Color.amCream)
                    .lineSpacing(2)
                    .lineLimit(4)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)

            BrandFooter()
        }
        .containerBackground(Color.amBackground, for: .widget)
        .widgetURL(widgetTapURL)
    }
}

// MARK: - Medium variant 2: affirmation centered, category below

struct MediumAffirmationView: View {
    let data: WidgetData

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            Text(data.todayAffirmation)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Color.amCream)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .lineLimit(3)
                .minimumScaleFactor(0.8)

            Text(data.todayCategory.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(2)
                .foregroundStyle(Color.amGold)
                .lineLimit(1)

            Spacer(minLength: 0)

            BrandFooter(symbol: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color.amBackground, for: .widget)
        .widgetURL(widgetTapURL)
    }
}

// MARK: - Widget definitions

/// Small + medium "Daily Affirmation" widget (medium shows the streak panel).
struct AlreadyMineWidget: Widget {
    let kind = "AlreadyMineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AffirmationProvider()) { entry in
            AlreadyMineWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Affirmation")
        .description("Today's affirmation — with your streak on the medium size.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AlreadyMineWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: AffirmationProvider.Entry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumStreakView(data: entry.data)
        default:
            SmallAffirmationView(data: entry.data)
        }
    }
}

/// Medium-only variant: the affirmation itself, centered like a card.
struct AlreadyMineAffirmationWidget: Widget {
    let kind = "AlreadyMineAffirmationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AffirmationProvider()) { entry in
            MediumAffirmationView(data: entry.data)
        }
        .configurationDisplayName("Affirmation Card")
        .description("Today's affirmation, centered, with its category.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    AlreadyMineWidget()
} timeline: {
    AffirmationEntry(date: .now, data: .placeholder)
    AffirmationEntry(date: .now, data: .empty)
}

#Preview("Medium · Streak", as: .systemMedium) {
    AlreadyMineWidget()
} timeline: {
    AffirmationEntry(date: .now, data: .placeholder)
}

#Preview("Medium · Card", as: .systemMedium) {
    AlreadyMineAffirmationWidget()
} timeline: {
    AffirmationEntry(date: .now, data: .placeholder)
}
