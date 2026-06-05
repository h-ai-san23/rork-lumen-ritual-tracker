//
//  Components.swift
//  LUMEN
//
//  Reusable building blocks: cards, gold buttons, pills, hairlines, section headers.
//

import SwiftUI

// MARK: - Card

struct LumenCard<Content: View>: View {
    @Environment(\.palette) private var palette
    var padding: CGFloat = Space.l
    var cornerRadius: CGFloat = Radius.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface1)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(palette.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(palette.isDark ? 0.35 : 0.06), radius: 24, y: 10)
    }
}

// MARK: - Gold Button

struct GoldButton: View {
    @Environment(\.palette) private var palette
    let title: String
    var systemImage: String? = nil
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: Space.s) {
                Text(title)
                    .font(.ui(17, .semibold))
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.ui(15, .bold))
                }
            }
            .foregroundStyle(Color(hex: 0x1A1306))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(palette.gold)
            .clipShape(.rect(cornerRadius: Radius.button))
            .shadow(color: palette.goldDark.opacity(0.45), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

struct GhostButton: View {
    @Environment(\.palette) private var palette
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.ui(16, .medium))
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button)
                        .strokeBorder(palette.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pills

struct Pill: View {
    @Environment(\.palette) private var palette
    let text: String
    var systemImage: String? = nil
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.ui(12, .semibold))
            }
            Text(text).font(.ui(13, .medium))
        }
        .foregroundStyle(selected ? Color(hex: 0x1A1306) : palette.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            if selected {
                Capsule().fill(palette.gold)
            } else {
                Capsule().strokeBorder(palette.hairline, lineWidth: 1)
            }
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    @Environment(\.palette) private var palette
    let title: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "See all"

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.serif(22, .medium))
                .foregroundStyle(palette.textPrimary)
                .tracking(-0.4)
            Spacer()
            if let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.ui(14, .medium))
                        .foregroundStyle(palette.accent)
                }
            }
        }
    }
}

// MARK: - Hairline

struct Hairline: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Rectangle()
            .fill(palette.hairline)
            .frame(height: 1)
    }
}

// MARK: - Lock Badge

struct LockBadge: View {
    @Environment(\.palette) private var palette
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill").font(.ui(10, .bold))
            Text("GOLD").font(.ui(10, .bold)).tracking(0.5)
        }
        .foregroundStyle(palette.goldDark)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(palette.accent.opacity(0.15)))
    }
}
