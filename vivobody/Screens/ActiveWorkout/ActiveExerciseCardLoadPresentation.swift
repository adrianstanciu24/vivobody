//
//  ActiveExerciseCardLoadPresentation.swift
//  vivobody
//
//  Active-workout presentation rules for resistance and unloaded exercise work.
//

import Foundation
import SwiftUI
import VivoKit

extension ActiveExerciseCard {
    var isUnloadedExercise: Bool {
        !exercise.tracksResistance
    }

    var activeLoadUnit: String {
        if exercise.loadMode == .nonComparable,
           weightDisplayBinding.wrappedValue <= 0
        {
            return ""
        }
        return unit.symbol
    }

    var activeLoadFormatter: ((Double) -> String)? {
        guard exercise.loadMode == .nonComparable else { return nil }
        return { value in
            guard value > 0 else { return "Not set" }
            return value.formatted(
                .number.precision(.fractionLength(0 ... 2))
            )
        }
    }

    var activeLoadFontSize: CGFloat {
        exercise.loadMode == .nonComparable ? 80 : 104
    }

    var resistanceAccessibilityValue: String {
        let value = weightDisplayBinding.wrappedValue
        let number = activeLoadFormatter?(value) ?? ""
        return number + (activeLoadUnit.isEmpty ? "" : " \(activeLoadUnit)")
    }

    @ViewBuilder
    func resistanceAccessibleLoadControl(
        @ViewBuilder content: () -> some View
    ) -> some View {
        if exercise.loadMode == .nonComparable {
            content()
                .accessibilityRepresentation {
                    Text("Resistance")
                        .accessibilityValue(resistanceAccessibilityValue)
                        .accessibilityHint("Swipe up or down to change")
                        .accessibilityAdjustableAction(adjustResistance)
                }
        } else {
            content()
        }
    }

    func adjustResistance(_ direction: AccessibilityAdjustmentDirection) {
        let adjustment: Double
        switch direction {
        case .increment: adjustment = weightStep
        case .decrement: adjustment = -weightStep
        @unknown default: return
        }
        let range = unit.strengthRange
        let current = weightDisplayBinding.wrappedValue
        weightDisplayBinding.wrappedValue = min(
            max(current + adjustment, range.lowerBound),
            range.upperBound
        )
        activeScrubDidEnd()
    }

    var unloadedRepsHero: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("REPS")
                .panelLegend()
                .accessibilityHidden(true)
            BareScrubber(
                value: repsBinding,
                range: 1 ... 30,
                step: 1,
                pointsPerStep: 16,
                fontSize: 104,
                unit: "reps",
                unitFontSize: 18,
                numberColor: Ink.primary,
                unitColor: Ink.tertiary,
                accessibilityLabel: "Reps",
                showsScrubHint: isActive,
                performsScrubNudge: isActive,
                fitsWidth: true,
                hitSlop: 12,
                showsRail: true,
                cancellationID: effectiveScrubCancellationID,
                onScrubEnded: activeScrubDidEnd
            )
        }
    }
}
