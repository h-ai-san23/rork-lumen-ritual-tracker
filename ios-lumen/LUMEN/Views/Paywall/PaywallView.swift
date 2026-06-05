//
//  PaywallView.swift
//  LUMEN
//
//  LUMEN Gold paywall — lux full-screen sheet with transparent pricing.
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var purchases = PurchaseManager()
    let user: UserState

    @State private var selectedPlan = GoldPlan.all.first!.id

    private let perks: [(String, String)] = [
        ("infinity", "Unlimited products & shelf analytics"),
        ("chart.line.uptrend.xyaxis", "Insights — habit & result correlations"),
        ("photo.stack", "Unlimited progress photo history"),
        ("bubble.left.and.text.bubble.right", "Unlimited AI advisor"),
        ("snowflake", "Streak freezes & boosts"),
        ("square.and.arrow.up", "PDF export & all themes"),
    ]

    var body: some View {
        ZStack {
            LumenBackground()
            ScrollView {
                VStack(spacing: Space.xl) {
                    header
                    perksList
                    plans
                    cta
                    footer
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.xl)
                .padding(.bottom, Space.xxl)
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.ui(14, .semibold)).foregroundStyle(palette.textSecondary)
                            .frame(width: 34, height: 34).background(Circle().fill(palette.surface1))
                    }
                }
                .padding(Space.l)
                Spacer()
            }
        }
    }

    private var header: some View {
        VStack(spacing: Space.m) {
            ZStack {
                AuraOrb(intensity: 0.9).frame(width: 120, height: 120)
                Image(systemName: "crown.fill").font(.system(size: 40)).foregroundStyle(palette.gold)
            }
            Text("LUMEN Gold")
                .font(.serif(34, .semibold)).foregroundStyle(palette.textPrimary).tracking(-0.5)
            Text("Your full ritual, without limits.")
                .font(.ui(16)).foregroundStyle(palette.textSecondary)
        }
        .padding(.top, Space.l)
    }

    private var perksList: some View {
        VStack(spacing: Space.m) {
            ForEach(perks, id: \.1) { perk in
                HStack(spacing: Space.m) {
                    Image(systemName: perk.0).font(.ui(16)).foregroundStyle(palette.accent).frame(width: 28)
                    Text(perk.1).font(.ui(15)).foregroundStyle(palette.textPrimary)
                    Spacer()
                    Image(systemName: "checkmark").font(.ui(12, .bold)).foregroundStyle(palette.sage)
                }
            }
        }
        .padding(Space.l)
        .background(palette.surface1)
        .clipShape(.rect(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(palette.hairline, lineWidth: 1))
    }

    private var plans: some View {
        VStack(spacing: Space.m) {
            ForEach(GoldPlan.all) { plan in
                planRow(plan)
            }
        }
    }

    private func planRow(_ plan: GoldPlan) -> some View {
        let isSelected = selectedPlan == plan.id
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            selectedPlan = plan.id
        } label: {
            HStack(spacing: Space.m) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.ui(20)).foregroundStyle(isSelected ? palette.accent : palette.hairline)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Space.s) {
                        Text(plan.title).font(.ui(17, .semibold)).foregroundStyle(palette.textPrimary).lineLimit(1)
                        if plan.highlighted {
                            Text("BEST VALUE").font(.ui(9, .bold)).tracking(0.5)
                                .foregroundStyle(Color(hex: 0x1A1306))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Capsule().fill(palette.gold))
                        }
                    }
                    if let note = plan.note {
                        Text(note).font(.ui(12)).foregroundStyle(palette.accent).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(plan.price).font(.ui(17, .bold)).foregroundStyle(palette.textPrimary).lineLimit(1)
                    Text(plan.cadence).font(.ui(11)).foregroundStyle(palette.textSecondary).lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(Space.l)
            .background(palette.surface1)
            .clipShape(.rect(cornerRadius: Radius.tile))
            .overlay(RoundedRectangle(cornerRadius: Radius.tile)
                .strokeBorder(isSelected ? palette.accent : palette.hairline, lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private var cta: some View {
        VStack(spacing: Space.m) {
            GoldButton(title: purchases.isPurchasing ? "Processing…" : ctaTitle) {
                guard let plan = GoldPlan.all.first(where: { $0.id == selectedPlan }) else { return }
                Task {
                    if await purchases.purchase(plan, user: user) { dismiss() }
                }
            }
            .disabled(purchases.isPurchasing)

            Button("Restore purchases") {
                Task { _ = await purchases.restore(user: user) }
            }
            .font(.ui(14, .medium)).foregroundStyle(palette.textSecondary)
        }
    }

    private var ctaTitle: String { "Start LUMEN Gold" }

    private var footer: some View {
        Text("Cancel anytime in Settings → Apple ID → Subscriptions. Your subscription renews automatically until cancelled. Payment is charged to your Apple account.")
            .font(.ui(11)).foregroundStyle(palette.textSecondary.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.m)
    }
}
