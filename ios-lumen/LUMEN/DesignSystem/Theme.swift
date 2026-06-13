//
//  Theme.swift
//  LUMEN
//
//  The quiet-luxury design system: a single gold accent on warm neutrals.
//

import SwiftUI

extension Color {
    /// Create a color from a hex value, e.g. `Color(hex: 0xD9B877)`.
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// The full set of semantic colors for a given appearance.
struct Palette: Sendable {
    let isDark: Bool

    var base: Color { isDark ? Color(hex: 0x0D0D0F) : Color(hex: 0xF7F4EE) }
    var surface1: Color { isDark ? Color(hex: 0x16161A) : Color(hex: 0xFFFFFF) }
    var surface2: Color { isDark ? Color(hex: 0x1F1F25) : Color(hex: 0xFBF8F2) }
    var textPrimary: Color { isDark ? Color(hex: 0xF5F3EE) : Color(hex: 0x1A1A1C) }
    var textSecondary: Color { isDark ? Color(hex: 0xA8A29A) : Color(hex: 0x6B6660) }

    /// The single accent — warm gold.
    let accent = Color(hex: 0xC9A86A)
    let goldLight = Color(hex: 0xD9B877)
    let goldDark = Color(hex: 0xB8935A)
    let sage = Color(hex: 0x8AA678)
    var danger: Color { isDark ? Color(hex: 0xE0816F) : Color(hex: 0xC1543E) }

    var hairline: Color { Color(hex: 0xC9A86A, alpha: isDark ? 0.18 : 0.22) }

    /// The signature gold gradient used for CTAs, the progress ring, and medals.
    var gold: LinearGradient {
        LinearGradient(
            colors: [goldLight, goldDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var goldRadial: RadialGradient {
        RadialGradient(
            colors: [goldLight.opacity(0.9), goldDark.opacity(0.6)],
            center: .center,
            startRadius: 0,
            endRadius: 80
        )
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette(isDark: true)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Typography

extension Font {
    /// Editorial serif display face (system New York) used for all headlines.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Sans face used for body and UI.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Spacing (8pt grid)

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

enum Radius {
    static let card: CGFloat = 24
    static let tile: CGFloat = 20
    static let button: CGFloat = 16
}
