//
//  DesignTokens.swift
//  vivobody
//
//  Shared visual tokens for the app and widget extension. Widgets
//  cannot import the app target, so the core colour, opacity, radius,
//  spacing, and typography roles live in a source folder compiled by
//  both targets.
//

import SwiftUI
import UIKit

public enum Tint {
    // The brand orange stays consistent across appearances. Black
    // foreground content remains legible on the bright filled controls.
    public static let primary = adaptiveColor(
        dark: UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 1.0),
        light: UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 1.0),
        highContrastDark: UIColor(red: 1.0, green: 0.52, blue: 0.05, alpha: 1.0),
        highContrastLight: UIColor(red: 0.56, green: 0.18, blue: 0.0, alpha: 1.0)
    )
    public static let primaryDim = adaptiveColor(
        dark: UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 0.35),
        light: UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 0.35),
        highContrastDark: UIColor(red: 1.0, green: 0.52, blue: 0.05, alpha: 0.55),
        highContrastLight: UIColor(red: 0.56, green: 0.18, blue: 0.0, alpha: 0.55)
    )
    public static let primaryShadow = adaptiveColor(
        dark: UIColor(red: 0.72, green: 0.30, blue: 0.0, alpha: 1.0),
        light: UIColor(red: 0.45, green: 0.14, blue: 0.0, alpha: 1.0),
        highContrastDark: UIColor(red: 0.84, green: 0.35, blue: 0.0, alpha: 1.0),
        highContrastLight: UIColor(red: 0.38, green: 0.10, blue: 0.0, alpha: 1.0)
    )

    public static let success    = primary
    public static let successDim = primaryDim
    public static let inProgress = primary
    public static let complete    = primary
    public static let completeDim = primaryDim
    public static let onAccent = adaptiveColor(
        dark: .black,
        light: .black,
        highContrastDark: .black,
        highContrastLight: .white
    )
    public static let danger = adaptiveColor(
        dark: UIColor(red: 0.96, green: 0.42, blue: 0.42, alpha: 1.0),
        light: UIColor(red: 0.70, green: 0.12, blue: 0.12, alpha: 1.0),
        highContrastDark: UIColor(red: 1.0, green: 0.52, blue: 0.52, alpha: 1.0),
        highContrastLight: UIColor(red: 0.58, green: 0.06, blue: 0.06, alpha: 1.0)
    )

    nonisolated private static func adaptiveColor(
        dark: UIColor,
        light: UIColor,
        highContrastDark: UIColor,
        highContrastLight: UIColor
    ) -> Color {
        Color(UIColor { traits in
            switch (traits.userInterfaceStyle, traits.accessibilityContrast) {
            case (.dark, .high): highContrastDark
            case (_, .high):     highContrastLight
            case (.dark, _):     dark
            default:             light
            }
        })
    }
}

public enum Ink {
    // The normal-contrast tertiary and quaternary roles clear 4.5:1
    // against the app's black/white backgrounds, even at caption sizes.
    // High Contrast keeps the same hierarchy while increasing separation.
    public static let primary = adaptiveColor(
        dark: .white.withAlphaComponent(0.96),
        light: .black.withAlphaComponent(0.92),
        highContrastDark: .white,
        highContrastLight: .black
    )
    public static let secondary = adaptiveColor(
        dark: .white.withAlphaComponent(0.74),
        light: .black.withAlphaComponent(0.76),
        highContrastDark: .white.withAlphaComponent(0.88),
        highContrastLight: .black.withAlphaComponent(0.88)
    )
    public static let tertiary = adaptiveColor(
        dark: .white.withAlphaComponent(0.58),
        light: .black.withAlphaComponent(0.64),
        highContrastDark: .white.withAlphaComponent(0.78),
        highContrastLight: .black.withAlphaComponent(0.80)
    )
    public static let quaternary = adaptiveColor(
        dark: .white.withAlphaComponent(0.48),
        light: .black.withAlphaComponent(0.56),
        highContrastDark: .white.withAlphaComponent(0.65),
        highContrastLight: .black.withAlphaComponent(0.70)
    )

    nonisolated private static func adaptiveColor(
        dark: UIColor,
        light: UIColor,
        highContrastDark: UIColor,
        highContrastLight: UIColor
    ) -> Color {
        Color(UIColor { traits in
            switch (traits.userInterfaceStyle, traits.accessibilityContrast) {
            case (.dark, .high): highContrastDark
            case (_, .high):     highContrastLight
            case (.dark, _):     dark
            default:             light
            }
        })
    }
}

public enum Opacity {
    public static let strong: Double = 0.85
    public static let emphasis: Double = 0.70
    public static let medium: Double = 0.55
    public static let soft: Double = 0.40
    public static let faint: Double = 0.22
}

public enum Radius {
    public static let card: CGFloat = 22
    public static let chip: CGFloat = 14
    public static let small: CGFloat = 10
    public static let pill: CGFloat = 999
}

public enum Space {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let gutter: CGFloat = 20
    public static let section: CGFloat = 32
    public static let tapMin: CGFloat = 44
    public static let rowMin: CGFloat = 60
}

public enum Surface {
    public static let background = adaptiveColor(
        dark: .black,
        light: UIColor.systemGroupedBackground,
        highContrastDark: .black,
        highContrastLight: UIColor.systemGroupedBackground
    )
    public static let cardTint = adaptiveColor(
        dark: .white.withAlphaComponent(0.055),
        light: .black.withAlphaComponent(0.045),
        highContrastDark: .white.withAlphaComponent(0.10),
        highContrastLight: .black.withAlphaComponent(0.09)
    )
    public static let cardTintBright = adaptiveColor(
        dark: .white.withAlphaComponent(0.085),
        light: .black.withAlphaComponent(0.075),
        highContrastDark: .white.withAlphaComponent(0.15),
        highContrastLight: .black.withAlphaComponent(0.14)
    )
    public static let edge = adaptiveColor(
        dark: .white.withAlphaComponent(0.10),
        light: .black.withAlphaComponent(0.10),
        highContrastDark: .white.withAlphaComponent(0.24),
        highContrastLight: .black.withAlphaComponent(0.24)
    )
    public static let edgeBright = adaptiveColor(
        dark: .white.withAlphaComponent(0.18),
        light: .black.withAlphaComponent(0.16),
        highContrastDark: .white.withAlphaComponent(0.34),
        highContrastLight: .black.withAlphaComponent(0.32)
    )

    nonisolated private static func adaptiveColor(
        dark: UIColor,
        light: UIColor,
        highContrastDark: UIColor,
        highContrastLight: UIColor
    ) -> Color {
        Color(UIColor { traits in
            switch (traits.userInterfaceStyle, traits.accessibilityContrast) {
            case (.dark, .high): highContrastDark
            case (_, .high):     highContrastLight
            case (.dark, _):     dark
            default:             light
            }
        })
    }
}

public enum Typography {
    // Hero numerals — intentionally fixed. These are already very large
    // display sizes (40-104 pt) that live inside gesture-first instrument
    // layouts. Scaling them further risks breaking the deliberate spatial
    // relationships. Apple allows capping very large display text.
    public static let bigMetric = Font.system(size: 104, weight: .bold, design: .monospaced)
    public static let metricHero = Font.system(size: 56, weight: .bold, design: .monospaced)
    public static let metricLg = Font.system(size: 40, weight: .bold, design: .monospaced)

    // Scalable numeric tokens — text-style-based so they react to Dynamic Type.
    public static let statValue = Font.system(.title, design: .monospaced, weight: .bold)
    public static let statValueCompact = Font.system(.title2, design: .monospaced, weight: .bold)
    public static let metricInline = Font.system(.callout, design: .monospaced, weight: .semibold)
    public static let metricUnit = Font.system(.footnote, design: .monospaced, weight: .medium)
    public static let metricMicro = Font.system(.caption2, design: .monospaced, weight: .medium)

    // Scalable text tokens — text-style-based so they react to Dynamic Type.
    public static let display = Font.system(.largeTitle, weight: .bold)
    public static let title = Font.system(.title3, weight: .semibold)
    public static let headline = Font.system(.headline)
    public static let body = Font.system(.body)
    public static let sectionHeading = Font.system(.subheadline, weight: .semibold)
    public static let sectionLabel = Font.system(.footnote, weight: .medium)
    public static let caption = Font.system(.caption, weight: .medium)
    public static let micro = Font.system(.caption2, weight: .medium)
}

public extension View {
    func sectionLabelStyle(_ opacity: Double = Opacity.soft) -> some View {
        self
            .font(Typography.sectionLabel)
            .foregroundStyle(Ink.primary.opacity(opacity))
            .textCase(nil)
            .tracking(0)
    }

    func sectionHeadingStyle(_ opacity: Double = Opacity.strong) -> some View {
        self
            .font(Typography.sectionHeading)
            .foregroundStyle(Ink.primary.opacity(opacity))
            .textCase(nil)
            .tracking(0)
    }
}
