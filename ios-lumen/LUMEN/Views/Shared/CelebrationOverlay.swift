//
//  CelebrationOverlay.swift
//  LUMEN
//
//  Listens to the engine's pending celebration and presents confetti +
//  a glass banner for milestones, freezes, and medal unlocks.
//

import SwiftUI

struct CelebrationOverlay: View {
    @Environment(\.palette) private var palette
    @Bindable var engine: RitualEngine

    @State private var showConfetti = false
    @State private var banner: BannerInfo?

    struct BannerInfo: Equatable {
        let title: String
        let subtitle: String
        let symbol: String
        let big: Bool
    }

    var body: some View {
        ZStack {
            if showConfetti {
                GoldConfettiView()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            if let banner {
                bannerView(banner)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: banner)
        .onChange(of: engine.pendingCelebration) { _, event in
            guard let event else { return }
            present(event)
        }
    }

    private func bannerView(_ info: BannerInfo) -> some View {
        VStack(spacing: Space.m) {
            Image(systemName: info.symbol)
                .font(.system(size: info.big ? 52 : 36))
                .foregroundStyle(palette.gold)
                .symbolEffect(.bounce, value: info.title)
                .goldShimmer()
            Text(info.title)
                .font(.serif(info.big ? 28 : 22, .semibold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .tracking(-0.3)
            Text(info.subtitle)
                .font(.ui(15))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.xl)
        .frame(maxWidth: 320)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
        .padding(Space.xl)
    }

    private func present(_ event: UnlockEvent) {
        let info: BannerInfo
        switch event {
        case .perfectDay:
            info = BannerInfo(title: "Ritual Complete", subtitle: "Your day is whole. Rest well.", symbol: "checkmark.seal.fill", big: false)
        case .medal(let id):
            let medal = Medal.by(id: id)
            info = BannerInfo(title: medal?.title ?? "Medal Unlocked", subtitle: medal?.detail ?? "A new medal joins your case.", symbol: medal?.symbol ?? "medal.fill", big: true)
        case .rankUp(let rank):
            info = BannerInfo(title: rank.rawValue, subtitle: "You've risen to a new rank.", symbol: rank.symbol, big: true)
        case .streakMilestone(let n):
            info = BannerInfo(title: "\(n)-Day Streak", subtitle: "Devotion, made visible.", symbol: "flame.fill", big: true)
        case .freezeEarned:
            info = BannerInfo(title: "Streak Freeze Earned", subtitle: "One missed day won't break your streak.", symbol: "snowflake", big: false)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { banner = info; showConfetti = info.big }

        DispatchQueue.main.asyncAfter(deadline: .now() + (info.big ? 2.8 : 2.0)) {
            withAnimation { banner = nil; showConfetti = false }
            engine.pendingCelebration = nil
        }
    }
}
