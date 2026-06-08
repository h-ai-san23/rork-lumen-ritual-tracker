//
//  AdvisorView.swift
//  LUMEN
//
//  The AI advisor chat — neutral, helpful guidance plus tappable product cards.
//  Enforces the 3-questions-per-month free limit.
//

import SwiftUI
import SwiftData

struct AdvisorView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    let user: UserState

    @Query private var products: [Product]
    @Query private var steps: [RitualStep]
    @State private var messages: [AdvisorMessage] = [
        AdvisorMessage(isUser: false, text: "I'm your LUMEN advisor. Ask me about your routine, ingredient order, or what to use from your shelf — I'll keep it calm and honest.")
    ]
    @State private var input = ""
    @State private var thinking = false
    @State private var showPaywall = false

    private let freeLimit = 3

    private var remaining: Int { max(0, freeLimit - user.advisorQuestionsThisMonth) }
    private var canAsk: Bool { user.isPremium || remaining > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                LumenBackground()
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: Space.l) {
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
                    inputBar
                }
            }
            .navigationTitle("Advisor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !user.isPremium {
                        Text("\(remaining) left").font(.ui(13, .medium)).foregroundStyle(palette.accent)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView(user: user) }
            .onAppear { resetMonthlyCounterIfNeeded() }
        }
        .tint(palette.accent)
    }

    private func bubble(_ message: AdvisorMessage) -> some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: Space.s) {
            Text(message.text)
                .font(.ui(15))
                .foregroundStyle(message.isUser ? Color(hex: 0x1A1306) : palette.textPrimary)
                .lineSpacing(3)
                .padding(.horizontal, Space.l).padding(.vertical, Space.m)
                .background {
                    if message.isUser { palette.gold }
                    else { palette.surface1 }
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

    private var inputBar: some View {
        VStack(spacing: Space.s) {
            if !canAsk {
                Button { showPaywall = true } label: {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("You've used your 3 free questions. Unlock unlimited advice.")
                            .font(.ui(13, .medium))
                    }
                    .foregroundStyle(palette.accent)
                    .frame(maxWidth: .infinity).padding(.vertical, Space.m)
                    .background(palette.accent.opacity(0.12)).clipShape(.rect(cornerRadius: Radius.button))
                }
            }
            HStack(spacing: Space.s) {
                TextField("Ask your advisor…", text: $input, axis: .vertical)
                    .font(.ui(15)).foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, Space.l).padding(.vertical, 12)
                    .background(palette.surface1).clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(palette.hairline, lineWidth: 1))
                    .disabled(!canAsk)
                Button { send() } label: {
                    Image(systemName: "arrow.up")
                        .font(.ui(16, .bold)).foregroundStyle(Color(hex: 0x1A1306))
                        .frame(width: 44, height: 44).background(palette.gold).clipShape(Circle())
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || !canAsk || thinking)
                .opacity(input.trimmingCharacters(in: .whitespaces).isEmpty || !canAsk ? 0.5 : 1)
            }
        }
        .padding(Space.l)
        .background(.ultraThinMaterial)
    }

    private func send() {
        let question = input.trimmingCharacters(in: .whitespaces)
        guard !question.isEmpty, canAsk else { return }
        input = ""
        messages.append(AdvisorMessage(isUser: true, text: question))
        if !user.isPremium { user.advisorQuestionsThisMonth += 1; try? context.save() }
        thinking = true

        let history = messages
        Task {
            let reply = await AIAdvisor.respond(
                to: question,
                history: history,
                shelf: products,
                steps: steps,
                user: user
            )
            thinking = false
            messages.append(AdvisorMessage(isUser: false, text: reply.text, suggestions: reply.suggestions))
        }
    }

    private func resetMonthlyCounterIfNeeded() {
        let month = Calendar.current.component(.month, from: Date())
        if user.advisorMonthMarker != month {
            user.advisorMonthMarker = month
            user.advisorQuestionsThisMonth = 0
            try? context.save()
        }
    }
}
