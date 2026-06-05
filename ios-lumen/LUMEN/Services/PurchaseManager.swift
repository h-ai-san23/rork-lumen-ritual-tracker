//
//  PurchaseManager.swift
//  LUMEN
//
//  LUMEN Gold subscription state.
//
//  TODO: Wire RevenueCat. Add the purchases-ios SPM package, configure with your
//  public SDK key, and replace `purchase(_:)` / `restore()` with Purchases.shared
//  calls. Update `isPremium` from the customer info entitlements. The plan list and
//  paywall UI below are production-ready and do not need to change.
//

import Foundation

struct GoldPlan: Identifiable, Hashable {
    let id: String
    let title: String
    let price: String
    let cadence: String
    let note: String?
    let highlighted: Bool

    static let all: [GoldPlan] = [
        GoldPlan(id: "annual", title: "Annual", price: "$10.99", cadence: "per year", note: "Best value · save 54%", highlighted: true),
        GoldPlan(id: "monthly", title: "Monthly", price: "$1.99", cadence: "per month", note: nil, highlighted: false),
    ]
}

@MainActor
@Observable
final class PurchaseManager {
    var isPurchasing = false
    var lastError: String?

    /// Simulate a purchase locally so the flow is fully demoable.
    func purchase(_ plan: GoldPlan, user: UserState) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await Task.sleep(for: .milliseconds(900))
        user.isPremium = true
        return true
    }

    func restore(user: UserState) async -> Bool {
        try? await Task.sleep(for: .milliseconds(700))
        // TODO: query RevenueCat entitlements. For now, no-op restore.
        return user.isPremium
    }
}
