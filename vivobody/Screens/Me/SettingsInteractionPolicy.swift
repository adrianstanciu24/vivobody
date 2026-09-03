//
//  SettingsInteractionPolicy.swift
//  vivobody
//
//  Pure Settings presentation branches and ordered interaction plans.
//  SettingsScreen applies each command so UserDefaults, haptic/audio,
//  StoreKit, HealthKit, and sheet effects retain one integration owner.
//

import Foundation

nonisolated struct SettingsPreferenceDefaults: Equatable {
    let appearance: AppAppearance
    let bodyDriftSpeed: BodyDriftSpeed
    let weightUnit: WeightUnit
    let defaultRestSeconds: Int
    let hapticsEnabled: Bool
    let soundsEnabled: Bool
    let healthKitEnabled: Bool
}

nonisolated enum SettingsProPresentation: Equatable {
    case locked
    case unlocked
}

nonisolated enum SettingsHealthKitPresentation: Equatable {
    case unavailable
    case locked
    case unlocked
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
    case setHealthKitEnabled(Bool)
    case requestProUnlock
    case showCatalogResetConfirmation
    case showHealthKitPriming(Bool)
    case requestHealthKitAuthorization
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
            soundsEnabled: SettingsDefaults.soundsEnabled,
            healthKitEnabled: SettingsDefaults.healthKitEnabled
        )
    }

    static func proPresentation(isUnlocked: Bool) -> SettingsProPresentation {
        isUnlocked ? .unlocked : .locked
    }

    static func healthKitPresentation(
        isAvailable: Bool,
        isPro: Bool
    ) -> SettingsHealthKitPresentation {
        guard isAvailable else { return .unavailable }
        return isPro ? .unlocked : .locked
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

    static func requestProUnlock() -> [SettingsInteractionCommand] {
        [.requestProUnlock]
    }

    static func requestCatalogReset() -> [SettingsInteractionCommand] {
        [.playSoftHaptic(playsSound: true), .showCatalogResetConfirmation]
    }

    static func disableHealthKit() -> [SettingsInteractionCommand] {
        [.setHealthKitEnabled(false)]
    }

    static func beginHealthKitEnable() -> [SettingsInteractionCommand] {
        [.setHealthKitEnabled(true)]
    }

    static func routeHealthKitEnable(
        shouldPrime: Bool
    ) -> [SettingsInteractionCommand] {
        shouldPrime
            ? [.showHealthKitPriming(true)]
            : [.requestHealthKitAuthorization]
    }

    static func continueHealthKitPriming() -> [SettingsInteractionCommand] {
        [.showHealthKitPriming(false), .requestHealthKitAuthorization]
    }

    static func declineHealthKitPriming() -> [SettingsInteractionCommand] {
        [.setHealthKitEnabled(false), .showHealthKitPriming(false)]
    }

    static func settleHealthKitAuthorization(
        granted: Bool
    ) -> [SettingsInteractionCommand] {
        var commands: [SettingsInteractionCommand] = [.setHealthKitEnabled(granted)]
        if granted {
            commands.append(.playSoftHaptic(playsSound: false))
        }
        return commands
    }
}
