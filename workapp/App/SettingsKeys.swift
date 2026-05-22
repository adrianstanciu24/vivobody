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
}

enum SettingsDefaults {
    static let hapticsEnabled = true
    static let defaultRestSeconds = 60
}
