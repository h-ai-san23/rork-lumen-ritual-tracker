//
//  RitualEngine.swift
//  LUMEN
//
//  The brain of the app: completion tracking, XP, streaks, freezes, and medals.
//

import Foundation
import SwiftData
import SwiftUI

/// An event surfaced to the UI so it can celebrate (confetti, haptic, sheet).
enum UnlockEvent: Equatable {
    case perfectDay
    case medal(String)
    case rankUp(Rank)
    case streakMilestone(Int)
    case freezeEarned
}

@MainActor
@Observable
final class RitualEngine {
    private let context: ModelContext
    private let calendar = Calendar.current

    /// The most recent unlock to celebrate; the UI observes and clears it.
    var pendingCelebration: UnlockEvent?
    var comebackOffered = false

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Fetch helpers

    func steps(for ritual: RitualTime) -> [RitualStep] {
        let raw = ritual.rawValue
        let descriptor = FetchDescriptor<RitualStep>(
            predicate: #Predicate { $0.ritualRaw == raw },
            sortBy: [SortDescriptor(\.order)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func allSteps() -> [RitualStep] {
        (try? context.fetch(FetchDescriptor<RitualStep>(sortBy: [SortDescriptor(\.order)]))) ?? []
    }

    func product(_ id: UUID?) -> Product? {
        guard let id else { return nil }
        return (try? context.fetch(FetchDescriptor<Product>()))?.first { $0.id == id }
    }

    func log(for date: Date) -> DayLog {
        let day = calendar.startOfDay(for: date)
        let logs = (try? context.fetch(FetchDescriptor<DayLog>())) ?? []
        if let existing = logs.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            return existing
        }
        let new = DayLog(date: day)
        context.insert(new)
        return new
    }

    var today: DayLog { log(for: Date()) }

    // MARK: - Completion

    /// Fraction (0...1) of today's steps complete.
    func completion(for log: DayLog) -> Double {
        let steps = allSteps()
        guard !steps.isEmpty else { return 0 }
        let done = steps.filter { log.isComplete($0) }.count
        return Double(done) / Double(steps.count)
    }

    func completion(for ritual: RitualTime, log: DayLog) -> Double {
        let steps = steps(for: ritual)
        guard !steps.isEmpty else { return 0 }
        let done = steps.filter { log.isComplete($0) }.count
        return Double(done) / Double(steps.count)
    }

    /// Toggle a step's completion and run all the gamification side-effects.
    func toggle(_ step: RitualStep, user: UserState) {
        let log = today
        let id = step.id.uuidString
        let wasComplete = log.isComplete(step)

        if wasComplete {
            log.completedStepIDs.removeAll { $0 == id }
            user.xp = max(0, user.xp - 10)
            if let product = product(step.productID) {
                product.usageCount = max(0, product.usageCount - 1)
            }
            return
        }

        // Completing the step.
        log.completedStepIDs.append(id)
        user.xp += 10
        if let product = product(step.productID) {
            product.usageCount += 1
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        let previousRank = user.rank
        checkFullRitual(.am, user: user, log: log)
        checkFullRitual(.pm, user: user, log: log)
        checkPerfectDay(user: user, log: log)

        if user.rank != previousRank {
            celebrate(.rankUp(user.rank))
            if user.rank == .refined { unlock("rankRefined", user: user) }
            if user.rank == .luminary { unlock("rankLuminary", user: user) }
        }
        evaluateMedals(user: user)
    }

    private var fullyAwarded: Set<String> = []

    private func checkFullRitual(_ ritual: RitualTime, user: UserState, log: DayLog) {
        let key = "\(calendar.startOfDay(for: Date()).timeIntervalSince1970)-\(ritual.rawValue)"
        guard completion(for: ritual, log: log) >= 1, !fullyAwarded.contains(key) else { return }
        fullyAwarded.insert(key)
        user.xp += 50
    }

    private func checkPerfectDay(user: UserState, log: DayLog) {
        guard completion(for: log) >= 1 else { return }
        let today = calendar.startOfDay(for: Date())
        if let last = user.lastPerfectDay, calendar.isDate(last, inSameDayAs: today) {
            return // already counted today
        }

        // Continue the streak if yesterday was perfect, otherwise start fresh at 1.
        if let last = user.lastPerfectDay,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(last, inSameDayAs: yesterday) {
            user.streak += 1
        } else {
            user.streak = 1
        }

        user.lastPerfectDay = today
        user.bestStreak = max(user.bestStreak, user.streak)

        // Earn a freeze every 7 perfect days.
        user.perfectDaysTowardFreeze += 1
        if user.perfectDaysTowardFreeze >= 7 {
            user.perfectDaysTowardFreeze = 0
            user.freezes += 1
            celebrate(.freezeEarned)
        }

        celebrate(.perfectDay)
        if [7, 30, 100, 365].contains(user.streak) {
            celebrate(.streakMilestone(user.streak))
        }
    }

    // MARK: - Daily reconciliation (streak survival / comeback)

    /// Run once per launch to handle missed days using freezes.
    func reconcile(user: UserState) {
        let today = calendar.startOfDay(for: Date())
        if let last = user.lastReconciledDay, calendar.isDate(last, inSameDayAs: today) { return }
        user.lastReconciledDay = today

        guard let lastPerfect = user.lastPerfectDay else { return }
        let days = calendar.dateComponents([.day], from: lastPerfect, to: today).day ?? 0
        guard days >= 2 else { return } // missed at least one full day

        let missed = days - 1
        if user.freezes >= missed {
            user.freezes -= missed // freezes absorb the gap, streak survives
        } else {
            user.streak = 0
            user.perfectDaysTowardFreeze = 0
            comebackOffered = true
        }
    }

    // MARK: - Medals

    func evaluateMedals(user: UserState) {
        let productCount = (try? context.fetchCount(FetchDescriptor<Product>())) ?? 0
        let logs = (try? context.fetch(FetchDescriptor<DayLog>())) ?? []
        let perfectDays = logs.filter { completion(for: $0) >= 1 }.count

        // Days each ritual (AM/PM) was fully completed.
        let amDays = logs.filter { completion(for: .am, log: $0) >= 1 }.count
        let pmDays = logs.filter { completion(for: .pm, log: $0) >= 1 }.count

        // Lifetime completed steps grouped by domain.
        let steps = allSteps()
        var domainForStep: [String: Domain] = [:]
        for step in steps { domainForStep[step.id.uuidString] = step.domain }
        var domainCompletions: [Domain: Int] = [:]
        for log in logs {
            for id in log.completedStepIDs {
                if let domain = domainForStep[id] {
                    domainCompletions[domain, default: 0] += 1
                }
            }
        }

        for medal in Medal.all where !user.medalsUnlocked.contains(medal.id) {
            let earned: Bool
            switch medal.criteria {
            case .streak(let n): earned = user.streak >= n
            case .perfectWeek: earned = user.streak >= 7
            case .perfectDaysTotal(let n): earned = perfectDays >= n
            case .ritualDays(let ritual, let n): earned = (ritual == .am ? amDays : pmDays) >= n
            case .domainSteps(let domain, let n): earned = (domainCompletions[domain] ?? 0) >= n
            case .shelfCurator(let n): earned = productCount >= n
            case .freezeCount(let n): earned = user.freezes >= n
            case .comeback: earned = false // granted explicitly on comeback
            case .rank(let r): earned = user.xp >= r.threshold
            }
            if earned { unlock(medal.id, user: user) }
        }
    }

    func grantComeback(user: UserState) {
        unlock("comeback", user: user)
        comebackOffered = false
    }

    func unlock(_ id: String, user: UserState) {
        guard !user.medalsUnlocked.contains(id) else { return }
        user.medalsUnlocked.append(id)
        celebrate(.medal(id))
    }

    private func celebrate(_ event: UnlockEvent) {
        // Last meaningful celebration wins; medals take priority over perfect-day.
        if case .perfectDay = event, pendingCelebration != nil { return }
        pendingCelebration = event
    }
}
