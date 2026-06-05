//
//  AchievementsView.swift
//  LUMEN
//
//  Trophy case of gold medals + Ritual Rank insignia and a share card.
//

import SwiftUI

struct AchievementsView: View {
    @Environment(\.palette) private var palette
    let user: UserState

    @State private var selected: Medal?
    private let columns = [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)]

    private var unlockedCount: Int { user.medalsUnlocked.count }

    var body: some View {
        NavigationStack {
            ZStack {
                LumenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        rankCard
                        VStack(alignment: .leading, spacing: Space.m) {
                            HStack {
                                SectionHeader(title: "Medals")
                                Spacer()
                                Text("\(unlockedCount)/\(Medal.all.count)")
                                    .font(.ui(14, .medium)).foregroundStyle(palette.textSecondary)
                            }
                            LazyVGrid(columns: columns, spacing: Space.l) {
                                ForEach(Medal.all) { medal in
                                    MedalTile(medal: medal, unlocked: user.medalsUnlocked.contains(medal.id))
                                        .onTapGesture {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            selected = medal
                                        }
                                }
                            }
                        }
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                }
            }
            .navigationTitle("Achievements")
            .sheet(item: $selected) { medal in
                MedalDetailSheet(medal: medal, unlocked: user.medalsUnlocked.contains(medal.id), user: user)
            }
        }
        .tint(palette.accent)
    }

    private var rankCard: some View {
        let rank = user.rank
        let next = rank.next
        let lower = rank.threshold
        let upper = next?.threshold ?? rank.threshold
        let progress = next != nil ? Double(user.xp - lower) / Double(max(1, upper - lower)) : 1
        return LumenCard {
            VStack(spacing: Space.l) {
                HStack(spacing: Space.l) {
                    ZStack {
                        Circle().fill(palette.gold).frame(width: 64, height: 64)
                            .shadow(color: palette.accent.opacity(0.5), radius: 12)
                        Image(systemName: rank.symbol)
                            .font(.system(size: 28)).foregroundStyle(Color(hex: 0x1A1306))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RITUAL RANK").font(.ui(11, .semibold)).tracking(1).foregroundStyle(palette.textSecondary)
                        Text(rank.rawValue).font(.serif(28, .semibold)).foregroundStyle(palette.textPrimary)
                        Text("\(user.xp) XP").font(.ui(14)).foregroundStyle(palette.accent)
                    }
                    Spacer()
                }
                if let next {
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(palette.hairline).frame(height: 6)
                                Capsule().fill(palette.gold).frame(width: geo.size.width * max(0.02, min(1, progress)), height: 6)
                            }
                        }
                        .frame(height: 6)
                        Text("\(upper - user.xp) XP to \(next.rawValue)")
                            .font(.ui(12)).foregroundStyle(palette.textSecondary)
                    }
                }
            }
        }
    }
}

struct MedalTile: View {
    @Environment(\.palette) private var palette
    let medal: Medal
    let unlocked: Bool

    var body: some View {
        VStack(spacing: Space.s) {
            MetalMedal(medal: medal, unlocked: unlocked, size: 78)
            Text(medal.title)
                .font(.ui(11.5, .semibold))
                .foregroundStyle(unlocked ? palette.textPrimary : palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 30, alignment: .top)
        }
    }
}
