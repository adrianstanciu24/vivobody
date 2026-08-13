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
    /// String — the last marketing-version + catalog-generation pair that
    /// triggered a full Spotlight reindex. The generation invalidates stale
    /// install-local UUIDs after a clean-slate store cutover.
    static let spotlightReindexedVersion = "settings.spotlightReindexedVersion"
    /// Bool — last known Pro entitlement, mirrored by ProStore so the
    /// UI doesn't flash locked on a cold offline launch while StoreKit
    /// resolves. A render hint only — `Transaction.currentEntitlements`
    /// remains the source of truth and overwrites this on every launch.
    static let proUnlockedCache = "settings.proUnlockedCache"
    /// Stores `BodyDriftSpeed.rawValue`. Read via @AppStorage inside
    /// `RotatableBodyModel`, so changing it retargets the idle
    /// turntable everywhere the figure is on screen.
    static let bodyDriftSpeed = "settings.bodyDriftSpeed"
    /// Bool — whether the App Store review prompt has ever been
    /// requested. Gates ReviewRequestController: the system prompt is
    /// requested at most once, after the 20th archived workout.
    static let hasRequestedAppReview = "settings.hasRequestedAppReview"
    /// Monotonic revision for data consumed by the full widget
    /// snapshot set. Relevant mutation paths advance it only after
    /// their SwiftData save succeeds.
    static let widgetDatasetRevision = "widgets.datasetRevision"
    /// Fingerprint of the last complete App Group snapshot publish.
    /// It also carries date- and preference-based inputs that can
    /// change without a SwiftData mutation.
    static let widgetSnapshotFingerprint = "widgets.snapshotFingerprint"
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
    static let bodyDriftSpeed = BodyDriftSpeed.low.rawValue
}

/// How fast the 3D body model idles on its turntable. `low` is the
/// default — one revolution in fifteen seconds, so every side comes
/// around without the user dragging. Each step up doubles it.
nonisolated enum BodyDriftSpeed: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }

    /// One full idle revolution takes this long.
    var secondsPerRevolution: Double {
        switch self {
        case .low:    return 15
        case .medium: return 7.5
        case .high:   return 3.75
        }
    }

    /// Idle angular speed in radians/second, derived from the above.
    var radiansPerSecond: Float { Float(2 * Double.pi / secondsPerRevolution) }
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
