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

    @State private var selectedPlan: String = ""

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
        .alert("Something went wrong", isPresented: Binding(
            get: { purchases.lastError != nil },
            set: { if !$0 { purchases.lastError = nil } }
        )) {
            Button("OK") { purchases.lastError = nil }
        } message: {
            Text(purchases.lastError ?? "")
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

    @ViewBuilder private var plans: some View {
        if purchases.isLoading {
            ProgressView()
                .tint(palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.l)
        } else {
            VStack(spacing: Space.m) {
                ForEach(purchases.plans) { plan in
                    planRow(plan)
                }
            }
            .onAppear {
                if selectedPlan.isEmpty {
                    selectedPlan = purchases.plans.first(where: { $0.highlighted })?.id
                        ?? purchases.plans.first?.id ?? ""
                }
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
                guard !selectedPlan.isEmpty else { return }
                Task {
                    if await purchases.purchase(selectedPlan, user: user) { dismiss() }
                }
            }
            .disabled(purchases.isPurchasing || selectedPlan.isEmpty)

            Button("Restore purchases") {
                Task {
                    if await purchases.restore(user: user) { dismiss() }
                }
            }
            .font(.ui(14, .medium)).foregroundStyle(palette.textSecondary)
            .disabled(purchases.isPurchasing)
        }
    }

    private var ctaTitle: String { "Start LUMEN Gold" }

    private var footer: some View {
        VStack(spacing: Space.s) {
            Text("LUMEN Gold is an auto-renewing subscription. Payment is charged to your Apple account at confirmation. It renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings → Apple ID → Subscriptions.")
                .font(.ui(11)).foregroundStyle(palette.textSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.m)

            HStack(spacing: Space.s) {
                Link("Terms of Use", destination: URL(string: "https://lumenritual.ai/terms")!)
                Text("·").foregroundStyle(palette.textSecondary.opacity(0.5))
                Link("Privacy Policy", destination: URL(string: "https://lumenritual.ai/privacy")!)
            }
            .font(.ui(11, .semibold))
            .tint(palette.accent)
            .padding(.top, 2)
        }
    }
}
