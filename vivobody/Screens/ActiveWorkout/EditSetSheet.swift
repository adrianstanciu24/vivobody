//
//  EditSetSheet.swift
//  vivobody
//
//  Small modal for correcting a previously-completed set when the
//  user mis-logged its weight or reps. Reuses the two NumberScrubbers
//  from the active card so the editing motion (drag up/down) feels
//  identical to logging the set the first time. Changes apply live
//  via @Bindable on the WorkoutSet — there's no save/discard; pulling
//  the sheet down commits the current values.
//

import SwiftUI

struct EditSetSheet: View {
    @Bindable var set: WorkoutSet
    @Environment(\.dismiss) private var dismiss

    /// The set's tracking mode comes from its owning exercise —
    /// decides whether we edit reps or a held interval.
    private var mode: TrackingMode { self.set.exercise?.trackingMode ?? .reps }

    /// NumberScrubber operates on Double; reps live as Int in the
    /// model. Round on every set so the model stays integer-clean.
    private var repsBinding: Binding<Double> {
        Binding(
            get: { Double(set.reps) },
            set: { set.reps = Int($0.rounded()) }
        )
    }

    private var weightBinding: Binding<Double> {
        Binding(
            get: { set.weight },
            set: { set.weight = $0 }
        )
    }

    private var durationBinding: Binding<Double> {
        Binding(
            get: { set.duration },
            set: { set.duration = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                switch mode {
                case .reps:
                    WeightScrubber(
                        canonicalWeight: weightBinding,
                        purpose: .strength,
                        label: "weight",
                        pointsPerStep: 8,
                        valueFontSize: 40,
                        verticalPadding: 14
                    )

                    NumberScrubber(
                        value: repsBinding,
                        range: 1...30,
                        step: 1,
                        pointsPerStep: 16,
                        unit: "reps",
                        label: "reps",
                        valueFontSize: 32,
                        verticalPadding: 12
                    )

                    RIRSelector(value: $set.repsInReserve)

                case .duration:
                    NumberScrubber(
                        value: durationBinding,
                        range: DurationFormatter.scrubRange,
                        step: DurationFormatter.scrubStep,
                        pointsPerStep: 10,
                        label: "hold",
                        valueFontSize: 40,
                        verticalPadding: 14,
                        formatter: { DurationFormatter.string($0) }
                    )

                    WeightScrubber(
                        canonicalWeight: weightBinding,
                        purpose: .strength,
                        label: "added load",
                        pointsPerStep: 8,
                        valueFontSize: 32,
                        verticalPadding: 12
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.soft()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.black)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    EditSetSheet(set: WorkoutSet(weight: 135, reps: 8, isCompleted: true))
        .preferredColorScheme(.dark)
}
