//
//  AIAdvisor.swift
//  LUMEN
//
//  The conversational advisor. Ships with a calm, neutral on-device responder
//  that grounds answers in the user's actual shelf.
//
//  TODO: To wire a live LLM, set Config.LUMEN_AI_API_KEY and route
//  `respond(to:)` through the Rork chat proxy (see .rork/skills/ai). Keep the
//  same `AdvisorReply` shape so the UI is unchanged.
//

import Foundation

/// A tappable product recommendation attached to an advisor reply.
struct AdvisorSuggestion: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let reason: String
    let reorderUrl: String
}

struct AdvisorReply {
    let text: String
    let suggestions: [AdvisorSuggestion]
}

struct AdvisorMessage: Identifiable, Equatable {
    let id = UUID()
    let isUser: Bool
    let text: String
    var suggestions: [AdvisorSuggestion] = []

    static func == (lhs: AdvisorMessage, rhs: AdvisorMessage) -> Bool { lhs.id == rhs.id }
}

@MainActor
enum AIAdvisor {

    /// Generate a neutral, helpful reply grounded in the user's shelf.
    static func respond(to question: String, shelf: [Product]) async -> AdvisorReply {
        // Small delay to feel considered.
        try? await Task.sleep(for: .milliseconds(650))

        let q = question.lowercased()

        func pick(_ domain: Domain) -> [AdvisorSuggestion] {
            shelf.filter { $0.domain == domain }.prefix(2).map {
                AdvisorSuggestion(
                    name: "\($0.brand) \($0.name)".trimmingCharacters(in: .whitespaces),
                    reason: reason(for: $0.domain),
                    reorderUrl: $0.reorderUrl.isEmpty ? "https://example.com/reorder" : $0.reorderUrl
                )
            }
        }

        if q.contains("dry") || q.contains("hydrat") || q.contains("flak") {
            return AdvisorReply(
                text: "For dryness, lead with gentle hydration rather than more active ingredients. Apply moisturiser to slightly damp skin to lock water in, and keep exfoliation to once or twice a week. If you use retinol, buffer it with a moisturiser the first few weeks.",
                suggestions: pick(.skin)
            )
        }
        if q.contains("acne") || q.contains("break") || q.contains("oily") || q.contains("pore") {
            return AdvisorReply(
                text: "Consistency beats intensity. Cleanse twice daily, introduce one active at a time, and never skip SPF — many treatments increase sun sensitivity. Give any new step three to four weeks before judging it.",
                suggestions: pick(.skin)
            )
        }
        if q.contains("sleep") || q.contains("tired") || q.contains("rest") {
            return AdvisorReply(
                text: "A steady wind-down matters more than any single product. Dim lights an hour before bed, keep screens away, and try magnesium glycinate 30 minutes before sleep. Aim for a consistent wake time, even on weekends.",
                suggestions: pick(.sleep)
            )
        }
        if q.contains("hair") || q.contains("scalp") || q.contains("frizz") {
            return AdvisorReply(
                text: "Focus shampoo on the scalp and conditioner on the lengths. If you style with heat, a leave-in plus lower heat will protect more than any single repair product. Less frequent washing often improves texture.",
                suggestions: pick(.hair)
            )
        }
        if q.contains("beard") || q.contains("shave") || q.contains("groom") {
            return AdvisorReply(
                text: "Always shave with the grain after warming the skin to reduce irritation. A few drops of oil after keeps the beard soft and the skin underneath calm. Replace blades often — a dull blade causes most razor burn.",
                suggestions: pick(.grooming)
            )
        }
        if q.contains("order") || q.contains("routine") || q.contains("layer") {
            return AdvisorReply(
                text: "A simple rule: thinnest to thickest. Cleanse, then water-based serums, then treatments, then moisturiser, and SPF last in the morning. At night, retinol goes after cleansing and before moisturiser.",
                suggestions: pick(.skin)
            )
        }

        return AdvisorReply(
            text: "Tell me a little about your goal — clearer skin, better sleep, a simpler routine — and I'll tailor a few steps. I'll keep it calm and only suggest what genuinely helps. You can ask about ingredient order, timing, or what to use from your shelf.",
            suggestions: Array(shelf.prefix(2).map {
                AdvisorSuggestion(name: "\($0.brand) \($0.name)".trimmingCharacters(in: .whitespaces),
                                  reason: reason(for: $0.domain),
                                  reorderUrl: $0.reorderUrl.isEmpty ? "https://example.com/reorder" : $0.reorderUrl)
            })
        )
    }

    private static func reason(for domain: Domain) -> String {
        switch domain {
        case .skin: "A reliable base for your routine."
        case .hair: "Supports healthier lengths over time."
        case .grooming: "Keeps skin calm post-shave."
        case .sleep: "Helps signal your body it's time to rest."
        case .health: "An easy daily foundation."
        }
    }
}
