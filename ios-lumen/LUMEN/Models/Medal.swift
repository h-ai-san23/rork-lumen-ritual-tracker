//
//  Medal.swift
//  LUMEN
//
//  The catalog of medals and the criteria that unlock them.
//

import SwiftUI

/// A category of unlock criteria, used by the engine to evaluate progress.
enum MedalCriteria: Equatable, Sendable {
    /// Current streak reaches N consecutive perfect days.
    case streak(Int)
    /// Total number of perfect days ever logged reaches N.
    case perfectDaysTotal(Int)
    /// A given ritual (AM/PM) has been fully completed on N separate days.
    case ritualDays(RitualTime, Int)
    /// N completed steps accumulated within a single domain.
    case domainSteps(Domain, Int)
    /// N products tracked on the shelf.
    case shelfCurator(Int)
    /// N streak freezes banked at once.
    case freezeCount(Int)
    /// Reach a given Ritual Rank.
    case rank(Rank)
    /// Seven flawless days within a single week (current streak ≥ 7).
    case perfectWeek
    /// Return to the ritual after a missed day (granted explicitly).
    case comeback
}

/// The metal finish of a medal, driving its 3D look and rarity.
enum MedalTier: Int, Sendable, Comparable {
    case bronze, silver, gold, platinum, obsidian

    static func < (lhs: MedalTier, rhs: MedalTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var name: String {
        switch self {
        case .bronze: "Bronze"
        case .silver: "Silver"
        case .gold: "Gold"
        case .platinum: "Platinum"
        case .obsidian: "Obsidian"
        }
    }

    /// Light → mid → dark metal stops for the medallion body.
    var metal: [Color] {
        switch self {
        case .bronze:   [Color(hex: 0xF1C89A), Color(hex: 0xC67E3F), Color(hex: 0x6E3F19)]
        case .silver:   [Color(hex: 0xFBFCFE), Color(hex: 0xC4CAD3), Color(hex: 0x7C828D)]
        case .gold:     [Color(hex: 0xFDEFC2), Color(hex: 0xD9B877), Color(hex: 0x8C6A2E)]
        case .platinum: [Color(hex: 0xFFFFFF), Color(hex: 0xD7E0EA), Color(hex: 0x97A2B1)]
        case .obsidian: [Color(hex: 0x9A93AE), Color(hex: 0x3A3543), Color(hex: 0x0E0C14)]
        }
    }

    /// The bright rim / bevel colour.
    var rim: Color {
        switch self {
        case .bronze: Color(hex: 0xFAD9AE)
        case .silver: Color(hex: 0xFFFFFF)
        case .gold: Color(hex: 0xFFF0C4)
        case .platinum: Color(hex: 0xFFFFFF)
        case .obsidian: Color(hex: 0xC9B3F2)
        }
    }

    /// The colour of the surrounding glow/shimmer.
    var glow: Color {
        switch self {
        case .bronze: Color(hex: 0xE08A3C)
        case .silver: Color(hex: 0xBFE3FF)
        case .gold: Color(hex: 0xE7C25C)
        case .platinum: Color(hex: 0xBFD6FF)
        case .obsidian: Color(hex: 0x9C6BFF)
        }
    }

    /// Tint for the embossed symbol so it reads against the metal.
    var emblem: Color {
        switch self {
        case .bronze: Color(hex: 0x4A2A10)
        case .silver: Color(hex: 0x474C55)
        case .gold: Color(hex: 0x5C4416)
        case .platinum: Color(hex: 0x586273)
        case .obsidian: Color(hex: 0xEADBFF)
        }
    }
}

struct Medal: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tier: MedalTier
    let criteria: MedalCriteria

    static let all: [Medal] = [
        // MARK: Streaks
        Medal(id: "streak3", title: "First Steps", detail: "Complete your full ritual three days in a row.", symbol: "figure.walk", tier: .bronze, criteria: .streak(3)),
        Medal(id: "streak7", title: "Seven Days", detail: "Complete your full ritual seven days in a row.", symbol: "flame.fill", tier: .bronze, criteria: .streak(7)),
        Medal(id: "streak14", title: "Fortnight", detail: "Two unbroken weeks of devotion.", symbol: "flame.fill", tier: .silver, criteria: .streak(14)),
        Medal(id: "streak30", title: "Devoted", detail: "A thirty-day streak. The ritual is now a habit.", symbol: "flame.circle.fill", tier: .silver, criteria: .streak(30)),
        Medal(id: "streak60", title: "Unbroken", detail: "Sixty consecutive perfect days.", symbol: "flame.circle.fill", tier: .gold, criteria: .streak(60)),
        Medal(id: "streak100", title: "Centurion", detail: "One hundred consecutive perfect days.", symbol: "laurel.leading", tier: .gold, criteria: .streak(100)),
        Medal(id: "streak180", title: "Half a Year", detail: "A 180-day streak. Unshakeable.", symbol: "laurel.leading", tier: .platinum, criteria: .streak(180)),
        Medal(id: "streak365", title: "A Full Year", detail: "365 days of devotion to yourself.", symbol: "sparkles", tier: .obsidian, criteria: .streak(365)),

        // MARK: Perfect days (lifetime)
        Medal(id: "perfectFirst", title: "First Light", detail: "Complete your very first perfect day.", symbol: "sun.max.fill", tier: .bronze, criteria: .perfectDaysTotal(1)),
        Medal(id: "perfect25", title: "Twenty-Five", detail: "Log twenty-five perfect days in total.", symbol: "star.fill", tier: .silver, criteria: .perfectDaysTotal(25)),
        Medal(id: "perfect100", title: "Hundred Rituals", detail: "One hundred perfect days, all-time.", symbol: "star.circle.fill", tier: .gold, criteria: .perfectDaysTotal(100)),
        Medal(id: "perfect250", title: "Relentless", detail: "Two hundred and fifty perfect days logged.", symbol: "sparkle", tier: .platinum, criteria: .perfectDaysTotal(250)),
        Medal(id: "perfectWeek", title: "Perfect Week", detail: "Seven flawless days within a single week.", symbol: "checkmark.seal.fill", tier: .silver, criteria: .perfectWeek),

        // MARK: Morning / Evening
        Medal(id: "am20", title: "Early Riser", detail: "Finish your morning ritual on twenty days.", symbol: "sunrise.fill", tier: .bronze, criteria: .ritualDays(.am, 20)),
        Medal(id: "am100", title: "Dawn Keeper", detail: "One hundred completed morning rituals.", symbol: "sun.horizon.fill", tier: .gold, criteria: .ritualDays(.am, 100)),
        Medal(id: "pm20", title: "Night Owl", detail: "Finish your evening ritual on twenty days.", symbol: "moon.fill", tier: .bronze, criteria: .ritualDays(.pm, 20)),
        Medal(id: "pm100", title: "Dusk Keeper", detail: "One hundred completed evening rituals.", symbol: "moon.stars.fill", tier: .gold, criteria: .ritualDays(.pm, 100)),

        // MARK: Domain mastery
        Medal(id: "domainSkin", title: "Skin Adept", detail: "Complete fifty skin-care steps.", symbol: "drop.fill", tier: .silver, criteria: .domainSteps(.skin, 50)),
        Medal(id: "domainHair", title: "Mane Tamed", detail: "Complete fifty hair-care steps.", symbol: "comb.fill", tier: .silver, criteria: .domainSteps(.hair, 50)),
        Medal(id: "domainGrooming", title: "Sharp", detail: "Complete fifty grooming steps.", symbol: "scissors", tier: .silver, criteria: .domainSteps(.grooming, 50)),
        Medal(id: "domainSleep", title: "Rested", detail: "Complete fifty wind-down steps.", symbol: "moon.zzz.fill", tier: .silver, criteria: .domainSteps(.sleep, 50)),
        Medal(id: "domainHealth", title: "Vital", detail: "Complete fifty health steps.", symbol: "heart.fill", tier: .silver, criteria: .domainSteps(.health, 50)),

        // MARK: Shelf
        Medal(id: "shelf3", title: "Collector", detail: "Track three products on your shelf.", symbol: "books.vertical", tier: .bronze, criteria: .shelfCurator(3)),
        Medal(id: "curator", title: "Shelf Curator", detail: "Track ten products on your shelf.", symbol: "books.vertical.fill", tier: .silver, criteria: .shelfCurator(10)),
        Medal(id: "shelf25", title: "Connoisseur", detail: "Curate a shelf of twenty-five products.", symbol: "archivebox.fill", tier: .gold, criteria: .shelfCurator(25)),

        // MARK: Streak freezes
        Medal(id: "freeze3", title: "Cool Headed", detail: "Bank three streak freezes at once.", symbol: "snowflake", tier: .silver, criteria: .freezeCount(3)),
        Medal(id: "freeze10", title: "Frostproof", detail: "Bank ten streak freezes at once.", symbol: "snowflake.circle.fill", tier: .platinum, criteria: .freezeCount(10)),

        // MARK: Rank
        Medal(id: "rankRefined", title: "Refined", detail: "Reach the Refined rank.", symbol: "seal.fill", tier: .gold, criteria: .rank(.refined)),
        Medal(id: "rankMaster", title: "Master", detail: "Reach the Master rank.", symbol: "crown", tier: .platinum, criteria: .rank(.master)),
        Medal(id: "rankLuminary", title: "Luminary", detail: "Reach the highest rank — Luminary.", symbol: "crown.fill", tier: .obsidian, criteria: .rank(.luminary)),

        // MARK: Resilience
        Medal(id: "comeback", title: "The Comeback", detail: "Return to your ritual after a missed day.", symbol: "arrow.uturn.up.circle.fill", tier: .gold, criteria: .comeback),
    ]

    static func by(id: String) -> Medal? { all.first { $0.id == id } }
}
