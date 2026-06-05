//
//  UserState.swift
//  LUMEN
//
//  The single persistent record of the user's progress and preferences.
//

import Foundation
import SwiftData

@Model
final class UserState {
    var streak: Int = 0
    var bestStreak: Int = 0
    var freezes: Int = 0
    var xp: Int = 0
    var medalsUnlocked: [String] = []
    var isPremium: Bool = false
    var isDark: Bool = true
    var onboardingComplete: Bool = false

    var wakeTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    var windDownTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    var remindersEnabled: Bool = true

    var goals: [String] = []
    var selectedDomains: [String] = Domain.allCases.map(\.rawValue)

    /// Onboarding answers (kept lightweight as strings).
    var skinType: String = ""
    var skinConcerns: [String] = []
    var hairType: String = ""
    var groomingFocus: String = ""
    var sleepGoal: Double = 8

    /// Day of the last fully-completed (perfect) ritual, for streak math.
    var lastPerfectDay: Date?
    /// Last day the app ran the daily streak reconciliation.
    var lastReconciledDay: Date?
    /// Perfect days accumulated toward the next streak freeze.
    var perfectDaysTowardFreeze: Int = 0
    /// Free AI advisor questions used this calendar month.
    var advisorQuestionsThisMonth: Int = 0
    var advisorMonthMarker: Int = Calendar.current.component(.month, from: Date())

    init() {}

    var rank: Rank { Rank.forXP(xp) }

    var domains: [Domain] {
        selectedDomains.compactMap { Domain(rawValue: $0) }
    }
}
