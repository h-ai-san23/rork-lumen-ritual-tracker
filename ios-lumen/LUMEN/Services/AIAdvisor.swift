//
//  AIAdvisor.swift
//  LUMEN
//
//  The conversational advisor. Routes through the Rork AI proxy with the user's
//  actual shelf, rituals, and profile as context so answers are genuinely
//  knowledgeable and personal. Stays strictly scoped to LUMEN and self-care.
//  Falls back to a calm on-device responder if AI is unavailable.
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

    // MARK: - Config

    private static var baseURL: String { Config.EXPO_PUBLIC_TOOLKIT_URL }
    private static var secret: String { Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY }
    private static var isConfigured: Bool { !secret.isEmpty && !baseURL.isEmpty }
    private static let model = "google/gemini-2.5-flash"

    // MARK: - Public API

    /// Generate a knowledgeable, on-topic reply grounded in the user's shelf,
    /// rituals, and profile. Keeps the conversation scoped to LUMEN and self-care.
    static func respond(
        to question: String,
        history: [AdvisorMessage],
        shelf: [Product],
        steps: [RitualStep],
        user: UserState
    ) async -> AdvisorReply {
        guard isConfigured else { return offlineReply(to: question, shelf: shelf) }

        do {
            return try await liveReply(to: question, history: history, shelf: shelf, steps: steps, user: user)
        } catch {
            return offlineReply(to: question, shelf: shelf)
        }
    }

    // MARK: - Live AI

    private static func liveReply(
        to question: String,
        history: [AdvisorMessage],
        shelf: [Product],
        steps: [RitualStep],
        user: UserState
    ) async throws -> AdvisorReply {
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt(shelf: shelf, steps: steps, user: user)],
        ]
        // Carry recent turns so follow-ups have context (skip the seeded greeting).
        for message in history.suffix(8) where !message.text.isEmpty {
            messages.append(["role": message.isUser ? "user" : "assistant", "content": message.text])
        }
        messages.append(["role": "user", "content": question])

        let body: [String: Any] = ["model": model, "messages": messages]
        let data = try await postChat(body: body)

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let raw = decoded.choices.first?.message.content else { throw AdvisorError.empty }
        return parse(raw, shelf: shelf)
    }

    /// The model answers with strict JSON so we can attach real product cards.
    private static func systemPrompt(shelf: [Product], steps: [RitualStep], user: UserState) -> String {
        let shelfList = shelf.isEmpty
            ? "The shelf is currently empty."
            : shelf.map { p in
                let opened = p.openedDate != nil ? "opened" : "unopened"
                let low = p.lowFlag ? ", running low" : ""
                let expiring = p.isExpiringSoon ? ", expiring soon" : ""
                return "- \(p.brand) \(p.name) [\(p.domain.title)] (\(opened)\(low)\(expiring))"
            }.joined(separator: "\n")

        func ritual(_ time: RitualTime) -> String {
            let s = steps.filter { $0.ritual == time }.sorted { $0.order < $1.order }
            if s.isEmpty { return "  (no steps set)" }
            return s.map { "  \($0.order + 1). \($0.title) [\($0.domain.title)]" }.joined(separator: "\n")
        }

        let goals = user.goals.isEmpty ? "not specified" : user.goals.joined(separator: ", ")
        let domains = user.domains.map(\.title).joined(separator: ", ")
        let concerns = user.skinConcerns.isEmpty ? "none noted" : user.skinConcerns.joined(separator: ", ")

        return """
        You are the LUMEN advisor — a calm, knowledgeable self-care guide inside the LUMEN app. \
        LUMEN helps people build and keep a daily self-care ritual across five domains: skin, hair, grooming, sleep, and health. \
        It tracks streaks, XP, ranks, medals, the products on the user's shelf, and AM/PM rituals.

        YOUR ROLE:
        - Give practical, honest guidance on the user's rituals, routine order, product usage, ingredient timing, and self-care habits.
        - Ground every answer in the user's ACTUAL shelf and rituals below. Reference their real products by name when relevant.
        - Help them use LUMEN itself (streaks, rituals, shelf, medals, reminders) when asked.
        - Be warm and concise. Prefer a few clear sentences over long lists.

        STRICT SCOPE:
        - ONLY answer questions about self-care (skin, hair, grooming, sleep, health), the user's routine and products, or how the LUMEN app works.
        - If asked anything off-topic (coding, politics, general trivia, math, unrelated chit-chat), politely decline in one sentence and steer back to their rituals or shelf.
        - You are not a doctor. For medical symptoms, allergies, or prescriptions, recommend they consult a professional — never diagnose.

        USER PROFILE:
        - Goals: \(goals)
        - Focus domains: \(domains)
        - Skin type: \(user.skinType.isEmpty ? "unknown" : user.skinType); concerns: \(concerns)
        - Hair type: \(user.hairType.isEmpty ? "unknown" : user.hairType)
        - Current streak: \(user.streak) days; rank: \(user.rank.rawValue)

        THEIR SHELF:
        \(shelfList)

        MORNING RITUAL:
        \(ritual(.am))

        EVENING RITUAL:
        \(ritual(.pm))

        RESPONSE FORMAT — reply with STRICT JSON only, no markdown:
        {"text": string (your reply, plain text), "recommend": [array of 0-2 EXACT product names from the shelf above that are most relevant to this answer; use [] if none]}
        """
    }

    private static func parse(_ raw: String, shelf: [Product]) -> AdvisorReply {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") else {
            return AdvisorReply(text: raw.trimmingCharacters(in: .whitespacesAndNewlines), suggestions: [])
        }
        let json = String(raw[start...end])
        struct Raw: Decodable {
            let text: String
            let recommend: [String]?
        }
        guard let parsed = try? JSONDecoder().decode(Raw.self, from: Data(json.utf8)) else {
            return AdvisorReply(text: raw.trimmingCharacters(in: .whitespacesAndNewlines), suggestions: [])
        }

        let suggestions: [AdvisorSuggestion] = (parsed.recommend ?? []).prefix(2).compactMap { name in
            let needle = name.lowercased()
            guard let product = shelf.first(where: {
                let full = "\($0.brand) \($0.name)".lowercased()
                return full.contains(needle) || $0.name.lowercased().contains(needle)
            }) else { return nil }
            return AdvisorSuggestion(
                name: "\(product.brand) \(product.name)".trimmingCharacters(in: .whitespaces),
                reason: reason(for: product.domain),
                reorderUrl: product.reorderUrl.isEmpty ? "https://example.com/reorder" : product.reorderUrl
            )
        }
        return AdvisorReply(text: parsed.text.trimmingCharacters(in: .whitespacesAndNewlines), suggestions: suggestions)
    }

    // MARK: - Networking

    private static func postChat(body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/v2/vercel/v1/chat/completions") else { throw AdvisorError.empty }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw AdvisorError.empty }
        return data
    }

    private enum AdvisorError: Error { case empty }

    // MARK: - Offline fallback

    /// A calm, neutral on-device responder used when AI is unavailable.
    private static func offlineReply(to question: String, shelf: [Product]) -> AdvisorReply {
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
            return AdvisorReply(text: "For dryness, lead with gentle hydration rather than more active ingredients. Apply moisturiser to slightly damp skin to lock water in, and keep exfoliation to once or twice a week. If you use retinol, buffer it with a moisturiser the first few weeks.", suggestions: pick(.skin))
        }
        if q.contains("acne") || q.contains("break") || q.contains("oily") || q.contains("pore") {
            return AdvisorReply(text: "Consistency beats intensity. Cleanse twice daily, introduce one active at a time, and never skip SPF — many treatments increase sun sensitivity. Give any new step three to four weeks before judging it.", suggestions: pick(.skin))
        }
        if q.contains("sleep") || q.contains("tired") || q.contains("rest") {
            return AdvisorReply(text: "A steady wind-down matters more than any single product. Dim lights an hour before bed, keep screens away, and try magnesium glycinate 30 minutes before sleep. Aim for a consistent wake time, even on weekends.", suggestions: pick(.sleep))
        }
        if q.contains("hair") || q.contains("scalp") || q.contains("frizz") {
            return AdvisorReply(text: "Focus shampoo on the scalp and conditioner on the lengths. If you style with heat, a leave-in plus lower heat will protect more than any single repair product. Less frequent washing often improves texture.", suggestions: pick(.hair))
        }
        if q.contains("beard") || q.contains("shave") || q.contains("groom") {
            return AdvisorReply(text: "Always shave with the grain after warming the skin to reduce irritation. A few drops of oil after keeps the beard soft and the skin underneath calm. Replace blades often — a dull blade causes most razor burn.", suggestions: pick(.grooming))
        }
        if q.contains("order") || q.contains("routine") || q.contains("layer") {
            return AdvisorReply(text: "A simple rule: thinnest to thickest. Cleanse, then water-based serums, then treatments, then moisturiser, and SPF last in the morning. At night, retinol goes after cleansing and before moisturiser.", suggestions: pick(.skin))
        }

        return AdvisorReply(
            text: "Tell me a little about your goal — clearer skin, better sleep, a simpler routine — and I'll tailor a few steps from your shelf. I can help with ingredient order, timing, or how to get the most from your rituals.",
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
