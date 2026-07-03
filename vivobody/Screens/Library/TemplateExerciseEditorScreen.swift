//
//  TemplateExerciseEditorScreen.swift
//  vivobody
//
//  Edits a single TemplateExercise in the app's instrument language:
//  full-bleed on black, a type-forward kicker header, and the planned
//  Sets / Reps / Weight set as huge monospaced numerals you scrub
//  with a vertical drag — the same BareScrubber the live workout hero
//  uses, so editing a template feels identical to editing mid-set.
//  Drag up to increase, down to decrease; haptic tick on every step;
//  rubber-band at the range walls. Values bind straight to the @Model
//  via @Bindable + modelContext.save() on change, so edits flow back
//  to the parent list summary the instant a drag ends.
//
//  Why scrubbers, not iOS Form Steppers: the active workout sets the
//  app's visual + interaction language. The template editor has to
//  match — otherwise template-side editing feels like a different app
//  from workout-side editing.
//

import SwiftUI
import SwiftData

struct TemplateExerciseEditorScreen: View {
    @Bindable var exercise: TemplateExercise

    @Environment(\.modelContext) private var modelContext

    @State private var saveError: SaveErrorBox? = nil

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                header

                valueRow(label: "Sets") {
                    BareScrubber(
                        value: setsBinding,
                        range: 1...12,
                        step: 1,
                        pointsPerStep: 18,
                        fontSize: 64,
                        numberColor: Ink.primary,
                        accessibilityLabel: "Sets"
                    )
                }

                SectionDivider()

                switch exercise.trackingMode {
                case .reps:
                    valueRow(label: "Reps") {
                        BareScrubber(
                            value: repsBinding,
                            range: 1...50,
                            step: 1,
                            pointsPerStep: 16,
                            fontSize: 64,
                            numberColor: Ink.primary,
                            accessibilityLabel: "Reps"
                        )
                    }
                case .duration:
                    valueRow(label: "Hold") {
                        BareScrubber(
                            value: durationBinding,
                            range: DurationFormatter.scrubRange,
                            step: DurationFormatter.scrubStep,
                            pointsPerStep: 10,
                            fontSize: 64,
                            numberColor: Ink.primary,
                            formatter: { DurationFormatter.string($0) },
                            accessibilityLabel: "Hold"
                        )
                    }
                }

                SectionDivider()

                valueRow(label: exercise.trackingMode == .duration ? "Added load" : "Weight") {
                    BareScrubber(
                        value: weightDisplayBinding,
                        range: unit.strengthRange,
                        step: unit.strengthStep,
                        pointsPerStep: 8,
                        fontSize: 64,
                        unit: unit.symbol,
                        unitFontSize: 16,
                        numberColor: Ink.primary,
                        unitColor: Ink.tertiary,
                        accessibilityLabel: exercise.trackingMode == .duration ? "Added load" : "Weight",
                        tickTone: .deep
                    )
                }

                if exercise.hasPerSetData {
                    SectionDivider()
                    perSetNotice
                }
            }
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
        // Persist on every step. SwiftData writes are cheap and
        // this keeps the parent list summary fresh as soon as the
        // user finishes a drag.
        .onChange(of: exercise.plannedSets) { _, _ in save() }
        .onChange(of: exercise.plannedReps) { _, _ in save() }
        .onChange(of: exercise.plannedWeight) { _, _ in save() }
        .onChange(of: exercise.plannedDuration) { _, _ in save() }
        .saveErrorAlert($saveError)
    }

    // MARK: - Header

    /// Type-forward identity: the muscle group as a quiet kicker, the
    /// exercise name as the title. No stripe, no card — the name
    /// carries the screen.
    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(exercise.group.displayName)
                .sectionLabelStyle(Opacity.soft)
            Text(exercise.name)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Value row

    /// A small sentence-case label above a bare scrubbing numeral.
    /// The numeral is the control; the label just names what it sets.
    private func valueRow<S: View>(
        label: String,
        @ViewBuilder scrubber: () -> S
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(label)
                .sectionLabelStyle(Opacity.medium)
            scrubber()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Per-set notice

    /// Surfaces when the template has explicit pyramid/wave rows.
    /// The Sets/Reps/Weight scrubbers above act as fallback values
    /// in that mode — the per-set rows are the source of truth at
    /// runtime. Per-set editing UI is future work.
    private var perSetNotice: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Per-set programming")
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.secondary)
            Text("This exercise uses pyramid / wave programming with \(exercise.orderedSets.count) explicit set rows. The values above are fallbacks — the per-set rows are the source of truth at runtime.")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Bindings

    /// BareScrubber scrubs Double — bridge from / to the model's Int
    /// storage. Conversion happens at the binding boundary so the
    /// rest of the app never sees a Double set count.
    private var setsBinding: Binding<Double> {
        Binding(
            get: { Double(exercise.plannedSets) },
            set: { exercise.plannedSets = Int($0) }
        )
    }

    private var repsBinding: Binding<Double> {
        Binding(
            get: { Double(exercise.plannedReps) },
            set: { exercise.plannedReps = Int($0) }
        )
    }

    private var durationBinding: Binding<Double> {
        Binding(
            get: { exercise.plannedDuration },
            set: { exercise.plannedDuration = $0 }
        )
    }

    /// Scrubbed in display units; converted to/from canonical lb at
    /// the binding boundary so the model only ever stores lb.
    private var weightDisplayBinding: Binding<Double> {
        Binding(
            get: { WeightFormatter.toDisplay(exercise.plannedWeight, unit: unit) },
            set: { exercise.plannedWeight = WeightFormatter.toCanonical($0, unit: unit) }
        )
    }

    // MARK: - Persistence

    private func save() {
        do {
            try modelContext.saveOrRollback()
            WidgetSnapshotWriter.writeAll(in: modelContext)
        } catch {
            saveError = SaveErrorBox(error)
        }
    }
}
