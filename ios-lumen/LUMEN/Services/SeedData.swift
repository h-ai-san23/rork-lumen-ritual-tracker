//
//  SeedData.swift
//  LUMEN
//
//  Generates a default AM/PM ritual, starter shelf, and lively history
//  so every screen looks alive on first launch.
//

import Foundation
import SwiftData

@MainActor
enum SeedData {

    /// Build a default ritual + shelf based on the chosen domains.
    static func buildRitual(for domains: [Domain], in context: ModelContext) -> [Product] {
        // Starter products keyed by domain.
        let starters: [(Domain, String, String, Int, Double)] = [
            (.skin, "Gentle Gel Cleanser", "Lumière", 12, 24),
            (.skin, "Vitamin C Serum", "Atelier", 6, 58),
            (.skin, "Mineral SPF 50", "Solé", 12, 32),
            (.skin, "Retinol Night Treatment", "Atelier", 6, 64),
            (.hair, "Strengthening Shampoo", "Maison", 18, 22),
            (.hair, "Leave-In Conditioner", "Maison", 12, 26),
            (.grooming, "Sandalwood Beard Oil", "Noir", 12, 30),
            (.grooming, "Sharp Razor Cream", "Noir", 24, 18),
            (.sleep, "Magnesium Glycinate", "Vital", 24, 28),
            (.sleep, "Lavender Pillow Mist", "Solé", 18, 20),
            (.health, "Daily Multivitamin", "Vital", 24, 34),
            (.health, "Omega-3", "Vital", 18, 30),
        ]

        var products: [Domain: [Product]] = [:]
        for (domain, name, brand, pao, cost) in starters where domains.contains(domain) {
            let opened = Calendar.current.date(byAdding: .day, value: -Int.random(in: 10...120), to: Date())
            let p = Product(name: name, brand: brand, domain: domain, openedDate: opened, paoMonths: pao, cost: cost)
            p.usageCount = Int.random(in: 8...60)
            context.insert(p)
            products[domain, default: []].append(p)
        }

        // Flag one product as running low for an alive Shelf.
        products[.skin]?.first?.lowFlag = true

        func pid(_ domain: Domain, _ index: Int) -> UUID? {
            products[domain]?[safe: index]?.id
        }

        // AM ritual template.
        var amTemplate: [(Domain, String, String, Int, Int)] = []
        if domains.contains(.skin) {
            amTemplate += [
                (.skin, "Cleanse", "Massage a coin-sized amount over damp skin for 60 seconds, then rinse with lukewarm water.", 60, 0),
                (.skin, "Vitamin C", "Press 3–4 drops into the skin while damp. Wait one minute before the next step.", 60, 1),
                (.skin, "SPF", "Two finger-lengths across the face and neck. Reapply through the day.", 0, 2),
            ]
        }
        if domains.contains(.hair) {
            amTemplate.append((.hair, "Style & Protect", "Work leave-in through mid-lengths to ends; comb through.", 0, 1))
        }
        if domains.contains(.health) {
            amTemplate += [
                (.health, "Hydrate", "A full glass of water before coffee.", 0, 0),
                (.health, "Morning Supplements", "Take your multivitamin with food.", 0, 0),
            ]
        }
        if domains.contains(.grooming) {
            amTemplate.append((.grooming, "Shave", "Warm the skin, apply cream, shave with the grain.", 0, 1))
        }

        // PM ritual template.
        var pmTemplate: [(Domain, String, String, Int, Int)] = []
        if domains.contains(.skin) {
            pmTemplate += [
                (.skin, "Double Cleanse", "Remove the day, then cleanse a second time.", 60, 0),
                (.skin, "Night Treatment", "A pea-sized amount of retinol, avoiding the eye area.", 0, 3),
            ]
        }
        if domains.contains(.hair) {
            pmTemplate.append((.hair, "Wash", "Shampoo the scalp, condition the lengths.", 120, 0))
        }
        if domains.contains(.grooming) {
            pmTemplate.append((.grooming, "Beard Oil", "Three drops, worked from root to tip.", 0, 0))
        }
        if domains.contains(.health) {
            pmTemplate.append((.health, "Evening Omega-3", "Take with your last meal.", 0, 1))
        }
        if domains.contains(.sleep) {
            pmTemplate += [
                (.sleep, "Magnesium", "One capsule, 30 minutes before bed.", 0, 0),
                (.sleep, "Pillow Mist", "Two spritzes on the pillow. Dim the lights.", 0, 1),
                (.sleep, "Wind Down", "Screens away. Three slow breaths.", 300, 0),
            ]
        }

        for (i, t) in amTemplate.enumerated() {
            let step = RitualStep(ritual: .am, domain: t.0, title: t.1, howTo: t.2, timerSeconds: t.3, productID: pid(t.0, t.4), order: i)
            context.insert(step)
        }
        for (i, t) in pmTemplate.enumerated() {
            let step = RitualStep(ritual: .pm, domain: t.0, title: t.1, howTo: t.2, timerSeconds: t.3, productID: pid(t.0, t.4), order: i)
            context.insert(step)
        }

        return products.values.flatMap { $0 }
    }

    /// Seed a few weeks of believable history so Progress charts and streaks look alive.
    static func seedHistory(steps: [RitualStep], user: UserState, in context: ModelContext) {
        let cal = Calendar.current
        let stepIDs = steps.map { $0.id.uuidString }
        var perfectRun = 0

        for offset in stride(from: 27, through: 1, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let log = DayLog(date: date)
            // Mostly-complete days, occasionally partial.
            let isPerfect = Int.random(in: 0...10) > 2
            if isPerfect {
                log.completedStepIDs = stepIDs
                perfectRun += 1
            } else {
                log.completedStepIDs = Array(stepIDs.shuffled().prefix(stepIDs.count / 2))
                perfectRun = 0
            }
            log.skinRating = isPerfect ? Int.random(in: 6...9) : Int.random(in: 4...7)
            log.sleepHours = Double(Int.random(in: 5...9)) + (Bool.random() ? 0.5 : 0)
            log.mood = Int.random(in: 5...9)
            context.insert(log)
        }

        user.streak = max(perfectRun, 5)
        user.bestStreak = max(user.streak, 12)
        user.xp = 1340
        user.freezes = 1
        user.medalsUnlocked = ["streak7", "perfectWeek", "comeback"]
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
