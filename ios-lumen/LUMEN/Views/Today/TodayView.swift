//
//  TodayView.swift
//  LUMEN
//
//  The home hero: greeting, Ritual Ring, Aura, streak chip, AM/PM cards.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.palette) private var palette
    @Environment(RitualEngine.self) private var engine
    let user: UserState

    @Query(sort: \RitualStep.order) private var steps: [RitualStep]
    @Query private var products: [Product]
    @State private var showPlayer = false

    private var log: DayLog { engine.today }
    private var completion: Double { engine.completion(for: log) }

    private func product(_ id: UUID?) -> Product? {
        guard let id else { return nil }
        return products.first { $0.id == id }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        ZStack {
            LumenBackground()
            ScrollView {
                VStack(spacing: Space.xl) {
                    header
                    ringSection
                    ritualCard(.am)
                    ritualCard(.pm)
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
            }

            VStack {
                Spacer()
                GoldButton(title: "Start ritual", systemImage: "play.fill") {
                    showPlayer = true
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.s)
                .background(
                    LinearGradient(colors: [palette.base.opacity(0), palette.base], startPoint: .top, endPoint: .bottom)
                        .frame(height: 120).allowsHitTesting(false), alignment: .bottom
                )
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            RitualPlayerView(user: user)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                    .font(.ui(13, .medium))
                    .foregroundStyle(palette.textSecondary)
                    .tracking(0.5)
                    .textCase(.uppercase)
                Text(greeting)
                    .font(.serif(30, .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .tracking(-0.5)
            }
            Spacer()
            streakChip
        }
        .padding(.top, Space.s)
    }

    private var streakChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.ui(13))
                .foregroundStyle(palette.gold)
            Text("\(user.streak)")
                .font(.ui(15, .bold))
                .foregroundStyle(palette.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(palette.surface1))
        .overlay(Capsule().strokeBorder(palette.hairline, lineWidth: 1))
        .modifier(MilestoneShimmer(active: [7, 30, 100, 365].contains(user.streak)))
    }

    private var ringSection: some View {
        ZStack {
            AuraOrb(intensity: completion)
                .frame(width: 260, height: 260)
                .opacity(0.9)
            RitualRing(progress: completion, size: 220)
            VStack(spacing: 4) {
                Text("\(Int(completion * 100))%")
                    .font(.serif(48, .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .shadow(color: palette.base.opacity(0.6), radius: 6)
                    .contentTransition(.numericText())
                    .animation(.spring, value: completion)
                Text(completion >= 1 ? "Complete" : "Today's ritual")
                    .font(.ui(13, .medium))
                    .foregroundStyle(palette.textSecondary)
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .shadow(color: palette.base.opacity(0.6), radius: 4)
            }
            .padding(28)
            .background(
                RadialGradient(
                    colors: [palette.base.opacity(0.55), palette.base.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 90
                )
                .blur(radius: 6)
                .allowsHitTesting(false)
            )
        }
        .frame(height: 280)
        .padding(.vertical, Space.s)
    }

    private func ritualCard(_ ritual: RitualTime) -> some View {
        let ritualSteps = steps.filter { $0.ritual == ritual }
        let done = ritualSteps.filter { log.isComplete($0) }.count
        return LumenCard {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
                    Image(systemName: ritual.symbol).foregroundStyle(palette.accent)
                    Text(ritual.title)
                        .font(.serif(20, .medium))
                        .foregroundStyle(palette.textPrimary)
                    Spacer()
                    Text("\(done)/\(ritualSteps.count)")
                        .font(.ui(14, .medium))
                        .foregroundStyle(palette.textSecondary)
                }
                if ritualSteps.isEmpty {
                    Text("No steps yet.")
                        .font(.ui(14))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.vertical, Space.s)
                } else {
                    ForEach(Array(ritualSteps.enumerated()), id: \.element.id) { idx, step in
                        if idx > 0 { Hairline() }
                        StepRow(step: step, product: product(step.productID), isComplete: log.isComplete(step)) {
                            withAnimation(.snappy) { engine.toggle(step, user: user) }
                        }
                    }
                }
            }
        }
    }
}

/// Applies the gold shimmer only when a milestone is active.
private struct MilestoneShimmer: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.goldShimmer() } else { content }
    }
}
