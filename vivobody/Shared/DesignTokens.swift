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

enum Tint {
    static let primary       = Color(.sRGB, red: 1.0, green: 0.45, blue: 0.0, opacity: 1.0)
    static let primaryDim    = Color(.sRGB, red: 1.0, green: 0.45, blue: 0.0, opacity: 0.35)
    static let primaryShadow = Color(.sRGB, red: 0.72, green: 0.30, blue: 0.0, opacity: 1.0)

    static let success    = primary
    static let successDim = primaryDim
    static let inProgress = primary
    static let complete    = primary
    static let completeDim = primaryDim
    static let onAccent   = Color.black
    static let danger     = Color(.sRGB, red: 0.96, green: 0.42, blue: 0.42, opacity: 1.0)
}

enum Ink {
    static let primary    = adaptiveColor(dark: .white.withAlphaComponent(0.95), light: .black.withAlphaComponent(0.88))
    static let secondary  = adaptiveColor(dark: .white.withAlphaComponent(0.68), light: .black.withAlphaComponent(0.62))
    static let tertiary   = adaptiveColor(dark: .white.withAlphaComponent(0.44), light: .black.withAlphaComponent(0.42))
    static let quaternary = adaptiveColor(dark: .white.withAlphaComponent(0.22), light: .black.withAlphaComponent(0.22))

    private static func adaptiveColor(dark: UIColor, light: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum Opacity {
    static let strong: Double = 0.85
    static let emphasis: Double = 0.70
    static let medium: Double = 0.55
    static let soft: Double = 0.40
    static let faint: Double = 0.22
}

enum Radius {
    static let card: CGFloat = 22
    static let chip: CGFloat = 14
    static let small: CGFloat = 10
    static let pill: CGFloat = 999
}

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let gutter: CGFloat = 20
    static let section: CGFloat = 32
    static let tapMin: CGFloat = 44
    static let rowMin: CGFloat = 60
}

enum Surface {
    static let background = adaptiveColor(dark: .black, light: UIColor.systemGroupedBackground)
    static let cardTint = adaptiveColor(dark: .white.withAlphaComponent(0.055), light: .black.withAlphaComponent(0.045))
    static let cardTintBright = adaptiveColor(dark: .white.withAlphaComponent(0.085), light: .black.withAlphaComponent(0.075))
    static let edge = adaptiveColor(dark: .white.withAlphaComponent(0.10), light: .black.withAlphaComponent(0.10))
    static let edgeBright = adaptiveColor(dark: .white.withAlphaComponent(0.18), light: .black.withAlphaComponent(0.16))

    private static func adaptiveColor(dark: UIColor, light: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum Typography {
    static let bigMetric = Font.system(size: 104, weight: .bold, design: .monospaced)
    static let metricHero = Font.system(size: 56, weight: .bold, design: .monospaced)
    static let metricLg = Font.system(size: 40, weight: .bold, design: .monospaced)
    static let statValue = Font.system(size: 28, weight: .bold, design: .monospaced)
    static let metricInline = Font.system(size: 16, weight: .semibold, design: .monospaced)
    static let metricUnit = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let metricMicro = Font.system(size: 11, weight: .medium, design: .monospaced)

    static let display = Font.system(size: 30, weight: .bold)
    static let title = Font.system(size: 20, weight: .semibold)
    static let headline = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let sectionHeading = Font.system(size: 15, weight: .semibold)
    static let sectionLabel = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 12, weight: .medium)
    static let micro = Font.system(size: 10, weight: .medium)
}

extension View {
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
