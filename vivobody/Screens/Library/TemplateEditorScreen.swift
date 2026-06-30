//
//  TemplateEditorScreen.swift
//  vivobody
//
//  Create-or-edit builder for one workout template, presented as a
//  modal sheet from Library (toolbar "+" / empty-state CTA for new,
//  template-row tap for edit). One screen serves both modes via
//  `TemplateEditorTarget`.
//
//  Flow (first principles):
//    1. Name the template — a single hairline-underlined field.
//    2. "Add exercise" → ExercisePickerSheet in picks-on-tap mode:
//       selecting a row commits it immediately and dismisses.
//    3. The pick flows into ConfigureExerciseSheet — a bottom sheet
//       where Sets / Target reps / Weight are scrubbed as huge
//       monospaced numerals, then dropped into the template.
//    4. Tap any configured row to revise it in the same sheet.
//
//  Nothing touches SwiftData until Save. The editing buffer is a
//  value-type `TemplateDraft`; the @Model objects (WorkoutTemplate /
//  TemplateExercise) are constructed or mutated only in `save()`, so
//  the name field has zero observation cost per keystroke and a
//  cancelled sheet never pollutes the store.
//

import SwiftUI
import SwiftData

struct TemplateEditorScreen: View {
    let target: TemplateEditorTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var draft: TemplateDraft

    /// A catalog pick captured from the picker, held until the picker
    /// finishes dismissing so the configure sheet can present cleanly
    /// (sequential-sheet pattern — never two sheets at once).
    @State private var pendingPick: ExerciseCatalogItem? = nil

    @State private var showPicker: Bool = false
    @State private var configureTarget: ConfigureExerciseTarget? = nil
    @State private var saveError: SaveErrorBox? = nil
    @State private var blockedPerSetExerciseName: String? = nil

    /// Auto-focus the name field on a new template — first action is
    /// always "name the thing." Skipped on edit so we don't shove the
    /// keyboard over existing content.
    @FocusState private var nameFieldFocused: Bool

    init(target: TemplateEditorTarget) {
        self.target = target
        switch target {
        case .new:
            _draft = State(wrappedValue: TemplateDraft())
        case .edit(let existing):
            var d = TemplateDraft()
            d.name = existing.name
            d.exercises = existing.orderedExercises.map { ExerciseDraft(from: $0) }
            d.scheduledWeekdays = existing.scheduledWeekdays
            _draft = State(wrappedValue: d)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    nameField
                    scheduleSection
                    exercisesSection
                    addExerciseButton
                }
                .padding(.top, Space.md)
                .padding(.bottom, Space.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .screenBackground()
            .navigationTitle(isNewMode ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .bold()
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showPicker, onDismiss: presentConfigureForPendingPick) {
                ExercisePickerSheet(
                    onPick: { item in
                        pendingPick = item
                        showPicker = false
                    },
                    picksOnTap: true
                )
            }
            .sheet(item: $configureTarget) { cfg in
                ConfigureExerciseSheet(target: cfg) { updated in
                    applyConfigured(updated)
                }
            }
            .onAppear {
                if isNewMode { nameFieldFocused = true }
            }
            .saveErrorAlert($saveError)
            .alert(
                "Per-set programming",
                isPresented: Binding(
                    get: { blockedPerSetExerciseName != nil },
                    set: { if !$0 { blockedPerSetExerciseName = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    blockedPerSetExerciseName = nil
                }
            } message: {
                Text("\(blockedPerSetExerciseName ?? "This exercise") uses explicit set-by-set programming. This quick editor only changes uniform exercises, so the per-set rows were left unchanged.")
            }
        }
    }

    // MARK: - Derived

    private var isNewMode: Bool {
        if case .new = target { return true }
        return false
    }

    private var canSave: Bool {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !draft.exercises.isEmpty
    }

    // MARK: - Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Name")
                .sectionLabelStyle(Opacity.medium)

            TextField("", text: $draft.name, prompt: Text("e.g. Push Day A")
                .foregroundStyle(Ink.quaternary))
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .textInputAutocapitalization(.words)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .onSubmit { nameFieldFocused = false }
                .padding(.vertical, Space.sm)
                .accessibilityLabel("Name")

            Rectangle()
                .fill(Surface.edge)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Schedule

    /// Weekday picker — pin the template to the days it should surface
    /// on Today's "Up next" card. Optional; empty means unscheduled.
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Schedule")
                .sectionLabelStyle(Opacity.medium)

            HStack(spacing: Space.sm) {
                ForEach(WeekdayLabels.ordered(), id: \.self) { weekday in
                    weekdayChip(weekday)
                }
            }

            Text("Pin to weekdays to queue it on Today. Optional.")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weekdayChip(_ weekday: Int) -> some View {
        let isOn = draft.scheduledWeekdays.contains(weekday)
        return Button {
            toggleScheduleDay(weekday)
        } label: {
            Text(WeekdayLabels.veryShort(weekday))
                .font(Typography.sectionHeading)
                .foregroundStyle(isOn ? Color.black : Ink.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Space.tapMin)
                .background(
                    Capsule(style: .continuous)
                        .fill(isOn ? Tint.primary : Surface.cardTint)
                        .accessibilityHidden(true)
                )
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
        .accessibilityValue(isOn ? "Scheduled" : "Not scheduled")
        .accessibilityHint("Toggles scheduling the template on this weekday")
    }

    private func toggleScheduleDay(_ weekday: Int) {
        if let idx = draft.scheduledWeekdays.firstIndex(of: weekday) {
            draft.scheduledWeekdays.remove(at: idx)
        } else {
            draft.scheduledWeekdays.append(weekday)
            draft.scheduledWeekdays.sort()
        }
        Haptics.selection()
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(
                title: "Exercises",
                trailing: draft.exercises.isEmpty ? nil : "\(draft.exercises.count)"
            )

            if draft.exercises.isEmpty {
                emptyPrompt
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(draft.exercises.enumerated()), id: \.element.id) { idx, exercise in
                        if idx > 0 { SectionDivider() }
                        exerciseRow(exercise)
                    }
                }
            }
        }
    }

    private var emptyPrompt: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("No exercises yet")
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.secondary)
            Text("Add one to start shaping this template.")
                .font(Typography.body)
                .foregroundStyle(Ink.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Space.sm)
    }

    private func exerciseRow(_ exercise: ExerciseDraft) -> some View {
        Button {
            if exercise.isPerSet {
                blockedPerSetExerciseName = exercise.name
            } else {
                configureTarget = .editing(exercise)
            }
        } label: {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(Typography.title)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(exercise.summary(unit: unit))
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }

                Spacer(minLength: Space.sm)

                Text(exercise.group.displayName)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            .frame(minHeight: Space.rowMin)
            .padding(.vertical, Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                remove(exercise.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private var addExerciseButton: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "plus")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Tint.inProgress)
                Text("Add exercise")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .coloredGlassControl(cornerRadius: Radius.pill, fill: nil)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    /// Runs once the picker has fully dismissed. Presenting the
    /// configure sheet here (rather than from the picker's onPick)
    /// guarantees the picker is gone first, avoiding the "already
    /// presenting" sheet glitch.
    private func presentConfigureForPendingPick() {
        guard let item = pendingPick else { return }
        pendingPick = nil
        configureTarget = .adding(item)
    }

    /// Commit a configured exercise back into the draft — replace an
    /// existing row (edit) or append a new one (add). Identity is the
    /// draft's stable UUID, preserved across the configure round-trip.
    private func applyConfigured(_ updated: ExerciseDraft) {
        if let idx = draft.exercises.firstIndex(where: { $0.id == updated.id }) {
            draft.exercises[idx] = updated
        } else {
            draft.exercises.append(updated)
        }
        Haptics.soft()
    }

    private func remove(_ id: ExerciseDraft.ID) {
        if reduceMotion {
            draft.exercises.removeAll { $0.id == id }
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                draft.exercises.removeAll { $0.id == id }
            }
        }
        Haptics.soft()
    }

    // MARK: - Save

    private func save() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !draft.exercises.isEmpty else { return }

        var savedTemplate: WorkoutTemplate?

        switch target {
        case .new(let sortOrder):
            let template = WorkoutTemplate(name: trimmedName, sortOrder: sortOrder)
            template.scheduledWeekdays = draft.scheduledWeekdays
            modelContext.insert(template)
            attachExercises(to: template)
            savedTemplate = template

        case .edit(let existing):
            existing.name = trimmedName
            existing.scheduledWeekdays = draft.scheduledWeekdays
            // Replace exercises wholesale. TemplateExercises hold only
            // plan data — no logged history — so nothing of value is
            // discarded.
            for old in existing.exercises {
                modelContext.delete(old)
            }
            existing.exercises.removeAll()
            attachExercises(to: existing)
            savedTemplate = existing
        }

        do {
            try modelContext.saveOrRollback()
            WidgetSnapshotWriter.writeAll(in: modelContext)
            if let template = savedTemplate {
                SpotlightIndexer.index(template)
            }
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.soft()
        dismiss()
    }

    private func attachExercises(to template: WorkoutTemplate) {
        for (i, ed) in draft.exercises.enumerated() {
            // In per-set mode, persist the FIRST row's values into the
            // uniform fields too — they act as a fallback for any
            // legacy code that hasn't learned about `sets` yet.
            let fallbackReps   = ed.isPerSet ? (ed.sets.first?.reps ?? ed.plannedReps) : ed.plannedReps
            let fallbackWeight = ed.isPerSet ? (ed.sets.first?.weight ?? ed.plannedWeight) : ed.plannedWeight
            let fallbackCount  = ed.isPerSet ? max(1, ed.sets.count) : ed.plannedSets

            let fallbackDuration = ed.isPerSet ? (ed.sets.first?.duration ?? ed.plannedDuration) : ed.plannedDuration

            let ex = TemplateExercise(
                name: ed.name,
                catalogItemID: ed.catalogItemID,
                group: ed.group,
                plannedSets: fallbackCount,
                plannedReps: fallbackReps,
                plannedWeight: fallbackWeight,
                muscleInvolvement: Muscle.Involvement(snapshot: ed.muscleInvolvementSnapshot),
                trackingMode: ed.trackingMode,
                plannedDuration: fallbackDuration,
                sortOrder: i
            )
            template.exercises.append(ex)

            if ed.isPerSet {
                for (j, setDraft) in ed.sets.enumerated() {
                    ex.sets.append(
                        TemplateSet(
                            weight: setDraft.weight,
                            reps: setDraft.reps,
                            duration: setDraft.duration,
                            sortOrder: j
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Target

/// Drives the sheet. One Identifiable wrapper means a single sheet
/// declaration can serve both create + edit entry points.
enum TemplateEditorTarget: Identifiable {
    case new(sortOrder: Int)
    case edit(WorkoutTemplate)

    var id: String {
        switch self {
        case .new(let s):  return "new-\(s)"
        case .edit(let t): return "edit-\(t.id.uuidString)"
        }
    }
}
