//
//  ShelfInsightsView.swift
//  LUMEN
//
//  AI-powered shelf insights for Gold members. Auto-analyses the user's
//  current shelf — surfacing alternatives, redundancies, and gaps — and lets
//  them ask follow-up questions grounded in their real products.
//

import SwiftUI
import SwiftData

struct ShelfInsightsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let user: UserState

    @Query private var products: [Product]
    @Query private var steps: [RitualStep]

    @State private var messages: [AdvisorMessage] = []
    @State private var input = ""
    @State private var thinking = false
    @State private var didAnalyze = false

    /// Quick prompts tailored to evaluating an existing shelf.
    private let starterPrompts: [String] = [
        "Suggest alternatives for my products",
        "Is anything on my shelf redundant?",
        "What am I missing for my goals?",
        "What should I replace first?"
    ]
    private var showStarters: Bool { !thinking && messages.count <= 1 }

    var body: some View {
        NavigationStack {
            ZStack {
                LumenBackground()
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: Space.l) {
                                header
                                ForEach(messages) { message in
                                    bubble(message).id(message.id)
                                }
                                if thinking { typingBubble.id("typing") }
                            }
                            .padding(Space.l)
                        }
                        .onChange(of: messages.count) { _, _ in
                            withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                        }
                    }
                    if showStarters { starterRow }
                    inputBar
                }
            }
            .navigationTitle("Shelf Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(palette.accent)
                }
            }
            .task { await analyzeIfNeeded() }
        }
        .tint(palette.accent)
    }

    private var header: some View {
        HStack(spacing: Space.m) {
            Image(systemName: "sparkles")
                .font(.ui(18, .semibold)).foregroundStyle(Color(hex: 0x1A1306))
                .frame(width: 44, height: 44).background(palette.gold).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Analysing \(products.count) product\(products.count == 1 ? "" : "s")")
                    .font(.ui(15, .semibold)).foregroundStyle(palette.textPrimary)
                Text("Personalised to your shelf and goals")
                    .font(.ui(12)).foregroundStyle(palette.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bubble(_ message: AdvisorMessage) -> some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: Space.s) {
            Text(message.text)
                .font(.ui(15))
                .foregroundStyle(message.isUser ? Color(hex: 0x1A1306) : palette.textPrimary)
                .lineSpacing(3)
                .padding(.horizontal, Space.l).padding(.vertical, Space.m)
                .background {
                    if message.isUser { palette.gold } else { palette.surface1 }
                }
                .clipShape(.rect(cornerRadius: 18))
                .overlay {
                    if !message.isUser {
                        RoundedRectangle(cornerRadius: 18).strokeBorder(palette.hairline, lineWidth: 1)
                    }
                }
                .frame(maxWidth: 300, alignment: message.isUser ? .trailing : .leading)

            ForEach(message.suggestions) { s in
                suggestionCard(s)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }

    private func suggestionCard(_ s: AdvisorSuggestion) -> some View {
        Link(destination: URL(string: s.reorderUrl) ?? URL(string: "https://example.com")!) {
            HStack(spacing: Space.m) {
                Image(systemName: "bag.fill").font(.ui(14)).foregroundStyle(palette.accent)
                    .frame(width: 38, height: 38).background(Circle().fill(palette.surface2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name).font(.ui(14, .semibold)).foregroundStyle(palette.textPrimary).lineLimit(1)
                    Text(s.reason).font(.ui(12)).foregroundStyle(palette.textSecondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.ui(12)).foregroundStyle(palette.textSecondary)
            }
            .padding(Space.m)
            .background(palette.surface1)
            .clipShape(.rect(cornerRadius: Radius.tile))
            .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(palette.hairline, lineWidth: 1))
            .frame(maxWidth: 300)
        }
    }

    private var typingBubble: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle().fill(palette.accent).frame(width: 7, height: 7)
                    .opacity(thinking ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: thinking)
            }
        }
        .padding(.horizontal, Space.l).padding(.vertical, Space.m)
        .background(palette.surface1).clipShape(.rect(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var starterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                ForEach(starterPrompts, id: \.self) { prompt in
                    Button { send(prompt) } label: {
                        Text(prompt)
                            .font(.ui(13, .medium))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                            .padding(.horizontal, Space.l).padding(.vertical, 10)
                            .background(palette.surface1)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(palette.hairline, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, Space.l)
        }
        .padding(.bottom, Space.s)
    }

    private var inputBar: some View {
        HStack(spacing: Space.s) {
            TextField("Ask about your shelf…", text: $input, axis: .vertical)
                .font(.ui(15)).foregroundStyle(palette.textPrimary)
                .padding(.horizontal, Space.l).padding(.vertical, 12)
                .background(palette.surface1).clipShape(Capsule())
                .overlay(Capsule().strokeBorder(palette.hairline, lineWidth: 1))
            Button { send() } label: {
                Image(systemName: "arrow.up")
                    .font(.ui(16, .bold)).foregroundStyle(Color(hex: 0x1A1306))
                    .frame(width: 44, height: 44).background(palette.gold).clipShape(Circle())
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
            .opacity(input.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(Space.l)
        .background(.ultraThinMaterial)
    }

    private func analyzeIfNeeded() async {
        guard !didAnalyze else { return }
        didAnalyze = true
        guard !products.isEmpty else {
            messages.append(AdvisorMessage(isUser: false, text: "Your shelf is empty. Add a few products and I'll review your routine — spotting alternatives, redundancies, and anything you might be missing."))
            return
        }
        thinking = true
        let prompt = "Review my current shelf as a whole. Briefly note what's working, flag anything redundant or expiring, and suggest 1–2 alternatives or additions that fit my goals. Keep it concise."
        let reply = await AIAdvisor.respond(to: prompt, history: [], shelf: products, steps: steps, user: user)
        thinking = false
        messages.append(AdvisorMessage(isUser: false, text: reply.text, suggestions: reply.suggestions))
    }

    private func send(_ preset: String? = nil) {
        let question = (preset ?? input).trimmingCharacters(in: .whitespaces)
        guard !question.isEmpty else { return }
        input = ""
        messages.append(AdvisorMessage(isUser: true, text: question))
        thinking = true

        let history = messages
        Task {
            let reply = await AIAdvisor.respond(to: question, history: history, shelf: products, steps: steps, user: user)
            thinking = false
            messages.append(AdvisorMessage(isUser: false, text: reply.text, suggestions: reply.suggestions))
        }
    }
}
