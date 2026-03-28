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

// MARK: - Vivobody Fonts (swap in Space Mono / Space Grotesk when bundled)

extension Font {
    static func vivoMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func vivoDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
