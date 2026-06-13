//
//  PurchaseManager.swift
//  LUMEN
//
//  LUMEN Gold subscription state, backed by RevenueCat.
//

import Foundation
import RevenueCat

/// Display model for a single Gold plan card, derived from a RevenueCat package.
struct GoldPlan: Identifiable, Hashable {
    let id: String
    let title: String
    let price: String
    let cadence: String
    let note: String?
    let highlighted: Bool
}

@MainActor
@Observable
final class PurchaseManager {
    var offering: Offering?
    var plans: [GoldPlan] = []
    var isLoading = false
    var isPurchasing = false
    var lastError: String?

    /// Map of plan id -> RevenueCat package for purchase.
    private var packagesById: [String: Package] = [:]

    init() {
        Task { await loadOfferings() }
        Task { await listenForUpdates() }
    }

    private func listenForUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            let active = info.entitlements["premium"]?.isActive == true
            if active { lastError = nil }
        }
    }

    /// Fetch the current offering and build display plans for the paywall.
    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else {
                lastError = "Subscriptions are not available right now."
                return
            }
            offering = current
            buildPlans(from: current)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func buildPlans(from offering: Offering) {
        var built: [GoldPlan] = []
        var map: [String: Package] = [:]

        if let annual = offering.annual {
            let id = annual.identifier
            map[id] = annual
            built.append(
                GoldPlan(
                    id: id,
                    title: "Annual",
                    price: annual.storeProduct.localizedPriceString,
                    cadence: "per year",
                    note: savingsNote(annual: annual, monthly: offering.monthly),
                    highlighted: true
                )
            )
        }

        if let monthly = offering.monthly {
            let id = monthly.identifier
            map[id] = monthly
            built.append(
                GoldPlan(
                    id: id,
                    title: "Monthly",
                    price: monthly.storeProduct.localizedPriceString,
                    cadence: "per month",
                    note: nil,
                    highlighted: false
                )
            )
        }

        packagesById = map
        plans = built
    }

    /// Compute "save X%" relative to paying monthly for a year.
    private func savingsNote(annual: Package, monthly: Package?) -> String? {
        guard let monthly else { return "Best value" }
        let annualPrice = annual.storeProduct.price as Decimal
        let monthlyYearly = (monthly.storeProduct.price as Decimal) * 12
        guard monthlyYearly > 0, annualPrice < monthlyYearly else { return "Best value" }
        let saved = (monthlyYearly - annualPrice) / monthlyYearly
        let percent = Int((saved as NSDecimalNumber).doubleValue * 100)
        return "Best value · save \(percent)%"
    }

    /// Purchase the plan with the given id. Returns true if the user is now premium.
    func purchase(_ planId: String, user: UserState) async -> Bool {
        guard let package = packagesById[planId] else {
            lastError = "That plan is unavailable. Please try again."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            let active = result.customerInfo.entitlements["premium"]?.isActive == true
            if active { user.isPremium = true }
            return active
        } catch ErrorCode.purchaseCancelledError {
            return false
        } catch ErrorCode.paymentPendingError {
            lastError = "Your purchase is pending approval."
            return false
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Restore prior purchases. Returns true if a premium entitlement was found.
    func restore(user: UserState) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            let active = info.entitlements["premium"]?.isActive == true
            user.isPremium = active
            if !active { lastError = "No active subscription found to restore." }
            return active
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
