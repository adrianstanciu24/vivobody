//
//  SettingsKeys.swift
//  workapp
//
//  Single source of truth for UserDefaults keys + defaults so the
//  values can't drift between the screen that writes them (MeScreen)
//  and the code that reads them (Haptics, future RestTimer).
//

import Foundation

enum SettingsKey {
    static let hapticsEnabled = "settings.hapticsEnabled"
    static let defaultRestSeconds = "settings.defaultRestSeconds"
    /// Stores `WeightUnit.rawValue` ("lb" or "kg"). Read via
    /// @AppStorage at every weight display + scrubber so flipping
    /// the toggle updates all surfaces synchronously.
    static let weightUnit = "settings.weightUnit"
}

enum SettingsDefaults {
    static let hapticsEnabled = true
    static let defaultRestSeconds = 60
    static let weightUnit = WeightUnit.lb.rawValue
}
