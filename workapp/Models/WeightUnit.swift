//
//  WeightUnit.swift
//  workapp
//
//  The user's choice of weight unit. The app's canonical storage
//  unit is always POUNDS (lb) — every WorkoutSet, TemplateSet,
//  Exercise, plannedWeight, BodyWeightEntry, etc. is stored as a
//  Double of lb. Conversion to kilograms happens only at the UI
//  boundary (display sites + scrubber bindings) so:
//
//    • No SwiftData migration is ever required when adding kg
//      support, and existing data round-trips correctly.
//    • Sharing templates / exporting / Apple Health writes can
//      declare lb unambiguously without inspecting a per-row tag.
//    • Math (volume, PR comparisons, e1RM) operates on uniform
//      canonical values without unit-aware arithmetic.
//
//  Per-unit metadata (scrubber step, scrubber range, default
//  fractional precision, gym-natural bar weight) lives here so the
//  whole app branches on this one enum.
//

import Foundation

enum WeightUnit: String, Hashable, CaseIterable, Identifiable {
    case lb, kg

    var id: String { rawValue }

    /// Short symbol shown next to displayed weight values.
    var symbol: String {
        switch self {
        case .lb: return "lb"
        case .kg: return "kg"
        }
    }

    /// Long-form name for accessibility + the Preferences chip.
    var displayName: String {
        switch self {
        case .lb: return "Pounds"
        case .kg: return "Kilograms"
        }
    }

    // MARK: - Plate / bar metadata (consumed by PlateVisualizer)

    var standardBarWeight: Double {
        switch self {
        case .lb: return 45
        case .kg: return 20
        }
    }

    var standardPlates: [Double] {
        switch self {
        case .lb: return [45, 35, 25, 10, 5, 2.5, 1.25]
        case .kg: return [25, 20, 15, 10, 5, 2.5, 1.25, 0.5]
        }
    }

    // MARK: - Scrubber metadata

    /// Natural plate-pair increment for the strength scrubber.
    /// In lb: 5 lb = one pair of 2.5 lb plates. In kg: 2.5 kg =
    /// one pair of 1.25 kg plates. These are the most common
    /// "minimum jump" values across gyms in each unit's region.
    var strengthStep: Double {
        switch self {
        case .lb: return 5
        case .kg: return 2.5
        }
    }

    /// Strength scrubber range in the unit's native scale.
    /// 600 lb (≈272 kg) covers any human; 270 kg matches the rough
    /// upper bound of the world's strongest squatters. Lower bound
    /// is 0 so unloaded bodyweight assistance exercises work too.
    var strengthRange: ClosedRange<Double> {
        switch self {
        case .lb: return 0...600
        case .kg: return 0...275
        }
    }

    /// Body-weight scrubber step. Finer than strength because
    /// body-composition tracking benefits from sub-pound resolution
    /// (and kg users typically weigh themselves in 0.1 kg).
    var bodyWeightStep: Double {
        switch self {
        case .lb: return 0.2
        case .kg: return 0.1
        }
    }

    /// Body-weight scrubber range. 60 lb (≈27 kg) is below any
    /// realistic adult; 500 lb (≈227 kg) covers the heaviest.
    var bodyWeightRange: ClosedRange<Double> {
        switch self {
        case .lb: return 60...500
        case .kg: return 27...230
        }
    }

    /// Default fractional precision for free-form displays.
    /// Strength weights in lb are usually whole numbers (135, 225);
    /// kg often involves 2.5 jumps (60.0, 62.5, 65.0). For deltas
    /// and body weight, callers can override to 1 explicitly.
    var defaultFractionDigits: Int {
        switch self {
        case .lb: return 0
        case .kg: return 1
        }
    }
}

// MARK: - Conversion constants

/// Conversion uses the international avoirdupois pound: exactly
/// 0.45359237 kg. Apple's HealthKit uses the same constant.
extension WeightUnit {
    static let lbPerKg: Double = 1.0 / 0.45359237   // ≈ 2.20462262
    static let kgPerLb: Double = 0.45359237
}
