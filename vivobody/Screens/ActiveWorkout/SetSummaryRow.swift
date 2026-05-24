//
//  SetSummaryRow.swift
//  vivobody
//
//  Compact one-line row for sets that AREN'T the active one. Completed
//  sets show a filled check in the muscle-group accent; pending sets
//  show a hollow numbered chip and dim text. Used above and below the
//  active SetCompleteButton inside ActiveExerciseCard.
//

import SwiftUI

struct SetSummaryRow: View {
    let index: Int
    let weight: Double
    let reps: Int
    let isCompleted: Bool

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// Universal "set complete" green — matches SetCompleteButton's
    /// completion accent. Not muscle-group specific because completion
    /// has a single semantic across all exercises.
    private let completedGreen = Color(.sRGB, red: 0.36, green: 0.92, blue: 0.62, opacity: 1.0)

    var body: some View {
        HStack(spacing: 12) {
            statusChip

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

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isCompleted ? 0.05 : 0.025))
        )
        .accessibilityElement()
        .accessibilityLabel("Set \(index)")
        .accessibilityValue(
            isCompleted
                ? "Completed at \(WeightFormatter.string(weight, unit: unit)) for \(reps) reps"
                : "Planned at \(WeightFormatter.string(weight, unit: unit)) for \(reps) reps"
        )
    }

    private var statusChip: some View {
        ZStack {
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

#Preview {
    VStack(spacing: 8) {
        SetSummaryRow(index: 1, weight: 135, reps: 8, isCompleted: true)
        SetSummaryRow(index: 2, weight: 135, reps: 8, isCompleted: true)
        SetSummaryRow(index: 3, weight: 135, reps: 8, isCompleted: false)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
