//
//  SetSummaryRow.swift
//  vivobody
//
//  Compact one-line row used inside the Sets list of an
//  ActiveExerciseCard. Three visual states:
//    • isActive    — primary-tinted "Lifting now" marker. Numbers
//                    deliberately omitted; the hero billboard above
//                    owns the active set's numbers, so repeating
//                    them here would be the exact duplication this
//                    redesign deletes.
//    • isCompleted — green check + monospaced weight · reps audit.
//    • pending     — hollow numbered chip + dim weight · reps plan.
//

import VivoKit
import SwiftUI

struct SetSummaryRow: View {
    let index: Int
    let weight: Double
    let reps: Int
    let isCompleted: Bool
    var isActive: Bool = false

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// Universal "set complete" green — not muscle-group specific
    /// because completion has a single semantic across all exercises.
    private let completedGreen = Tint.success

    /// Subtle pulse on the active marker's inner dot so the row
    /// reads as "live" without competing with the hero's animation.
    @State private var pulse: Double = 0.55

    var body: some View {
        HStack(spacing: 12) {
            statusChip

            if isActive {
                Text("Lifting now")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Tint.primary)
            } else {
                HStack(spacing: 4) {
                    Text(WeightFormatter.string(weight, unit: unit, includeUnit: false))
                        .monospacedDigit()
                    Text(unit.symbol)
                        .foregroundStyle(isCompleted ? Ink.tertiary : Ink.quaternary)
                    Text("·")
                        .foregroundStyle(Ink.quaternary)
                        .padding(.horizontal, 2)
                    Text("\(reps)")
                        .monospacedDigit()
                    Text("reps")
                        .foregroundStyle(isCompleted ? Ink.tertiary : Ink.quaternary)
                }
                .font(Typography.metricUnit)
                .foregroundStyle(isCompleted ? Ink.secondary : Ink.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, Space.md + 2)
        .padding(.vertical, Space.sm + 2)
        .background(rowBackground)
        .onAppear {
            guard isActive, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = 1.0
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Set \(index)")
        .accessibilityValue(accessibilityValueText)
    }

    private var accessibilityValueText: String {
        if isActive {
            return "Active. \(WeightFormatter.string(weight, unit: unit)) for \(reps) reps."
        }
        if isCompleted {
            return "Completed at \(WeightFormatter.string(weight, unit: unit)) for \(reps) reps"
        }
        return "Planned at \(WeightFormatter.string(weight, unit: unit)) for \(reps) reps"
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isActive {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(Tint.primary.opacity(0.10))
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .stroke(Tint.primary.opacity(0.30), lineWidth: 0.8)
            }
        } else {
            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                .fill(isCompleted ? Surface.cardTint : Surface.cardTint.opacity(0.5))
        }
    }

    private var statusChip: some View {
        ZStack {
            if isActive {
                Circle()
                    .stroke(Tint.primary.opacity(0.6), lineWidth: 1.2)
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(Tint.primary)
                    .frame(width: 9, height: 9)
                    .opacity(pulse)
            } else {
                Circle()
                    .fill(isCompleted ? completedGreen : Surface.cardTintBright)
                    .frame(width: 24, height: 24)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(Typography.caption)
                        .foregroundStyle(Tint.onAccent)
                } else {
                    Text("\(index)")
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.tertiary)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        SetSummaryRow(index: 1, weight: 135, reps: 8, isCompleted: true)
        SetSummaryRow(index: 2, weight: 135, reps: 8, isCompleted: false, isActive: true)
        SetSummaryRow(index: 3, weight: 135, reps: 8, isCompleted: false)
        SetSummaryRow(index: 4, weight: 135, reps: 8, isCompleted: false)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
