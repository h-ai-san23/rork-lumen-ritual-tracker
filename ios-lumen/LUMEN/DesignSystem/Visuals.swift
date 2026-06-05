//
//  Visuals.swift
//  LUMEN
//
//  Signature visual elements: the Ritual Ring, the Aura orb, gold confetti,
//  shimmer, and the medal share card.
//

import SwiftUI

// MARK: - Ritual Ring

struct RitualRing: View {
    @Environment(\.palette) private var palette
    var progress: Double
    var lineWidth: CGFloat = 16
    var size: CGFloat = 220

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.hairline, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    palette.gold,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: palette.accent.opacity(0.5), radius: 12)
                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Aura Orb

/// A soft glowing orb that radiates outward as completion rises — dim at 0%,
/// fully luminous at 100%.
struct AuraOrb: View {
    @Environment(\.palette) private var palette
    var intensity: Double // 0...1
    @State private var pulse = false

    /// Eased glow so early check-offs already feel rewarding.
    private var glow: Double { pow(max(0, min(1, intensity)), 0.7) }

    var body: some View {
        ZStack {
            // Outer halo grows and brightens with progress.
            Circle()
                .fill(palette.goldRadial)
                .opacity(0.12 + glow * 0.7)
                .blur(radius: 34)
                .scaleEffect((0.7 + glow * 0.35) * (pulse ? 1.06 : 0.98))
            // Mid bloom for depth.
            Circle()
                .fill(palette.goldRadial)
                .opacity(0.15 + glow * 0.5)
                .blur(radius: 18)
                .frame(width: 150, height: 150)
                .scaleEffect((0.8 + glow * 0.3) * (pulse ? 1.05 : 0.97))
            // Bright core.
            Circle()
                .fill(palette.gold)
                .opacity(0.35 + glow * 0.55)
                .blur(radius: 8)
                .frame(width: 60, height: 60)
                .scaleEffect((0.7 + glow * 0.5) * (pulse ? 1.05 : 0.95))
        }
        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pulse)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: intensity)
        .onAppear { pulse = true }
    }
}

// MARK: - Shimmer (streak milestones)

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width * 1.6)
                    .mask(content)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func goldShimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Confetti

private struct Fleck: Identifiable {
    let id = UUID()
    let x: CGFloat
    let delay: Double
    let duration: Double
    let size: CGFloat
    let rotation: Double
}

struct GoldConfettiView: View {
    @Environment(\.palette) private var palette
    @State private var animate = false
    private let flecks: [Fleck] = (0..<60).map { _ in
        Fleck(
            x: CGFloat.random(in: 0...1),
            delay: Double.random(in: 0...0.5),
            duration: Double.random(in: 1.6...3.0),
            size: CGFloat.random(in: 4...9),
            rotation: Double.random(in: 0...360)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(flecks) { f in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(palette.gold)
                        .frame(width: f.size, height: f.size * 0.5)
                        .rotationEffect(.degrees(f.rotation + (animate ? 360 : 0)))
                        .position(
                            x: f.x * geo.size.width,
                            y: animate ? geo.size.height + 40 : -40
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeIn(duration: f.duration).delay(f.delay),
                            value: animate
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}
