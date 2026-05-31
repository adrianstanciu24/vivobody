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
            _draft = State(wrappedValue: d)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    nameField
                    exercisesSection
                    addExerciseButton
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.md)
                .padding(.bottom, Space.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                .sectionLabelStyle(0.55)

            TextField("", text: $draft.name, prompt: Text("e.g. Push Day A")
                .foregroundStyle(Ink.quaternary))
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .textInputAutocapitalization(.words)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .onSubmit { nameFieldFocused = false }
                .padding(.vertical, Space.sm)

            Rectangle()
                .fill(Surface.edge)
                .frame(height: 1)
        }
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
            configureTarget = .editing(exercise)
        } label: {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(Typography.title)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                    Text(exercise.summary(unit: unit))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Tint.inProgress)
                Text("Add exercise")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .overlay {
                Capsule().stroke(Surface.edge, lineWidth: 1)
            }
            .contentShape(Capsule())
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
        withAnimation(.easeInOut(duration: 0.18)) {
            draft.exercises.removeAll { $0.id == id }
        }
        Haptics.soft()
    }

    // MARK: - Save

    private func save() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !draft.exercises.isEmpty else { return }

        switch target {
        case .new(let sortOrder):
            let template = WorkoutTemplate(name: trimmedName, sortOrder: sortOrder)
            modelContext.insert(template)
            attachExercises(to: template)

        case .edit(let existing):
            existing.name = trimmedName
            // Replace exercises wholesale. TemplateExercises hold only
            // plan data — no logged history — so nothing of value is
            // discarded.
            for old in existing.exercises {
                modelContext.delete(old)
            }
            existing.exercises.removeAll()
            attachExercises(to: existing)
        }

        try? modelContext.save()
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
                group: ed.group,
                plannedSets: fallbackCount,
                plannedReps: fallbackReps,
                plannedWeight: fallbackWeight,
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
