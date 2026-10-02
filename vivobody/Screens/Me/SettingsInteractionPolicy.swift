//
//  SettingsInteractionPolicy.swift
//  vivobody
//
//  Pure Settings presentation branches and ordered interaction plans.
//  SettingsScreen applies each command so UserDefaults, haptic/audio,
//  and sheet effects retain one integration owner.
//

import Foundation
import VivoKit

nonisolated struct SettingsPreferenceDefaults: Equatable {
    let appearance: AppAppearance
    let bodyDriftSpeed: BodyDriftSpeed
    let weightUnit: WeightUnit
    let defaultRestSeconds: Int
    let hapticsEnabled: Bool
    let soundsEnabled: Bool
}

nonisolated enum SettingsInteractionCommand: Equatable {
    case playSelectionHaptic
    case playSoftHaptic(playsSound: Bool)
    case playButtonSound
    case setAppearance(AppAppearance)
    case setBodyDriftSpeed(BodyDriftSpeed)
    case setWeightUnit(WeightUnit)
    case setDefaultRestSeconds(Int)
    case setHapticsEnabled(Bool)
    case setSoundsEnabled(Bool)
    case showCatalogResetConfirmation
}

nonisolated enum SettingsInteractionPolicy {
    /// The visible order is part of the one-tap rest-selection contract.
    static let restOptions = [180, 120, 90, 60, 30]

    static var defaults: SettingsPreferenceDefaults {
        SettingsPreferenceDefaults(
            appearance: AppAppearance(rawValue: SettingsDefaults.appearance) ?? .system,
            bodyDriftSpeed: BodyDriftSpeed(rawValue: SettingsDefaults.bodyDriftSpeed) ?? .low,
            weightUnit: WeightUnit(rawValue: SettingsDefaults.weightUnit) ?? .lb,
            defaultRestSeconds: SettingsDefaults.defaultRestSeconds,
            hapticsEnabled: SettingsDefaults.hapticsEnabled,
            soundsEnabled: SettingsDefaults.soundsEnabled
        )
    }

    static func selectAppearance(_ appearance: AppAppearance) -> [SettingsInteractionCommand] {
        [.playSelectionHaptic, .setAppearance(appearance)]
    }

    static func selectBodyDriftSpeed(_ speed: BodyDriftSpeed) -> [SettingsInteractionCommand] {
        [.playSelectionHaptic, .setBodyDriftSpeed(speed)]
    }

    static func selectWeightUnit(_ unit: WeightUnit) -> [SettingsInteractionCommand] {
        [.playSelectionHaptic, .setWeightUnit(unit)]
    }

    static func selectDefaultRest(_ seconds: Int) -> [SettingsInteractionCommand] {
        [.playSelectionHaptic, .setDefaultRestSeconds(seconds)]
    }

    static func setHaptics(_ isEnabled: Bool) -> [SettingsInteractionCommand] {
        var commands: [SettingsInteractionCommand] = [.setHapticsEnabled(isEnabled)]
        if isEnabled {
            commands.append(.playSoftHaptic(playsSound: true))
        }
        return commands
    }

    static func setSounds(_ isEnabled: Bool) -> [SettingsInteractionCommand] {
        var commands: [SettingsInteractionCommand] = [.setSoundsEnabled(isEnabled)]
        if isEnabled {
            commands.append(.playButtonSound)
        }
        return commands
    }

    static func requestCatalogReset() -> [SettingsInteractionCommand] {
        [.playSoftHaptic(playsSound: true), .showCatalogResetConfirmation]
    }
}
