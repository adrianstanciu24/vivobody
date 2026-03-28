import SwiftUI

// MARK: - Vivobody Color Palette

extension Color {
    static let vivoBackground = Color(hex: 0x111111)
    static let vivoSurface = Color(hex: 0x2A2A2A)
    static let vivoMuted = Color(hex: 0x3A3A3A)
    static let vivoSecondary = Color(hex: 0x666666)
    static let vivoPrimary = Color(hex: 0xEEEEEE)
    static let vivoAccent = Color(hex: 0xFF5500)
    static let vivoAccentShadow = Color(hex: 0xCC4400)
    static let vivoGreen = Color(hex: 0x34C759)
    static let vivoYellow = Color(hex: 0xD4A017)
    static let vivoWatermark = Color(hex: 0x1A1A1A)

    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Design Tokens: Font Sizes

enum VivoFont {
    // Display (Space Grotesk / system default)
    static let heroXL: CGFloat = 48
    static let heroLG: CGFloat = 40
    static let titleXL: CGFloat = 34
    static let titleLG: CGFloat = 32
    static let titleMD: CGFloat = 30
    static let titleSM: CGFloat = 28
    static let headlineLG: CGFloat = 24
    static let headlineMD: CGFloat = 22
    static let headlineSM: CGFloat = 20
    static let sectionTitle: CGFloat = 18
    static let body: CGFloat = 16
    static let bodySmall: CGFloat = 14
    static let caption: CGFloat = 12
    static let captionSmall: CGFloat = 11

    // Mono (Space Mono / system monospaced)
    static let monoXL: CGFloat = 20
    static let monoLG: CGFloat = 16
    static let monoBody: CGFloat = 15
    static let monoMD: CGFloat = 14
    static let monoDefault: CGFloat = 13
    static let monoSM: CGFloat = 12
    static let monoCaption: CGFloat = 11
    static let monoXS: CGFloat = 10
    static let monoMicro: CGFloat = 9
    static let monoTiny: CGFloat = 8
    static let monoMin: CGFloat = 7
}

// MARK: - Design Tokens: Spacing

enum VivoSpacing {
    static let screenH: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let sectionGap: CGFloat = 14
    static let itemGap: CGFloat = 10
    static let tightGap: CGFloat = 8
    static let innerPad: CGFloat = 12
    static let micro: CGFloat = 4
}

// MARK: - Design Tokens: Corner Radii

enum VivoRadius {
    static let card: CGFloat = 8
    static let button: CGFloat = 8
    static let pill: CGFloat = 6
    static let badge: CGFloat = 4
    static let bar: CGFloat = 3
    static let dot: CGFloat = 2
    static let stepper: CGFloat = 10
    static let large: CGFloat = 12
}

// MARK: - Design Tokens: Tracking (Letter Spacing)

enum VivoTracking {
    static let wide: CGFloat = 2
    static let medium: CGFloat = 1.5
    static let normal: CGFloat = 1
    static let tight: CGFloat = 0.5
}

// MARK: - Vivobody Fonts (swap in Space Mono / Space Grotesk when bundled)

extension Font {
    static func vivoMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func vivoDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
