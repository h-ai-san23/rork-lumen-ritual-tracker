//
//  ProgressTabView.swift
//  LUMEN
//
//  Photo timeline, trend charts, and premium Insights.
//

import SwiftUI
import SwiftData
import Charts
import PhotosUI

struct ProgressTabView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(RitualEngine.self) private var engine
    let user: UserState

    @Query(sort: \DayLog.date) private var logs: [DayLog]
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPaywall = false
    @State private var compareMode = false

    private var photoLogs: [DayLog] {
        let visible = user.isPremium ? logs : logs.filter { $0.date.timeIntervalSinceNow > -30 * 24 * 3600 }
        return visible.filter { $0.photoData != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LumenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        photoSection
                        chartsSection
                        insightsSection
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                }
            }
            .navigationTitle("Progress")
            .sheet(isPresented: $showPaywall) { PaywallView(user: user) }
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        let log = engine.today
                        log.photoData = data
                        try? context.save()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            }
        }
        .tint(palette.accent)
    }

    // MARK: - Photos

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                SectionHeader(title: "Photo Timeline")
                Spacer()
                if photoLogs.count >= 2 {
                    Button { withAnimation { compareMode.toggle() } } label: {
                        Pill(text: "Compare", systemImage: "rectangle.split.2x1", selected: compareMode)
                    }
                }
            }

            if compareMode, photoLogs.count >= 2 {
                comparison
            } else if photoLogs.isEmpty {
                photoEmpty
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.m) {
                        addPhotoTile
                        ForEach(photoLogs.reversed()) { log in
                            photoCard(log)
                        }
                    }
                }
                .scrollClipDisabled()
            }
            if !user.isPremium {
                Text("Free plan keeps the last 30 days. Lumira Gold keeps your full history.")
                    .font(.ui(12)).foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var addPhotoTile: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            VStack(spacing: Space.s) {
                Image(systemName: "plus").font(.system(size: 24)).foregroundStyle(palette.accent)
                Text("Weekly\nselfie").font(.ui(12, .medium)).multilineTextAlignment(.center)
                    .foregroundStyle(palette.textSecondary)
            }
            .frame(width: 130, height: 180)
            .background(palette.surface1)
            .clipShape(.rect(cornerRadius: Radius.tile))
            .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [5])))
        }
    }

    private func photoCard(_ log: DayLog) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let data = log.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 130, height: 180).clipped()
            }
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
            Text(log.date, format: .dateTime.month().day())
                .font(.ui(12, .semibold)).foregroundStyle(.white).padding(Space.s)
        }
        .frame(width: 130, height: 180)
        .clipShape(.rect(cornerRadius: Radius.tile))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(palette.hairline, lineWidth: 1))
    }

    private var comparison: some View {
        HStack(spacing: Space.m) {
            comparePane("Before", log: photoLogs.first)
            comparePane("After", log: photoLogs.last)
        }
    }

    private func comparePane(_ label: String, log: DayLog?) -> some View {
        VStack(spacing: Space.s) {
            ZStack {
                if let data = log?.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill)
                } else { palette.surface2 }
            }
            .frame(height: 220).frame(maxWidth: .infinity).clipped()
            .clipShape(.rect(cornerRadius: Radius.tile))
            Text("\(label) · \(log?.date.formatted(.dateTime.month().day()) ?? "")")
                .font(.ui(12, .medium)).foregroundStyle(palette.textSecondary)
        }
    }

    private var photoEmpty: some View {
        HStack(spacing: Space.m) {
            addPhotoTile
            VStack(alignment: .leading, spacing: 4) {
                Text("Track your glow")
                    .font(.serif(18, .medium)).foregroundStyle(palette.textPrimary)
                Text("Add a weekly selfie to see your progress side by side over time.")
                    .font(.ui(14)).foregroundStyle(palette.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Charts

    private var recent: [DayLog] { Array(logs.suffix(14)) }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            SectionHeader(title: "Trends")
            trendChart(title: "Skin self-rating", unit: "/10", color: palette.accent) { $0.skinRating.map(Double.init) }
            trendChart(title: "Sleep", unit: "hrs", color: palette.sage) { $0.sleepHours }
            consistencyChart
        }
    }

    private func trendChart(title: String, unit: String, color: Color, value: @escaping (DayLog) -> Double?) -> some View {
        LumenCard {
            VStack(alignment: .leading, spacing: Space.m) {
                Text(title).font(.ui(15, .semibold)).foregroundStyle(palette.textPrimary)
                Chart(recent) { log in
                    if let v = value(log) {
                        LineMark(x: .value("Day", log.date, unit: .day), y: .value(unit, v))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(color)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        AreaMark(x: .value("Day", log.date, unit: .day), y: .value(unit, v))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                    }
                }
                .frame(height: 120)
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 4)) { _ in AxisValueLabel(format: .dateTime.day()) } }
                .chartYAxis { AxisMarks(position: .leading) }
            }
        }
    }

    private var consistencyChart: some View {
        LumenCard {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("Consistency").font(.ui(15, .semibold)).foregroundStyle(palette.textPrimary)
                Chart(recent) { log in
                    BarMark(
                        x: .value("Day", log.date, unit: .day),
                        y: .value("%", engine.completion(for: log) * 100)
                    )
                    .foregroundStyle(palette.gold)
                    .cornerRadius(4)
                }
                .frame(height: 120)
                .chartYScale(domain: 0...100)
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 4)) { _ in AxisValueLabel(format: .dateTime.day()) } }
            }
        }
    }

    // MARK: - Insights (premium)

    private var insightsSection: some View {
        let insights = Insights.compute(logs: logs, engine: engine, user: user)
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                SectionHeader(title: "Insights")
                if !user.isPremium { LockBadge() }
            }
            ZStack {
                VStack(spacing: Space.m) {
                    ForEach(insights) { insight in
                        insightCard(insight)
                    }
                }
                .blur(radius: user.isPremium ? 0 : 7)
                .disabled(!user.isPremium)

                if !user.isPremium {
                    VStack(spacing: Space.m) {
                        Text("Unlock correlations between your\nhabits and your results.")
                            .font(.ui(15, .medium)).foregroundStyle(palette.textPrimary)
                            .multilineTextAlignment(.center)
                        GoldButton(title: "Unlock with Lumira Gold") { showPaywall = true }
                            .frame(maxWidth: 280)
                    }
                    .padding(Space.l)
                }
            }
        }
    }

    private func insightCard(_ insight: Insight) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: insight.symbol).foregroundStyle(palette.accent).font(.ui(16))
            Text(insight.text).font(.ui(15)).foregroundStyle(palette.textPrimary).lineSpacing(3)
            Spacer()
        }
        .padding(Space.l)
        .background(palette.surface1)
        .clipShape(.rect(cornerRadius: Radius.tile))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(palette.hairline, lineWidth: 1))
    }
}

/// A single insight, computed live from the user's real day logs.
struct Insight: Identifiable {
    let id = UUID()
    let symbol: String
    let text: String
}

/// Correlation and consistency insights computed entirely from the user's
/// actual day logs — no static placeholders. When there isn't enough logged
/// data yet, it returns an honest "still learning" message instead of guessing.
enum Insights {
    @MainActor
    static func compute(logs: [DayLog], engine: RitualEngine, user: UserState) -> [Insight] {
        var out: [Insight] = []
        let recent = Array(logs.suffix(30))

        // 1. Consistency over the logged window.
        let active = recent.filter { engine.completion(for: $0) > 0 }
        if active.count >= 3 {
            let avg = active.map { engine.completion(for: $0) }.reduce(0, +) / Double(active.count)
            let pct = Int((avg * 100).rounded())
            out.append(Insight(
                symbol: "chart.bar.fill",
                text: "You complete about \(pct)% of your ritual steps on the days you show up. \(pct >= 80 ? "That's exceptional consistency." : "Small daily wins compound fast.")"))
        }

        // 2. Sleep ↔ skin correlation, only with enough paired data.
        let rated = recent.filter { $0.skinRating != nil && $0.sleepHours != nil }
        if rated.count >= 5 {
            let goodSleep = rated.filter { ($0.sleepHours ?? 0) >= 7 }
            let poorSleep = rated.filter { ($0.sleepHours ?? 0) < 7 }
            if goodSleep.count >= 2, poorSleep.count >= 2 {
                let a = Double(goodSleep.compactMap { $0.skinRating }.reduce(0, +)) / Double(goodSleep.count)
                let b = Double(poorSleep.compactMap { $0.skinRating }.reduce(0, +)) / Double(poorSleep.count)
                if a - b >= 0.4 {
                    out.append(Insight(
                        symbol: "moon.stars.fill",
                        text: "Your skin self-rating averages \(fmt(a))/10 after 7+ hours of sleep versus \(fmt(b))/10 on shorter nights."))
                } else if b - a >= 0.4 {
                    out.append(Insight(
                        symbol: "moon.stars.fill",
                        text: "Sleep and skin aren't tracking together yet — other factors may be driving your ratings."))
                }
            }
        }

        // 3. Skin rating trend across the window.
        let skinSeries = recent.compactMap { $0.skinRating }
        if skinSeries.count >= 6 {
            let half = skinSeries.count / 2
            let early = Double(skinSeries.prefix(half).reduce(0, +)) / Double(half)
            let late = Double(skinSeries.suffix(half).reduce(0, +)) / Double(half)
            if late - early >= 0.5 {
                out.append(Insight(
                    symbol: "arrow.up.right",
                    text: "Your skin self-rating is trending up — \(fmt(early)) → \(fmt(late))/10 across this period."))
            } else if early - late >= 0.5 {
                out.append(Insight(
                    symbol: "arrow.down.right",
                    text: "Your skin rating dipped from \(fmt(early)) to \(fmt(late))/10 lately — worth revisiting your routine."))
            }
        }

        // 4. Morning vs evening adherence.
        let amLogs = recent.filter { engine.completion(for: .am, log: $0) >= 1 }.count
        let pmLogs = recent.filter { engine.completion(for: .pm, log: $0) >= 1 }.count
        if amLogs + pmLogs >= 4, abs(amLogs - pmLogs) >= 2 {
            if amLogs > pmLogs {
                out.append(Insight(
                    symbol: "sun.max.fill",
                    text: "You finish your morning ritual more often than your evening one (\(amLogs) vs \(pmLogs) days). Protect that wind-down."))
            } else {
                out.append(Insight(
                    symbol: "moon.fill",
                    text: "Your evenings are stronger than your mornings (\(pmLogs) vs \(amLogs) days). A simpler AM step could close the gap."))
            }
        }

        // 5. Perfect days + streak.
        let perfect = recent.filter { engine.completion(for: $0) >= 1 }.count
        if perfect > 0 {
            out.append(Insight(
                symbol: "checkmark.seal.fill",
                text: "You hit a complete ritual on \(perfect) of your last \(recent.count) logged days. Best streak: \(user.bestStreak) days."))
        }

        // Honest empty state when there's not enough to analyse.
        if out.isEmpty {
            out.append(Insight(
                symbol: "hourglass",
                text: "Lumira is still learning your patterns. Log a few more days — rate your skin and sleep — and personalised insights will appear here."))
        }
        return out
    }

    private static func fmt(_ v: Double) -> String {
        String(format: "%.1f", v)
    }
}
