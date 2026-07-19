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
    /// Bool — whether UI sounds accompany the haptic atoms/patterns.
    /// Read fresh by Sounds on every emission, independent of the
    /// haptics toggle. The .ambient audio session means the ring/
    /// silent switch still mutes sounds even when this is on.
    static let soundsEnabled = "settings.soundsEnabled"
    static let defaultRestSeconds = "settings.defaultRestSeconds"
    /// Stores `WeightUnit.rawValue` ("lb" or "kg"). Read via
    /// @AppStorage at every weight display + scrubber so flipping
    /// the toggle updates all surfaces synchronously.
    static let weightUnit = "settings.weightUnit"
    /// Per-exercise weight increment. Bundled exercises use their stable
    /// catalog ID so the preference survives a catalog reset; custom
    /// exercises fall back to their installation-local SwiftData UUID.
    static func weightStep(catalogID: String?, catalogItemID: UUID) -> String {
        if let catalogID, !catalogID.isEmpty {
            return "settings.weightStep.catalog.\(catalogID)"
        }
        return "settings.weightStep.custom.\(catalogItemID.uuidString)"
    }
    /// Stores `AppAppearance.rawValue`. Read via @AppStorage at the
    /// app root to drive `.preferredColorScheme`; "system" defers to
    /// the OS.
    static let appearance = "settings.appearance"
    /// Bool — whether finished workouts are mirrored to Apple Health
    /// (HealthKit Tier A). Opt-in; the Settings toggle requests write
    /// authorization when first enabled, and the archive path reads
    /// this flag before writing.
    static let healthKitEnabled = "settings.healthKitEnabled"
    /// Bool — whether the first-launch welcome screen has been
    /// dismissed. Gates the one-time OnboardingScreen presented over
    /// AppRoot; flips true the moment the user taps Start.
    static let onboardingCompleted = "settings.onboardingCompleted"
    /// Bool — whether the user has ever performed a real vertical
    /// scrub on a number scrubber. Gates the in-context first-use
    /// affordance (nudge animation + faint chevrons) so it appears
    /// only until the user drags a number once, then never again.
    /// Teaches the drag-to-adjust gesture without an onboarding
    /// wizard, which the product principles cut outright.
    static let hasScrubbedNumber = "settings.hasScrubbedNumber"
    /// String — the last `CFBundleShortVersionString` that triggered
    /// a full Spotlight reindex. Gates `reindexAllIfNeeded` so the
    /// delete-all + reindex runs once per app version, not every launch.
    static let spotlightReindexedVersion = "settings.spotlightReindexedVersion"
    /// Bool — last known Pro entitlement, mirrored by ProStore so the
    /// UI doesn't flash locked on a cold offline launch while StoreKit
    /// resolves. A render hint only — `Transaction.currentEntitlements`
    /// remains the source of truth and overwrites this on every launch.
    static let proUnlockedCache = "settings.proUnlockedCache"
}

nonisolated enum SettingsDefaults {
    static let hapticsEnabled = true
    static let soundsEnabled = true
    static let defaultRestSeconds = 60
    static let weightUnit = WeightUnit.lb.rawValue
    static let appearance = AppAppearance.system.rawValue
    static let healthKitEnabled = false
    static let onboardingCompleted = false
    static let hasScrubbedNumber = false
    static let proUnlockedCache = false
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
