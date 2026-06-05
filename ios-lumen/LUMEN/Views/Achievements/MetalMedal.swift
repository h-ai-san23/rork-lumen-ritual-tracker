//
//  MetalMedal.swift
//  LUMEN
//
//  A high-fidelity 3D metallic medallion that catches the light and shimmers
//  as the device tilts, driven by CoreMotion.
//

import SwiftUI
import CoreMotion

// MARK: - Motion source

/// A single shared device-motion source so dozens of medals can react to tilt
/// without each spinning up its own `CMMotionManager`.
@MainActor
@Observable
final class MedalMotion {
    static let shared = MedalMotion()

    /// Normalised tilt, roughly -1...1 on each axis.
    private(set) var roll: Double = 0.25
    private(set) var pitch: Double = -0.15

    private let manager = CMMotionManager()
    private var subscribers = 0

    private init() {}

    func start() {
        subscribers += 1
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 24.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let r = max(-1, min(1, motion.attitude.roll / (.pi / 4)))
            let p = max(-1, min(1, motion.attitude.pitch / (.pi / 4)))
            withAnimation(.easeOut(duration: 0.18)) {
                self.roll = r
                self.pitch = p
            }
        }
    }

    func stop() {
        subscribers = max(0, subscribers - 1)
        if subscribers == 0 { manager.stopDeviceMotionUpdates() }
    }
}

// MARK: - Metallic medal

struct MetalMedal: View {
    let medal: Medal
    var unlocked: Bool = true
    var size: CGFloat = 72
    /// Detailed medals add a glow halo and heavier sheen for hero/share contexts.
    var detailed: Bool = false

    @State private var motion = MedalMotion.shared
    /// Continuous shimmer phase for a slow travelling sheen, independent of tilt.
    @State private var shimmer = false

    private var tier: MedalTier { medal.tier }
    private var roll: Double { unlocked ? motion.roll : 0 }
    private var pitch: Double { unlocked ? motion.pitch : 0 }

    /// Where the specular hotspot sits, following the tilt of the device.
    private var highlight: UnitPoint {
        UnitPoint(x: 0.5 + roll * 0.32, y: 0.4 - pitch * 0.32)
    }

    var body: some View {
        ZStack {
            if detailed && unlocked { glow }
            disc
            if unlocked { sheen }
            emblem
            rimLight
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .shadow(color: .black.opacity(unlocked ? 0.45 : 0.25), radius: size * 0.12, y: size * 0.06)
        .saturation(unlocked ? 1 : 0.15)
        .opacity(unlocked ? 1 : 0.55)
        .onAppear {
            if unlocked { MedalMotion.shared.start() }
            if detailed {
                withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) { shimmer = true }
            }
        }
        .onDisappear { if unlocked { MedalMotion.shared.stop() } }
    }

    // MARK: Layers

    /// Soft coloured halo behind the medal.
    private var glow: some View {
        Circle()
            .fill(RadialGradient(colors: [tier.glow.opacity(0.7), .clear], center: .center, startRadius: 0, endRadius: size * 0.75))
            .blur(radius: size * 0.18)
            .scaleEffect(1.5)
            .offset(x: roll * size * 0.08, y: pitch * size * 0.08)
    }

    /// The metal body: a fluted rim ring plus a recessed face.
    private var disc: some View {
        ZStack {
            // Outer fluted rim.
            Circle()
                .fill(metalGradient)
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(colors: [tier.rim.opacity(0.9), tier.metal[2].opacity(0.6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: size * 0.035)
                )
                .overlay(fluting)

            // Recessed inner face.
            Circle()
                .fill(faceGradient)
                .overlay(Circle().strokeBorder(tier.metal[2].opacity(0.55), lineWidth: max(1, size * 0.012)))
                .padding(size * 0.16)
                .shadow(color: .black.opacity(0.35), radius: size * 0.02)
        }
    }

    /// Angular metal gradient that "turns" with roll, plus a vertical light bias.
    private var metalGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                tier.metal[1], tier.metal[0], tier.metal[2], tier.metal[1], tier.metal[0], tier.metal[2], tier.metal[1],
            ]),
            center: .center,
            angle: .degrees(roll * 28 - 90)
        )
    }

    private var faceGradient: RadialGradient {
        RadialGradient(colors: [tier.metal[0].opacity(0.95), tier.metal[1], tier.metal[2]],
                       center: highlight, startRadius: 0, endRadius: size * 0.5)
    }

    /// Thin radial "flutes" around the rim for a coin-like edge.
    private var fluting: some View {
        ZStack {
            ForEach(0..<48, id: \.self) { i in
                Capsule()
                    .fill(tier.metal[2].opacity(0.28))
                    .frame(width: max(0.6, size * 0.01), height: size * 0.07)
                    .offset(y: -size * 0.46)
                    .rotationEffect(.degrees(Double(i) / 48 * 360))
            }
        }
        .mask(Circle().strokeBorder(lineWidth: size * 0.08).padding(size * 0.005))
        .opacity(0.6)
    }

    /// The embossed symbol with a light-from-above engrave effect.
    private var emblem: some View {
        Image(systemName: medal.symbol)
            .font(.system(size: size * 0.34, weight: .black))
            .foregroundStyle(
                LinearGradient(colors: [tier.emblem.opacity(0.65), tier.emblem],
                               startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: tier.rim.opacity(0.7), radius: 0, x: 0, y: -max(0.5, size * 0.008))
            .shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: max(0.5, size * 0.01))
    }

    /// A travelling glass sheen + a tilt-tracked specular hotspot.
    private var sheen: some View {
        ZStack {
            // Specular hotspot that chases the tilt.
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.85), .white.opacity(0.05), .clear],
                                     center: .center, startRadius: 0, endRadius: size * 0.34))
                .frame(width: size * 0.6, height: size * 0.6)
                .position(x: size * highlight.x, y: size * highlight.y)
                .blendMode(.screen)
                .opacity(0.55 + abs(roll) * 0.25)

            // Glassy top reflection arc.
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.4), .clear],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.66, height: size * 0.34)
                .offset(y: -size * 0.18)
                .blendMode(.screen)
                .opacity(0.6)

            // Diagonal shimmer band sweeping across (detailed only).
            if detailed {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, tier.rim.opacity(0.85), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: size * 0.45)
                    .rotationEffect(.degrees(22))
                    .offset(x: (shimmer ? 1.3 : -1.3) * size)
                    .blendMode(.screen)
            }
        }
        .mask(Circle())
        .allowsHitTesting(false)
    }

    /// A bright rim arc on the lit side for extra dimensionality.
    private var rimLight: some View {
        Circle()
            .trim(from: 0.05, to: 0.45)
            .stroke(tier.rim.opacity(unlocked ? 0.9 : 0.2),
                    style: StrokeStyle(lineWidth: max(1, size * 0.02), lineCap: .round))
            .rotationEffect(.degrees(roll * 30 - 120))
            .blur(radius: size * 0.01)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }
}
