//
//  MedalDetailSheet.swift
//  LUMEN
//
//  Medal detail with a branded gold share card rendered to an image.
//

import SwiftUI

struct MedalDetailSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let medal: Medal
    let unlocked: Bool
    let user: UserState

    var body: some View {
        VStack(spacing: Space.xl) {
            Capsule().fill(palette.hairline).frame(width: 40, height: 4).padding(.top, Space.m)

            ShareCard(medal: medal, unlocked: unlocked, rank: user.rank)
                .frame(width: 280, height: 360)
                .padding(.top, Space.s)

            VStack(spacing: Space.s) {
                Text(medal.tier.name.uppercased())
                    .font(.ui(11, .semibold)).tracking(2)
                    .foregroundStyle(palette.accent)
                Text(medal.title).font(.serif(26, .semibold)).foregroundStyle(palette.textPrimary)
                Text(medal.detail).font(.ui(15)).foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Space.xl)
            }

            if unlocked {
                let image = renderShareCard()
                ShareLink(item: image, preview: SharePreview("My LUMEN medal", image: image)) {
                    HStack { Image(systemName: "square.and.arrow.up"); Text("Share card") }
                        .font(.ui(16, .semibold)).foregroundStyle(Color(hex: 0x1A1306))
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(palette.gold).clipShape(.rect(cornerRadius: Radius.button))
                }
                .padding(.horizontal, Space.xl)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                    Text("Keep going to unlock this medal.")
                }
                .font(.ui(14)).foregroundStyle(palette.textSecondary)
            }
            Spacer()
        }
        .background(LumenBackground())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    @MainActor private func renderShareCard() -> Image {
        let renderer = ImageRenderer(content:
            ShareCard(medal: medal, unlocked: unlocked, rank: user.rank)
                .frame(width: 600, height: 770)
                .environment(\.palette, palette)
        )
        renderer.scale = 3
        if let ui = renderer.uiImage {
            return Image(uiImage: ui)
        }
        return Image(systemName: "medal.fill")
    }
}

/// The branded gold card shown and shared.
struct ShareCard: View {
    @Environment(\.palette) private var palette
    let medal: Medal
    let unlocked: Bool
    let rank: Rank

    var body: some View {
        ZStack {
            Color(hex: 0x0D0D0F)
            RadialGradient(colors: [palette.accent.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 220)

            VStack(spacing: 22) {
                Text("LUMEN").font(.serif(20, .semibold)).tracking(6).foregroundStyle(Color(hex: 0xC9A86A))
                Spacer()
                MetalMedal(medal: medal, unlocked: unlocked, size: 150, detailed: true)
                VStack(spacing: 8) {
                    Text(medal.title).font(.serif(26, .semibold)).foregroundStyle(Color(hex: 0xF5F3EE))
                    Text(medal.detail).font(.ui(13)).foregroundStyle(Color(hex: 0xA8A29A))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)
                }
                Spacer()
                Text(rank.rawValue.uppercased()).font(.ui(11, .semibold)).tracking(2)
                    .foregroundStyle(Color(hex: 0xC9A86A))
            }
            .padding(28)
        }
        .clipShape(.rect(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Color(hex: 0xC9A86A, alpha: 0.4), lineWidth: 1))
    }
}
