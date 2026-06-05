//
//  Domain.swift
//  LUMEN
//
//  Core enums shared across the ritual data model.
//

import SwiftUI

/// The five self-care domains LUMEN bundles into one ritual.
enum Domain: String, CaseIterable, Codable, Identifiable, Sendable {
    case skin, hair, grooming, sleep, health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skin: "Skin"
        case .hair: "Hair"
        case .grooming: "Grooming"
        case .sleep: "Sleep"
        case .health: "Health"
        }
    }

    var symbol: String {
        switch self {
        case .skin: "drop.fill"
        case .hair: "comb.fill"
        case .grooming: "scissors"
        case .sleep: "moon.stars.fill"
        case .health: "heart.fill"
        }
    }

    var blurb: String {
        switch self {
        case .skin: "Cleanse, treat, protect."
        case .hair: "Wash, nourish, style."
        case .grooming: "Shave, trim, refine."
        case .sleep: "Wind down, rest deeply."
        case .health: "Hydrate, move, supplement."
        }
    }
}

/// AM or PM half of the daily ritual.
enum RitualTime: String, CaseIterable, Codable, Identifiable, Sendable {
    case am = "AM"
    case pm = "PM"

    var id: String { rawValue }
    var title: String { self == .am ? "Morning Ritual" : "Evening Ritual" }
    var symbol: String { self == .am ? "sun.max.fill" : "moon.fill" }
}

/// Ritual Rank insignia, rising with total XP.
enum Rank: String, CaseIterable, Codable, Sendable {
    case initiate = "Initiate"
    case adept = "Adept"
    case refined = "Refined"
    case master = "Master"
    case luminary = "Luminary"

    var threshold: Int {
        switch self {
        case .initiate: 0
        case .adept: 500
        case .refined: 2000
        case .master: 6000
        case .luminary: 15000
        }
    }

    var symbol: String {
        switch self {
        case .initiate: "circle"
        case .adept: "seal"
        case .refined: "seal.fill"
        case .master: "crown"
        case .luminary: "crown.fill"
        }
    }

    static func forXP(_ xp: Int) -> Rank {
        allCases.last { xp >= $0.threshold } ?? .initiate
    }

    /// XP needed to reach the next rank, or nil if already Luminary.
    var next: Rank? {
        let all = Rank.allCases
        guard let idx = all.firstIndex(of: self), idx + 1 < all.count else { return nil }
        return all[idx + 1]
    }
}
