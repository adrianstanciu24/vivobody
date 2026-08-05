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
//  Visually it speaks the active card's instrument language: bare
//  scrubbable numerals (no chip, no card chrome) with silkscreen
//  legends, laid out like a smaller echo of the hero — weight over
//  "× reps", or duration over its load line. The sheet sits on an
//  elevated surface (bright card tint over black) so it reads as a
//  layer ABOVE the panel, never as more of the same black.
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

    /// Measured height of the instrument cluster. The sheet hugs its
    /// content instead of claiming the medium detent — mode, load
    /// legends, and Dynamic Type all change the cluster's height, so
    /// it is read from layout rather than hardcoded.
    @State private var contentHeight: CGFloat = 400

    /// The inline navigation bar sits above the measured content and
    /// must be added back into the detent height.
    private static let navigationBarAllowance: CGFloat = 56

    /// The set's tracking mode comes from its owning exercise —
    /// decides whether we edit reps or a timed effort.
    private var mode: TrackingMode { self.set.exercise?.trackingMode ?? .reps }
    private var modality: ExerciseModality { self.set.exercise?.modality ?? .dynamicStrength }
    private var loadMode: ExerciseLoadMode { self.set.exercise?.loadMode ?? .external }

    /// 1-based position of this set inside its exercise — the sheet
    /// names what it's editing ("Set 2 of 3") so a pip tap never
    /// opens onto an anonymous number.
    private var setOrdinal: Int? {
        guard let exercise = set.exercise else { return nil }
        return exercise.orderedSets.firstIndex(where: { $0.id == set.id }).map { $0 + 1 }
    }

    private var setCount: Int {
        self.set.exercise?.orderedSets.count ?? 0
    }

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
            VStack(alignment: .leading, spacing: Space.xl) {
                if let setOrdinal {
                    Text("Set \(setOrdinal) of \(setCount)")
                        .panelLegend()
                }

                switch mode {
                case .reps:
                    VStack(alignment: .leading, spacing: Space.sm) {
                        // A bare value plus its unit explains itself for
                        // plain weight; added load and assistance keep
                        // their semantic noun, matching the hero.
                        if loadMode != .external {
                            Text(loadMode.inputLabel)
                                .panelLegend()
                        }
                        WeightScrubber(
                            canonicalWeight: weightBinding,
                            purpose: .strength,
                            label: loadMode.inputLabel,
                            pointsPerStep: 8,
                            valueFontSize: 96,
                            presentation: .bare,
                            onScrubEnded: saveSettledScrub
                        )

                        HStack(alignment: .center, spacing: Space.sm) {
                            Text("×")
                                .font(Typography.statValue)
                                .foregroundStyle(Ink.quaternary)
                                .accessibilityHidden(true)
                            BareScrubber(
                                value: repsBinding,
                                range: 1...30,
                                step: 1,
                                pointsPerStep: 16,
                                fontSize: 46,
                                unit: "reps",
                                unitFontSize: 14,
                                numberColor: Ink.primary.opacity(Opacity.strong),
                                unitColor: Ink.tertiary,
                                accessibilityLabel: "Reps",
                                hitSlop: 18,
                                showsRail: true,
                                railClearance: 26,
                                onScrubEnded: saveSettledScrub
                            )
                            Spacer(minLength: 0)
                        }
                    }

                    if modality == .dynamicStrength {
                        RIRSelector(value: rirBinding)
                    }

                case .duration:
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text(modality.durationLabel)
                            .panelLegend()
                        BareScrubber(
                            value: durationBinding,
                            range: DurationFormatter.scrubRange,
                            step: DurationFormatter.scrubStep,
                            pointsPerStep: 10,
                            fontSize: 96,
                            numberColor: Ink.primary,
                            formatter: { DurationFormatter.string($0) },
                            accessibilityLabel: modality.durationLabel,
                            fitsWidth: true,
                            hitSlop: 12,
                            showsRail: true,
                            onScrubEnded: saveSettledScrub
                        )

                        if loadMode != .external {
                            Text(loadMode.inputLabel)
                                .panelLegend()
                                .padding(.top, Space.sm)
                        }
                        HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                            Text(loadMode.inputOperatorSymbol)
                                .font(Typography.statValue)
                                .foregroundStyle(Ink.quaternary)
                                .accessibilityHidden(true)
                            WeightScrubber(
                                canonicalWeight: weightBinding,
                                purpose: .strength,
                                label: loadMode.inputLabel,
                                pointsPerStep: 8,
                                valueFontSize: 40,
                                presentation: .bare,
                                onScrubEnded: saveSettledScrub
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, Space.xxl)
            .padding(.bottom, Space.xxl)
            // Measure the hugged cluster BEFORE the fill frame below,
            // so the reading can never chase the detent it drives.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                contentHeight = height
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // Lifted off the panel: bright card tint over an opaque
            // black base, so the sheet reads as a surface floating
            // above the workout instead of more of the same black.
            .background(
                Surface.cardTintBright
                    .background(Surface.background)
                    .ignoresSafeArea()
            )
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
        .presentationDetents([.height(contentHeight + Self.navigationBarAllowance)])
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
