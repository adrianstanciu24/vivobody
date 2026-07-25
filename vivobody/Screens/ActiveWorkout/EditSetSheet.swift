//
//  EditSetSheet.swift
//  vivobody
//
//  Small modal for correcting a previously-completed set when the
//  user mis-logged its weight or reps. Changes apply immediately to
//  the in-memory WorkoutSet. Persistence happens once when the scrub
//  settles, or when the scene deactivates or sheet dismisses. RIR remains
//  an immediate semantic save.
//

import VivoKit
import SwiftUI
import SwiftData

struct EditSetSheet: View {
    @Bindable var set: WorkoutSet
    var onImmediateUpdate: (() -> Void)? = nil
    var onScrubEnded: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var saveError: SaveErrorBox? = nil
    @State private var hasPendingChanges: Bool = false

    /// The set's tracking mode comes from its owning exercise —
    /// decides whether we edit reps or a timed effort.
    private var mode: TrackingMode { self.set.exercise?.trackingMode ?? .reps }
    private var modality: ExerciseModality { self.set.exercise?.modality ?? .dynamicStrength }
    private var loadMode: ExerciseLoadMode { self.set.exercise?.loadMode ?? .external }

    /// NumberScrubber operates on Double; reps live as Int in the
    /// model. Round on every set so the model stays integer-clean.
    private var repsBinding: Binding<Double> {
        Binding(
            get: { Double(set.reps) },
            set: {
                set.reps = Int($0.rounded())
                hasPendingChanges = true
            }
        )
    }

    private var weightBinding: Binding<Double> {
        Binding(
            get: { set.weight },
            set: {
                set.weight = $0
                hasPendingChanges = true
            }
        )
    }

    private var durationBinding: Binding<Double> {
        Binding(
            get: { set.duration },
            set: {
                set.duration = $0
                hasPendingChanges = true
            }
        )
    }

    /// Writing RIR here marks it explicitly logged, so effort stats
    /// can tell a real reading apart from the default-2 placeholder.
    private var rirBinding: Binding<Int> {
        Binding(
            get: { set.repsInReserve },
            set: {
                set.repsInReserve = $0
                set.rirLogged = true
                saveImmediately()
            }
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
                        label: loadMode.inputLabel.lowercased(),
                        pointsPerStep: 8,
                        valueFontSize: 40,
                        verticalPadding: 14,
                        onScrubEnded: saveSettledScrub
                    )

                    NumberScrubber(
                        value: repsBinding,
                        range: 1...30,
                        step: 1,
                        pointsPerStep: 16,
                        unit: "reps",
                        label: "reps",
                        valueFontSize: 32,
                        verticalPadding: 12,
                        onScrubEnded: saveSettledScrub
                    )

                    if modality == .dynamicStrength {
                        RIRSelector(value: rirBinding)
                    }

                case .duration:
                    NumberScrubber(
                        value: durationBinding,
                        range: DurationFormatter.scrubRange,
                        step: DurationFormatter.scrubStep,
                        pointsPerStep: 10,
                        label: modality.durationLabelLowercased,
                        valueFontSize: 40,
                        verticalPadding: 14,
                        formatter: { DurationFormatter.string($0) },
                        onScrubEnded: saveSettledScrub
                    )

                    WeightScrubber(
                        canonicalWeight: weightBinding,
                        purpose: .strength,
                        label: loadMode.inputLabel.lowercased(),
                        pointsPerStep: 8,
                        valueFontSize: 32,
                        verticalPadding: 12,
                        onScrubEnded: saveSettledScrub
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
                        saveSettledScrub()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onChange(of: scenePhase) { oldPhase, phase in
            if oldPhase == .active, phase != .active {
                saveSettledScrub()
            }
        }
        .onDisappear { saveSettledScrub() }
        .saveErrorAlert($saveError)
    }

    private func saveSettledScrub() {
        guard hasPendingChanges else { return }
        if let onScrubEnded {
            onScrubEnded()
            hasPendingChanges = false
            return
        }
        persistLocalChanges()
    }

    private func saveImmediately() {
        if let onImmediateUpdate {
            onImmediateUpdate()
            hasPendingChanges = false
            return
        }
        hasPendingChanges = true
        persistLocalChanges()
    }

    private func persistLocalChanges() {
        do {
            try modelContext.saveOrRollback()
            hasPendingChanges = false
        } catch {
            hasPendingChanges = false
            saveError = SaveErrorBox(error)
        }
    }
}

#Preview {
    EditSetSheet(set: WorkoutSet(weight: 135, reps: 8, isCompleted: true))
        .preferredColorScheme(.dark)
}
