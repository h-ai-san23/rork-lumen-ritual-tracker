//
//  OnboardingView.swift
//  LUMEN
//
//  First-launch flow: one question per screen, large serif prompts,
//  finishing with an animated "Your ritual is ready" reveal.
//

import SwiftUI
import SwiftData
import AuthenticationServices

struct OnboardingView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(AuthManager.self) private var auth
    let user: UserState
    var onFinish: () -> Void

    @State private var stepIndex = 0
    @State private var selectedDomains: Set<Domain> = [.skin, .sleep, .health]
    @State private var skinType = ""
    @State private var skinConcerns: Set<String> = []
    @State private var hairType = ""
    @State private var groomingFocus = ""
    @State private var sleepGoal: Double = 8
    @State private var healthHabits: Set<String> = []
    @State private var wake = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var windDown = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var revealing = false

    private enum Step: Equatable {
        case welcome, domains, skinType, skinConcerns, hairType, grooming, sleep, health, times, account, reveal
    }

    private var steps: [Step] {
        var s: [Step] = [.welcome, .domains]
        if selectedDomains.contains(.skin) { s += [.skinType, .skinConcerns] }
        if selectedDomains.contains(.hair) { s.append(.hairType) }
        if selectedDomains.contains(.grooming) { s.append(.grooming) }
        if selectedDomains.contains(.sleep) { s.append(.sleep) }
        if selectedDomains.contains(.health) { s.append(.health) }
        s += [.times, .account, .reveal]
        return s
    }

    private var current: Step { steps[min(stepIndex, steps.count - 1)] }
    private var progress: Double { Double(stepIndex) / Double(max(1, steps.count - 1)) }

    var body: some View {
        ZStack {
            LumenBackground()

            VStack(spacing: 0) {
                if current != .welcome && current != .reveal {
                    progressBar
                        .padding(.horizontal, Space.xl)
                        .padding(.top, Space.s)
                }

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(current)

                footer
                    .padding(.horizontal, Space.xl)
                    .padding(.bottom, Space.l)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: stepIndex)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.hairline).frame(height: 3)
                Capsule().fill(palette.gold)
                    .frame(width: geo.size.width * progress, height: 3)
                    .animation(.spring(response: 0.5), value: progress)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Content per step

    @ViewBuilder private var content: some View {
        switch current {
        case .welcome: welcomeStep
        case .domains: domainStep
        case .skinType: choiceStep(
            title: "How does your skin behave?",
            options: ["Oily", "Dry", "Combination", "Sensitive", "Balanced"],
            selection: $skinType)
        case .skinConcerns: multiStep(
            title: "What would you like to improve?",
            subtitle: "Choose any that apply.",
            options: ["Breakouts", "Dullness", "Fine lines", "Texture", "Redness", "Dark spots"],
            selection: $skinConcerns)
        case .hairType: choiceStep(
            title: "Tell me about your hair.",
            options: ["Straight", "Wavy", "Curly", "Coily", "Fine", "Thick"],
            selection: $hairType)
        case .grooming: choiceStep(
            title: "Your grooming focus?",
            options: ["Clean shave", "Beard care", "Trim & maintain", "Skin first"],
            selection: $groomingFocus)
        case .sleep: sleepStep
        case .health: multiStep(
            title: "Which habits matter to you?",
            subtitle: "We'll fold these into your ritual.",
            options: ["Hydration", "Supplements", "Movement", "Mindfulness", "Less screen time"],
            selection: $healthHabits)
        case .times: timesStep
        case .account: accountStep
        case .reveal: revealStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: Space.xl) {
            Spacer()
            AuraOrb(intensity: 0.8).frame(width: 140, height: 140)
            VStack(spacing: Space.m) {
                Text("LUMIRA")
                    .font(.serif(40, .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .tracking(4)
                Text("Five rituals. One quiet practice.\nLet's build yours.")
                    .font(.ui(17))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            Spacer()
        }
        .padding(Space.xl)
    }

    private var domainStep: some View {
        StepScaffold(title: "Which rituals will you build?", subtitle: "Choose what matters. You can change this later.") {
            VStack(spacing: Space.m) {
                ForEach(Domain.allCases) { domain in
                    let on = selectedDomains.contains(domain)
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        if on { selectedDomains.remove(domain) } else { selectedDomains.insert(domain) }
                    } label: {
                        HStack(spacing: Space.l) {
                            Image(systemName: domain.symbol)
                                .font(.ui(18))
                                .foregroundStyle(on ? Color(hex: 0x1A1306) : palette.accent)
                                .frame(width: 44, height: 44)
                                .background {
                                    if on { Circle().fill(palette.gold) }
                                    else { Circle().strokeBorder(palette.hairline, lineWidth: 1) }
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(domain.title).font(.ui(17, .semibold)).foregroundStyle(palette.textPrimary)
                                Text(domain.blurb).font(.ui(13)).foregroundStyle(palette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? palette.accent : palette.hairline)
                        }
                        .padding(Space.m)
                        .background(palette.surface1)
                        .clipShape(.rect(cornerRadius: Radius.tile))
                        .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(on ? palette.accent.opacity(0.4) : palette.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func choiceStep(title: String, options: [String], selection: Binding<String>) -> some View {
        StepScaffold(title: title) {
            FlowChips(options: options, isSelected: { selection.wrappedValue == $0 }) { opt in
                UISelectionFeedbackGenerator().selectionChanged()
                selection.wrappedValue = opt
            }
        }
    }

    private func multiStep(title: String, subtitle: String, options: [String], selection: Binding<Set<String>>) -> some View {
        StepScaffold(title: title, subtitle: subtitle) {
            FlowChips(options: options, isSelected: { selection.wrappedValue.contains($0) }) { opt in
                UISelectionFeedbackGenerator().selectionChanged()
                if selection.wrappedValue.contains(opt) { selection.wrappedValue.remove(opt) }
                else { selection.wrappedValue.insert(opt) }
            }
        }
    }

    private var sleepStep: some View {
        StepScaffold(title: "Your nightly sleep goal?") {
            VStack(spacing: Space.xl) {
                Text(String(format: "%.1f hrs", sleepGoal))
                    .font(.serif(48, .semibold))
                    .foregroundStyle(palette.textPrimary)
                Slider(value: $sleepGoal, in: 5...10, step: 0.5)
                    .tint(palette.accent)
            }
            .padding(.top, Space.l)
        }
    }

    private var timesStep: some View {
        StepScaffold(title: "When do your days begin and end?", subtitle: "We'll gently remind you at these times.") {
            VStack(spacing: Space.l) {
                timeRow(title: "Wake", symbol: "sun.max.fill", selection: $wake)
                timeRow(title: "Wind down", symbol: "moon.fill", selection: $windDown)
            }
        }
    }

    private func timeRow(title: String, symbol: String, selection: Binding<Date>) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(palette.accent)
            Text(title).font(.ui(17, .medium)).foregroundStyle(palette.textPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(palette.accent)
        }
        .padding(Space.l)
        .background(palette.surface1)
        .clipShape(.rect(cornerRadius: Radius.tile))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(palette.hairline, lineWidth: 1))
    }

    private var accountStep: some View {
        @Bindable var auth = auth
        return ScrollView {
            VStack(spacing: Space.xl) {
                VStack(spacing: Space.m) {
                    ZStack {
                        Circle().fill(palette.gold.opacity(0.18)).frame(width: 92, height: 92)
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 40))
                            .foregroundStyle(palette.gold)
                    }
                    Text("Save your progress")
                        .font(.serif(30, .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .tracking(-0.4)
                    Text("Create an account to keep your rituals, streaks and progress safe — and sync across your devices.")
                        .font(.ui(16))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, Space.m)
                }
                .padding(.top, Space.xl)

                if let signedIn = auth.user {
                    signedInBadge(name: signedIn.name ?? signedIn.email)
                } else {
                    VStack(spacing: Space.m) {
                        SignInWithAppleButton(.signUp) { request in
                            request.requestedScopes = [.email, .fullName]
                        } onCompletion: { _ in
                            Task { await auth.signIn(provider: "apple") }
                        }
                        .signInWithAppleButtonStyle(palette.isDark ? .white : .black)
                        .frame(height: 52)
                        .clipShape(.rect(cornerRadius: Radius.tile))
                        .disabled(auth.isSigningIn)

                        Button {
                            Task { await auth.signIn(provider: "google") }
                        } label: {
                            HStack(spacing: Space.s) {
                                Image(systemName: "globe")
                                Text("Continue with Google").font(.ui(17, .semibold))
                            }
                            .foregroundStyle(palette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(palette.surface1)
                            .clipShape(.rect(cornerRadius: Radius.tile))
                            .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(palette.hairline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(auth.isSigningIn)

                        if auth.isSigningIn {
                            ProgressView().tint(palette.accent).padding(.top, Space.s)
                        }
                    }
                    .padding(.horizontal, Space.xl)
                }
            }
            .padding(.horizontal, Space.xl)
        }
        .alert("Sign in failed", isPresented: $auth.showError) {
            Button("OK") {}
        } message: {
            Text(auth.errorMessage)
        }
        .onChange(of: auth.user?.id) { _, id in
            if id != nil {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                advance()
            }
        }
    }

    private func signedInBadge(name: String) -> some View {
        HStack(spacing: Space.m) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.accent).font(.ui(22))
            VStack(alignment: .leading, spacing: 2) {
                Text("Signed in").font(.ui(13)).foregroundStyle(palette.textSecondary)
                Text(name).font(.ui(16, .semibold)).foregroundStyle(palette.textPrimary).lineLimit(1)
            }
            Spacer()
        }
        .padding(Space.l)
        .background(palette.surface1)
        .clipShape(.rect(cornerRadius: Radius.tile))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(palette.accent.opacity(0.4), lineWidth: 1))
        .padding(.horizontal, Space.xl)
    }

    private var revealStep: some View {
        VStack(spacing: Space.xl) {
            Spacer()
            ZStack {
                AuraOrb(intensity: 1).frame(width: 180, height: 180)
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(palette.gold)
                    .symbolEffect(.variableColor.iterative)
            }
            .scaleEffect(revealing ? 1 : 0.6)
            .opacity(revealing ? 1 : 0)

            VStack(spacing: Space.m) {
                Text("Your ritual is ready.")
                    .font(.serif(32, .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .tracking(-0.4)
                Text("We've assembled a morning and evening practice from your answers. Refine it any time.")
                    .font(.ui(16))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(revealing ? 1 : 0)
            .offset(y: revealing ? 0 : 16)
            Spacer()
        }
        .padding(Space.xl)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { revealing = true }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: Space.s) {
            GoldButton(title: primaryTitle, systemImage: current == .reveal ? nil : "arrow.right") {
                advance()
            }
            .disabled(current == .domains && selectedDomains.isEmpty)
            .opacity(current == .domains && selectedDomains.isEmpty ? 0.5 : 1)

            if canSkip {
                Button("Skip for now") { advance() }
                    .font(.ui(14))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var primaryTitle: String {
        switch current {
        case .welcome: "Begin"
        case .account: auth.user == nil ? "Maybe later" : "Continue"
        case .reveal: "Enter Lumira"
        default: "Continue"
        }
    }

    private var canSkip: Bool {
        [.skinConcerns, .health].contains(current)
    }

    private func advance() {
        if current == .reveal {
            finish()
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { stepIndex = min(stepIndex + 1, steps.count - 1) }
    }

    private func finish() {
        user.selectedDomains = selectedDomains.sorted { $0.rawValue < $1.rawValue }.map(\.rawValue)
        user.skinType = skinType
        user.skinConcerns = Array(skinConcerns)
        user.hairType = hairType
        user.groomingFocus = groomingFocus
        user.sleepGoal = sleepGoal
        user.goals = Array(healthHabits)
        user.wakeTime = wake
        user.windDownTime = windDown

        let domains = selectedDomains.sorted { $0.rawValue < $1.rawValue }
        _ = SeedData.buildRitual(for: domains, in: context)
        let steps = (try? context.fetch(FetchDescriptor<RitualStep>())) ?? []
        SeedData.seedHistory(steps: steps, user: user, in: context)

        user.onboardingComplete = true
        try? context.save()

        Task {
            await NotificationManager.requestAuthorization()
            NotificationManager.scheduleReminders(wake: wake, windDown: windDown, enabled: true)
        }
        onFinish()
    }
}

// MARK: - Reusable step scaffold

private struct StepScaffold<Content: View>: View {
    @Environment(\.palette) private var palette
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(title)
                        .font(.serif(30, .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .tracking(-0.5)
                        .lineSpacing(2)
                    if let subtitle {
                        Text(subtitle)
                            .font(.ui(16))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                content
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.xxl)
        }
    }
}

private struct FlowChips: View {
    @Environment(\.palette) private var palette
    let options: [String]
    let isSelected: (String) -> Bool
    let onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: Space.m) {
            ForEach(options, id: \.self) { opt in
                Button { onTap(opt) } label: {
                    Text(opt)
                        .font(.ui(15, .medium))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(isSelected(opt) ? Color(hex: 0x1A1306) : palette.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background {
                            if isSelected(opt) { Capsule().fill(palette.gold) }
                            else { Capsule().strokeBorder(palette.hairline, lineWidth: 1) }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A simple wrapping flow layout: each subview keeps its natural width and
/// wraps to the next line when it runs out of horizontal room.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width - bounds.minX > maxWidth {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
