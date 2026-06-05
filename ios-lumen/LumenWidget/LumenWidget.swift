//
//  LumenWidget.swift
//  LumenWidget
//
//  Home Screen / Lock Screen widget. It is self-contained: it derives the
//  time-appropriate ritual (morning vs evening) from the clock, so it stays
//  meaningful without needing access to the app's private data.
//

import WidgetKit
import SwiftUI

// MARK: - Shared palette

enum LumenWidgetColors {
    static let bg = Color(red: 0.051, green: 0.051, blue: 0.059)
    static let surface = Color(red: 0.086, green: 0.086, blue: 0.102)
    static let gold = Color(red: 0.788, green: 0.659, blue: 0.416)
    static let goldLight = Color(red: 0.851, green: 0.722, blue: 0.467)
    static let text = Color(red: 0.961, green: 0.953, blue: 0.933)
    static let secondary = Color(red: 0.659, green: 0.635, blue: 0.604)

    static let goldGradient = LinearGradient(
        colors: [goldLight, gold],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Timeline

nonisolated struct RitualEntry: TimelineEntry {
    let date: Date
    let isMorning: Bool

    var ritualName: String { isMorning ? "Morning Ritual" : "Evening Ritual" }
    var ritualSymbol: String { isMorning ? "sun.max.fill" : "moon.fill" }
    var prompt: String { isMorning ? "Begin your day, refined." : "Wind down, restore." }
}

nonisolated struct RitualProvider: TimelineProvider {
    func placeholder(in context: Context) -> RitualEntry {
        RitualEntry(date: .now, isMorning: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (RitualEntry) -> Void) {
        completion(entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RitualEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let current = entry(for: now)

        // Refresh at the next AM/PM boundary (2pm switches to evening, midnight back to morning).
        let hour = calendar.component(.hour, from: now)
        let nextBoundaryHour = hour < 14 ? 14 : 24
        let next = calendar.date(bySettingHour: nextBoundaryHour % 24, minute: 0, second: 0, of: now)
            ?? now.addingTimeInterval(3600)
        let refresh = nextBoundaryHour == 24
            ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? next
            : next

        completion(Timeline(entries: [current], policy: .after(refresh)))
    }

    private func entry(for date: Date) -> RitualEntry {
        let hour = Calendar.current.component(.hour, from: date)
        return RitualEntry(date: date, isMorning: hour < 14)
    }
}

// MARK: - Views

struct LumenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: RitualEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: entry.ritualSymbol)
                .font(.title2)
                .foregroundStyle(.primary)
        case .accessoryInline:
            Label(entry.ritualName, systemImage: entry.ritualSymbol)
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: entry.ritualSymbol).font(.title3)
                VStack(alignment: .leading) {
                    Text(entry.ritualName).font(.headline)
                    Text(entry.prompt).font(.caption2)
                }
            }
        default:
            fullWidget
        }
    }

    private var fullWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("LUMEN")
                    .font(.system(.caption, design: .serif).weight(.semibold))
                    .tracking(3)
                    .foregroundStyle(LumenWidgetColors.gold)
                Spacer()
                Image(systemName: entry.ritualSymbol)
                    .font(.title3)
                    .foregroundStyle(LumenWidgetColors.goldGradient)
            }
            Spacer()
            Text(entry.ritualName)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(LumenWidgetColors.text)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
            Text(entry.prompt)
                .font(.footnote)
                .foregroundStyle(LumenWidgetColors.secondary)
                .padding(.top, 2)
            Spacer()
            HStack(spacing: 6) {
                Text("Start ritual")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LumenWidgetColors.bg)
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(LumenWidgetColors.bg)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(LumenWidgetColors.goldGradient))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct LumenWidget: Widget {
    let kind: String = "LumenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RitualProvider()) { entry in
            LumenWidgetView(entry: entry)
                .widgetURL(URL(string: "lumen://ritual"))
                .containerBackground(for: .widget) {
                    LumenWidgetColors.bg
                }
        }
        .configurationDisplayName("Daily Ritual")
        .description("Your morning and evening self-care ritual at a glance.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}
