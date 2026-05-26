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

import SwiftUI

struct SetSummaryRow: View {
    let index: Int
    let weight: Double
    let reps: Int
    let isCompleted: Bool
    var isActive: Bool = false

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

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
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tint.primary)
            } else {
                HStack(spacing: 4) {
                    Text(WeightFormatter.string(weight, unit: unit, includeUnit: false))
                        .monospacedDigit()
                    Text(unit.symbol)
                        .foregroundStyle(.white.opacity(isCompleted ? 0.45 : 0.30))
                    Text("·")
                        .foregroundStyle(.white.opacity(isCompleted ? 0.30 : 0.20))
                        .padding(.horizontal, 2)
                    Text("\(reps)")
                        .monospacedDigit()
                    Text("reps")
                        .foregroundStyle(.white.opacity(isCompleted ? 0.45 : 0.30))
                }
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(isCompleted ? 0.80 : 0.45))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(rowBackground)
        .onAppear {
            guard isActive else { return }
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Tint.primary.opacity(0.10))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Tint.primary.opacity(0.30), lineWidth: 0.8)
            }
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isCompleted ? 0.05 : 0.025))
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
                    .fill(isCompleted ? completedGreen : Color.white.opacity(0.06))
                    .frame(width: 24, height: 24)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(index)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
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
