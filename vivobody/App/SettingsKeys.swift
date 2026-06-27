//
//  SettingsKeys.swift
//  vivobody
//
//  Single source of truth for UserDefaults keys + defaults so the
//  values can't drift between the screen that writes them (MeScreen)
//  and the code that reads them (Haptics, future RestTimer).
//

import SwiftUI

nonisolated enum SettingsKey {
    static let hapticsEnabled = "settings.hapticsEnabled"
    static let defaultRestSeconds = "settings.defaultRestSeconds"
    /// Stores `WeightUnit.rawValue` ("lb" or "kg"). Read via
    /// @AppStorage at every weight display + scrubber so flipping
    /// the toggle updates all surfaces synchronously.
    static let weightUnit = "settings.weightUnit"
    /// Stores `AppAppearance.rawValue`. Read via @AppStorage at the
    /// app root to drive `.preferredColorScheme`; "system" defers to
    /// the OS.
    static let appearance = "settings.appearance"
}

nonisolated enum SettingsDefaults {
    static let hapticsEnabled = true
    static let defaultRestSeconds = 60
    static let weightUnit = WeightUnit.lb.rawValue
    static let appearance = AppAppearance.system.rawValue
}

/// The user's colour-scheme preference. `system` follows the OS;
/// `light`/`dark` pin it. Maps to the optional `ColorScheme` SwiftUI
/// expects at `.preferredColorScheme` (nil = follow system).
nonisolated enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
