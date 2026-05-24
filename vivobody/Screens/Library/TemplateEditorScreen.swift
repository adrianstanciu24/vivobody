//
//  TemplateEditorScreen.swift
//  vivobody
//
//  Create-or-edit screen for one workout template. Presented as a
//  sheet from Library (toolbar "+" / empty-state CTA) or from the
//  template detail screen (overflow → Edit). One screen handles
//  both modes via `TemplateEditorTarget`.
//
//  Architecture (first principles):
//    • Editing buffer is a value-type `TemplateDraft` in @State.
//      The @Model objects (WorkoutTemplate / TemplateExercise) are
//      constructed or mutated only at Save — so the TextField has
//      no SwiftData observation cost on every keystroke.
//    • Draft is initialised in `init` (eager), not in onAppear, so
//      the body renders fully on first pass.
//    • Per-exercise editing is inline expand/collapse — tap a row
//      to expand into 3 NumberScrubbers; tap again to collapse.
//      One row expanded at a time.
//

import SwiftUI
import SwiftData

struct TemplateEditorScreen: View {
    let target: TemplateEditorTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var draft: TemplateDraft

    /// Which exercise (if any) currently has its scrubbers expanded.
    /// Inline editing keeps the editor self-contained — no nested
    /// sheets for per-exercise params.
    @State private var expandedExerciseID: ExerciseDraft.ID? = nil

    @State private var showPicker: Bool = false

    /// Auto-focus the name field on a new template — first action
    /// is always "name the thing." Skipped on edit so we don't
    /// shove the keyboard over the user's existing content.
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
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        nameSection
                        exercisesSection
                        addExerciseButton
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(isNewMode ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerSheet { item in
                    let new = ExerciseDraft(from: item)
                    draft.exercises.append(new)
                    expandedExerciseID = new.id
                }
            }
            .onAppear {
                if isNewMode {
                    nameFieldFocused = true
                }
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

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("NAME")

            TextField("e.g. Push Day A", text: $draft.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .onSubmit { nameFieldFocused = false }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("EXERCISES")
                Spacer()
                if !draft.exercises.isEmpty {
                    Text("\(draft.exercises.count)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.40))
                }
            }

            if draft.exercises.isEmpty {
                Text("No exercises yet. Tap below to add some.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.40))
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach($draft.exercises) { $exercise in
                        ExerciseDraftRow(
                            exercise: $exercise,
                            isExpanded: expandedExerciseID == exercise.id,
                            onToggle: { toggleExpand(exercise.id) },
                            onRemove: { remove(exercise.id) }
                        )
                    }
                }
            }
        }
    }

    private var addExerciseButton: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add Exercise")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.50))
    }

    private func toggleExpand(_ id: ExerciseDraft.ID) {
        withAnimation(.easeInOut(duration: 0.18)) {
            expandedExerciseID = (expandedExerciseID == id) ? nil : id
        }
        Haptics.soft()
    }

    private func remove(_ id: ExerciseDraft.ID) {
        withAnimation(.easeInOut(duration: 0.18)) {
            draft.exercises.removeAll { $0.id == id }
            if expandedExerciseID == id { expandedExerciseID = nil }
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
            // Replace exercises wholesale. TemplateExercises hold
            // only plan data — no logged history — so there's
            // nothing of value being discarded.
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
            let fallbackReps  = ed.isPerSet ? (ed.sets.first?.reps ?? ed.plannedReps) : ed.plannedReps
            let fallbackWeight = ed.isPerSet ? (ed.sets.first?.weight ?? ed.plannedWeight) : ed.plannedWeight
            let fallbackCount  = ed.isPerSet ? max(1, ed.sets.count) : ed.plannedSets

            let ex = TemplateExercise(
                name: ed.name,
                group: ed.group,
                plannedSets: fallbackCount,
                plannedReps: fallbackReps,
                plannedWeight: fallbackWeight,
                sortOrder: i
            )
            template.exercises.append(ex)

            if ed.isPerSet {
                for (j, setDraft) in ed.sets.enumerated() {
                    ex.sets.append(
                        TemplateSet(
                            weight: setDraft.weight,
                            reps: setDraft.reps,
                            sortOrder: j
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Exercise row (collapsed / expanded)

private struct ExerciseDraftRow: View {
    @Binding var exercise: ExerciseDraft
    let isExpanded: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// Shown when the user taps "Uniform" while in per-set mode with
    /// non-matching rows. Explains the constraint instead of silently
    /// flattening values.
    @State private var showCollapseBlockedAlert: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            summaryRow
            if isExpanded {
                expandedControls
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var summaryRow: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(exercise.group.accent)
                    .frame(width: 4, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        if exercise.isPerSet {
                            Text("PER SET")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(
                                        Color(.sRGB, red: 1.0, green: 0.78, blue: 0.30, opacity: 1.0)
                                    )
                                )
                        }
                    }
                    Text(exercise.summary(unit: unit))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var expandedControls: some View {
        VStack(spacing: 14) {
            Divider().background(Color.white.opacity(0.06))

            modeToggle

            if exercise.isPerSet {
                perSetRows
            } else {
                uniformControls
            }

            removeButton
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    // MARK: - Mode toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeChip(title: "Uniform", isSelected: !exercise.isPerSet) {
                guard exercise.isPerSet else { return }
                if exercise.canCollapseToUniform {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        exercise.switchToUniform()
                    }
                    Haptics.selection()
                } else {
                    Haptics.rigid()
                    showCollapseBlockedAlert = true
                }
            }
            modeChip(title: "Per Set", isSelected: exercise.isPerSet) {
                guard !exercise.isPerSet else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    exercise.switchToPerSet()
                }
                Haptics.selection()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .alert("Sets aren't uniform", isPresented: $showCollapseBlockedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("To switch back to uniform, every set must share the same weight and reps. Edit them to match first.")
        }
    }

    private func modeChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.75))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.white : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Uniform mode

    private var uniformControls: some View {
        HStack(spacing: 10) {
            scrubber(
                label: "SETS",
                value: Binding(
                    get: { Double(exercise.plannedSets) },
                    set: { exercise.plannedSets = Int($0) }
                ),
                range: 1...10,
                step: 1
            )
            scrubber(
                label: "REPS",
                value: Binding(
                    get: { Double(exercise.plannedReps) },
                    set: { exercise.plannedReps = Int($0) }
                ),
                range: 1...30,
                step: 1
            )
            weightScrubber(
                label: "WEIGHT",
                value: $exercise.plannedWeight
            )
        }
    }

    // MARK: - Per-set mode

    private var perSetRows: some View {
        VStack(spacing: 8) {
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { idx, _ in
                perSetRow(index: idx)
            }

            Button {
                addSet()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Add Set")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func perSetRow(index: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 18, alignment: .center)

            weightScrubber(
                label: "WEIGHT",
                value: Binding(
                    get: { exercise.sets[index].weight },
                    set: { exercise.sets[index].weight = $0 }
                )
            )
            scrubber(
                label: "REPS",
                value: Binding(
                    get: { Double(exercise.sets[index].reps) },
                    set: { exercise.sets[index].reps = max(1, Int($0)) }
                ),
                range: 1...30,
                step: 1
            )

            Button {
                removeSet(at: index)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(canRemoveSets ? .white.opacity(0.55) : .white.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRemoveSets)
            .accessibilityLabel("Remove set \(index + 1)")
        }
    }

    private var canRemoveSets: Bool { exercise.sets.count > 1 }

    private func addSet() {
        // Default new sets to the last row's values — most natural
        // starting point for a pyramid (user typically goes "heavier"
        // and only edits the new one).
        let template = exercise.sets.last
            ?? SetDraft(weight: exercise.plannedWeight, reps: exercise.plannedReps)
        withAnimation(.easeInOut(duration: 0.18)) {
            exercise.sets.append(SetDraft(weight: template.weight, reps: template.reps))
        }
        Haptics.soft()
    }

    private func removeSet(at index: Int) {
        guard canRemoveSets, exercise.sets.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            // remove(at:) returns the removed element; discard so the
            // closure resolves to Void (otherwise withAnimation's
            // generic Result inference produces an "unused" warning).
            _ = exercise.sets.remove(at: index)
        }
        Haptics.soft()
    }

    // MARK: - Remove exercise

    private var removeButton: some View {
        Button(role: .destructive, action: onRemove) {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                Text("Remove")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.red.opacity(0.85))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scrubber helper

    private func scrubber(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String = ""
    ) -> some View {
        NumberScrubber(
            value: value,
            range: range,
            step: step,
            unit: unit,
            label: label,
            valueFontSize: 28,
            verticalPadding: 10
        )
    }

    /// Unit-aware weight scrubber sized to match the editor's
    /// compact `scrubber` helper. Bindings remain canonical lb;
    /// WeightScrubber converts to/from the user's chosen unit
    /// internally and uses the unit's natural step + range.
    private func weightScrubber(
        label: String,
        value: Binding<Double>
    ) -> some View {
        WeightScrubber(
            canonicalWeight: value,
            purpose: .strength,
            label: label,
            valueFontSize: 28,
            verticalPadding: 10
        )
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
