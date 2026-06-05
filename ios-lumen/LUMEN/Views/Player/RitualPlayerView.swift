//
//  RitualPlayerView.swift
//  LUMEN
//
//  Guided, full-screen, one-step-at-a-time ritual experience with per-step
//  timers, a mirror mode, and an XP completion screen.
//

import SwiftUI
import SwiftData

struct RitualPlayerView: View {
    @Environment(\.palette) private var palette
    @Environment(RitualEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    let user: UserState

    @Query(sort: \RitualStep.order) private var allSteps: [RitualStep]
    @Query private var products: [Product]

    @State private var index = 0
    @State private var mirror = false
    @State private var finished = false
    @State private var xpAtStart = 0

    private var ritual: RitualTime {
        Calendar.current.component(.hour, from: Date()) < 14 ? .am : .pm
    }
    private var steps: [RitualStep] { allSteps.filter { $0.ritual == ritual } }
    private func product(_ id: UUID?) -> Product? { products.first { $0.id == id } }

    var body: some View {
        ZStack {
            if mirror {
                CameraProxyView().ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            } else {
                LumenBackground()
            }

            if finished || steps.isEmpty {
                completionScreen
            } else {
                playerContent
            }
        }
        .onAppear {
            xpAtStart = user.xp
            if !steps.isEmpty {
                RitualLiveActivity.shared.start(
                    ritualName: ritual.title,
                    ritualSymbol: ritual.symbol,
                    state: contentState()
                )
            }
        }
        .onDisappear { RitualLiveActivity.shared.end() }
    }

    /// Build the Live Activity state for the current step.
    private func contentState(endDate: Date? = nil) -> RitualActivityAttributes.ContentState {
        guard !steps.isEmpty else {
            return .init(stepTitle: "", stepNumber: 0, totalSteps: 0, domainSymbol: ritual.symbol, timerEndDate: nil)
        }
        let i = min(index, steps.count - 1)
        let step = steps[i]
        return .init(
            stepTitle: step.title,
            stepNumber: i + 1,
            totalSteps: steps.count,
            domainSymbol: step.domain.symbol,
            timerEndDate: endDate
        )
    }

    // MARK: - Player

    private var playerContent: some View {
        let step = steps[min(index, steps.count - 1)]
        return VStack(spacing: 0) {
            topBar
            Spacer()
            VStack(spacing: Space.xl) {
                ProductThumb(product: product(step.productID), domain: step.domain, size: 120)
                    .id(step.id)
                    .transition(.scale.combined(with: .opacity))

                VStack(spacing: Space.s) {
                    Text(step.domain.title.uppercased())
                        .font(.ui(12, .semibold)).tracking(1)
                        .foregroundStyle(palette.accent)
                    Text(step.title)
                        .font(.serif(32, .semibold))
                        .foregroundStyle(mirror ? .white : palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .tracking(-0.4)
                    Text(step.howTo)
                        .font(.ui(16))
                        .foregroundStyle(mirror ? .white.opacity(0.85) : palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, Space.xl)
                }
                .id(step.id)
                .transition(.opacity)

                if step.timerSeconds > 0 {
                    StepTimer(seconds: step.timerSeconds) { endDate in
                        RitualLiveActivity.shared.update(contentState(endDate: endDate))
                    }
                    .id(step.id)
                }
            }
            Spacer()
            dots
            controls
        }
        .padding(.horizontal, Space.l)
        .padding(.bottom, Space.l)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: index)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.ui(16, .semibold))
                    .foregroundStyle(mirror ? .white : palette.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(mirror ? .black.opacity(0.3) : palette.surface1))
            }
            Spacer()
            Text(ritual.title)
                .font(.ui(15, .semibold))
                .foregroundStyle(mirror ? .white : palette.textPrimary)
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { mirror.toggle() }
            } label: {
                Image(systemName: mirror ? "camera.fill" : "camera")
                    .font(.ui(16, .semibold))
                    .foregroundStyle(mirror ? .white : palette.accent)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(mirror ? .black.opacity(0.3) : palette.surface1))
            }
        }
        .padding(.top, Space.s)
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(steps.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? AnyShapeStyle(palette.gold) : AnyShapeStyle(mirror ? Color.white.opacity(0.4) : palette.hairline))
                    .frame(width: i == index ? 22 : 7, height: 7)
                    .animation(.spring, value: index)
            }
        }
        .padding(.bottom, Space.l)
    }

    private var controls: some View {
        HStack(spacing: Space.m) {
            if index > 0 {
                Button {
                    withAnimation { index -= 1 }
                    RitualLiveActivity.shared.update(contentState())
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.ui(16, .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(mirror ? .black.opacity(0.3) : palette.surface1))
                        .overlay(Circle().strokeBorder(palette.hairline, lineWidth: 1))
                }
            }
            GoldButton(title: index == steps.count - 1 ? "Finish ritual" : "Done · Next") {
                advance()
            }
        }
    }

    private func advance() {
        let step = steps[index]
        if !engine.today.isComplete(step) {
            engine.toggle(step, user: user)
        }
        if index == steps.count - 1 {
            withAnimation(.spring) { finished = true }
            RitualLiveActivity.shared.end()
        } else {
            withAnimation { index += 1 }
            RitualLiveActivity.shared.update(contentState())
        }
    }

    // MARK: - Completion

    private var completionScreen: some View {
        VStack(spacing: Space.xl) {
            Spacer()
            ZStack {
                AuraOrb(intensity: 1).frame(width: 200, height: 200)
                Image(systemName: ritual.symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(palette.gold)
            }
            VStack(spacing: Space.s) {
                Text("Ritual complete")
                    .font(.serif(32, .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .tracking(-0.4)
                Text("+\(max(0, user.xp - xpAtStart)) XP earned")
                    .font(.ui(17, .medium))
                    .foregroundStyle(palette.accent)
            }
            HStack(spacing: Space.xl) {
                stat("\(user.streak)", "Streak", "flame.fill")
                stat("\(user.xp)", "Total XP", "sparkles")
                stat(user.rank.rawValue, "Rank", user.rank.symbol)
            }
            Spacer()
            GoldButton(title: "Done") { dismiss() }
        }
        .padding(Space.xl)
    }

    private func stat(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.ui(16)).foregroundStyle(palette.accent)
            Text(value).font(.ui(17, .bold)).foregroundStyle(palette.textPrimary)
            Text(label).font(.ui(11)).foregroundStyle(palette.textSecondary).tracking(0.5).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Step Timer

private struct StepTimer: View {
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    let seconds: Int
    /// Reports the timer's target end date while running, or nil when paused/finished.
    var onTimerChange: (Date?) -> Void
    @State private var remaining: Int
    @State private var endDate: Date?
    @State private var running = false
    @State private var ticker: Timer?

    init(seconds: Int, onTimerChange: @escaping (Date?) -> Void) {
        self.seconds = seconds
        self.onTimerChange = onTimerChange
        _remaining = State(initialValue: seconds)
    }

    var body: some View {
        VStack(spacing: Space.m) {
            ZStack {
                Circle().stroke(palette.hairline, lineWidth: 6).frame(width: 96, height: 96)
                Circle()
                    .trim(from: 0, to: seconds > 0 ? CGFloat(remaining) / CGFloat(seconds) : 0)
                    .stroke(palette.gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 96, height: 96)
                    .animation(.linear(duration: 1), value: remaining)
                Text("\(remaining)")
                    .font(.serif(28, .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .contentTransition(.numericText())
            }
            Button {
                running ? pause() : start()
            } label: {
                Text(running ? "Pause" : (remaining == seconds ? "Start timer" : "Resume"))
                    .font(.ui(14, .semibold))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().strokeBorder(palette.hairline, lineWidth: 1))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { tick() }
        }
        .onDisappear { invalidate() }
    }

    private func start() {
        running = true
        let end = Date().addingTimeInterval(TimeInterval(remaining))
        endDate = end
        onTimerChange(end)
        ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
    }

    /// Recompute the displayed countdown from the target end date so it stays
    /// accurate even after the app returns from the background.
    private func tick() {
        guard running, let endDate else { return }
        let r = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        remaining = r
        if r == 0 { finish() }
    }

    private func pause() {
        running = false
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        onTimerChange(nil)
    }

    private func finish() {
        running = false
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        remaining = 0
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onTimerChange(nil)
    }

    private func invalidate() {
        running = false
        ticker?.invalidate()
        ticker = nil
    }
}
