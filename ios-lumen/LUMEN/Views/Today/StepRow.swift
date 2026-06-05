//
//  StepRow.swift
//  LUMEN
//
//  A single ritual step with thumbnail, title, and an animated circular checkbox.
//

import SwiftUI

struct StepRow: View {
    @Environment(\.palette) private var palette
    let step: RitualStep
    let product: Product?
    let isComplete: Bool
    var onToggle: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            onToggle()
        } label: {
            HStack(spacing: Space.m) {
                ProductThumb(product: product, domain: step.domain)
                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title)
                        .font(.ui(16, .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .strikethrough(isComplete, color: palette.textSecondary)
                    HStack(spacing: 6) {
                        Image(systemName: step.domain.symbol).font(.ui(10))
                        Text(step.domain.title.uppercased())
                            .font(.ui(11, .medium)).tracking(0.5)
                        if step.timerSeconds > 0 {
                            Text("· \(step.timerSeconds)s").font(.ui(11))
                        }
                    }
                    .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                checkbox
            }
            .padding(.vertical, Space.s)
            .contentShape(Rectangle())
            .opacity(isComplete ? 0.6 : 1)
        }
        .buttonStyle(.plain)
    }

    private var checkbox: some View {
        ZStack {
            Circle()
                .strokeBorder(isComplete ? Color.clear : palette.hairline, lineWidth: 1.5)
                .frame(width: 28, height: 28)
            if isComplete {
                Circle().fill(palette.gold).frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.ui(13, .bold))
                    .foregroundStyle(Color(hex: 0x1A1306))
            }
        }
        .scaleEffect(isComplete ? 1 : 0.96)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isComplete)
    }
}
