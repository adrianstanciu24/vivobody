//
//  WeightScrubber.swift
//  vivobody
//
//  Unit-aware wrapper around the app's card and bare scrubbers for
//  weight values.
//  The bound canonical value is always in lb; this view reads the
//  user's WeightUnit preference, converts the value to the display
//  unit for scrubbing, and converts back on write. Step and range
//  default to the unit's gym-natural values (5 lb / 2.5 kg for
//  strength; 0.2 lb / 0.1 kg for body weight) so the scrubber's
//  feel matches the user's environment without per-call setup.
//

import SwiftUI

struct WeightScrubber: View {
    /// Canonical pounds. The wrapper translates to/from the user's
    /// unit at the binding boundary so callers never see kg even
    /// when the user is scrubbing in kg.
    @Binding var canonicalWeight: Double

    /// What the scrubber is for. Strength uses larger step + range;
    /// body weight uses finer step + a tighter range tuned to human
    /// adult body-weight extremes.
    var purpose: Purpose = .strength

    /// Optional override for the underlying scrubber's range, in
    /// CANONICAL POUNDS. If supplied, it overrides the purpose's
    /// default; if nil, the purpose's range is used. Values are
    /// converted to display-unit at use time.
    var canonicalRange: ClosedRange<Double>? = nil

    /// Label shown above the value. Defaults to "Weight" for
    /// strength scrubbers; pass nil to hide the label entirely.
    var label: String? = "Weight"

    /// Drag points required per step (smaller = faster scrubbing).
    /// Defaults to 12 to match the underlying NumberScrubber's
    /// general-purpose feel; the active-workout sites pass 8 for
    /// snappier in-context adjustments.
    var pointsPerStep: CGFloat = 12

    var valueFontSize: CGFloat = 64
    var verticalPadding: CGFloat = 28
    var presentation: Presentation = .card

    enum Purpose {
        case strength
        case body
    }

    enum Presentation {
        case card
        case bare
    }

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .card:
            NumberScrubber(
                value: displayBinding,
                range: displayRange,
                step: step,
                pointsPerStep: pointsPerStep,
                unit: unit.symbol,
                label: label,
                valueFontSize: valueFontSize,
                verticalPadding: verticalPadding,
                tickTone: .deep
            )
        case .bare:
            BareScrubber(
                value: displayBinding,
                range: displayRange,
                step: step,
                pointsPerStep: pointsPerStep,
                fontSize: valueFontSize,
                unit: unit.symbol,
                unitFontSize: 16,
                accessibilityLabel: label ?? "Weight",
                fitsWidth: true,
                tickTone: .deep,
                hitSlop: 16,
                showsRail: true
            )
        }
    }

    // MARK: - Bridging

    /// The scrubber operates entirely in display-unit values. On
    /// read we convert canonical → display; on write we convert
    /// display → canonical and store. The conversion is lossless
    /// to within a fraction of the unit's step size, so repeated
    /// round-trips don't drift values meaningfully.
    private var displayBinding: Binding<Double> {
        Binding(
            get: { WeightFormatter.toDisplay(canonicalWeight, unit: unit) },
            set: { newDisplay in
                canonicalWeight = WeightFormatter.toCanonical(newDisplay, unit: unit)
            }
        )
    }

    private var displayRange: ClosedRange<Double> {
        if let canonicalRange {
            return WeightFormatter.toDisplay(canonicalRange, unit: unit)
        }
        switch purpose {
        case .strength: return unit.strengthRange
        case .body:     return unit.bodyWeightRange
        }
    }

    private var step: Double {
        switch purpose {
        case .strength: return unit.strengthStep
        case .body:     return unit.bodyWeightStep
        }
    }
}
