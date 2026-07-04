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

import VivoKit
import SwiftUI
import SwiftData

struct EditSetSheet: View {
    @Bindable var set: WorkoutSet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var saveError: SaveErrorBox? = nil

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

    /// Writing RIR here marks it explicitly logged, so effort stats
    /// can tell a real reading apart from the default-2 placeholder.
    private var rirBinding: Binding<Int> {
        Binding(
            get: { set.repsInReserve },
            set: { set.repsInReserve = $0; set.rirLogged = true }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.lg) {
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

                    RIRSelector(value: rirBinding)

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
            .padding(.top, Space.xl)
            .padding(.bottom, 20)
            .background(Surface.background.ignoresSafeArea())
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.soft()
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onChange(of: set.weight) { _, _ in save() }
        .onChange(of: set.reps) { _, _ in save() }
        .onChange(of: set.duration) { _, _ in save() }
        .onChange(of: set.repsInReserve) { _, _ in save() }
        .saveErrorAlert($saveError)
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            saveError = SaveErrorBox(error)
        }
    }
}

#Preview {
    EditSetSheet(set: WorkoutSet(weight: 135, reps: 8, isCompleted: true))
        .preferredColorScheme(.dark)
}
