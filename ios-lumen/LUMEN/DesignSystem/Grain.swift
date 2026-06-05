//
//  Grain.swift
//  LUMEN
//
//  A subtle ~3% film-grain overlay that gives backgrounds a tactile, analog depth.
//

import SwiftUI

/// A static, cached noise texture rendered once and reused as a tiling overlay.
private let grainImage: Image = {
    let size = 140
    let bytesPerPixel = 4
    let bytesPerRow = size * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: size * size * bytesPerPixel)
    var generator = SystemRandomNumberGenerator()
    for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
        let v = UInt8.random(in: 0...255, using: &generator)
        pixels[i] = v
        pixels[i + 1] = v
        pixels[i + 2] = v
        pixels[i + 3] = 255
    }
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: &pixels,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    guard let cg = ctx?.makeImage() else { return Image(systemName: "circle") }
    return Image(decorative: cg, scale: 1)
}()

struct GrainOverlay: View {
    var opacity: Double = 0.03

    var body: some View {
        grainImage
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .blendMode(.overlay)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}

/// Full-screen branded background: warm base + soft gold glow + grain.
struct LumenBackground: View {
    @Environment(\.palette) private var palette
    var glow: Bool = true

    var body: some View {
        ZStack {
            palette.base.ignoresSafeArea()
            if glow {
                RadialGradient(
                    colors: [palette.accent.opacity(palette.isDark ? 0.10 : 0.07), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 420
                )
                .ignoresSafeArea()
            }
            GrainOverlay()
        }
    }
}
