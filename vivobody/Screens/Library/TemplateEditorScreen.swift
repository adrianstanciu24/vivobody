//
//  TemplateEditorScreen.swift
//  vivobody
//
//  Create-or-edit builder for one workout template. `TemplateEditorForm`
//  is the editor; its host decides when the draft reaches SwiftData:
//    • TemplateEditorScreen — the modal sheet from Library (toolbar "+" /
//      empty-state CTA for new, template-row tap for edit in compact
//      width). One sheet serves both modes via `TemplateEditorTarget`.
//      Nothing touches SwiftData until Save, so a cancelled sheet never
//      pollutes the store.
//    • TemplateLiveEditorScreen — the detail beside the Library list,
//      which writes each change through as it happens.
//
//  Flow (first principles):
//    1. Name the template — a single hairline-underlined field.
//    2. "Add exercise" → ExercisePickerSheet in template-add mode:
//       selecting a row commits it immediately and dismisses.
//    3. The pick flows into ConfigureExerciseSheet — a bottom sheet
//       where Sets / Target reps / Weight are scrubbed as huge
//       monospaced numerals, then dropped into the template.
//    4. Tap any configured row to revise it in the same sheet.
//
//  The editing buffer is a value-type `TemplateDraft`, so the name field
//  has zero SwiftData observation cost per keystroke.
//

import SwiftData
import SwiftUI
import VivoKit

struct TemplateEditorScreen: View {
    let target: TemplateEditorTarget
    var onSaved: ((WorkoutTemplate) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var draft: TemplateDraft
    @State private var saveError: SaveErrorBox? = nil

    init(target: TemplateEditorTarget, onSaved: ((WorkoutTemplate) -> Void)? = nil) {
        self.target = target
        self.onSaved = onSaved
        switch target {
        case .new:
            _draft = State(wrappedValue: TemplateDraft())
        case let .edit(existing):
            _draft = State(wrappedValue: TemplateDraft(editing: existing))
        }
    }

    var body: some View {
        NavigationStack {
            TemplateEditorForm(draft: $draft, focusesNameOnAppear: isNewMode)
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
                .saveErrorAlert($saveError)
        }
    }

    private var isNewMode: Bool {
        if case .new = target { return true }
        return false
    }

    private var canSave: Bool {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !draft.exercises.isEmpty
    }

    private func save() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !draft.exercises.isEmpty else { return }

        let template: WorkoutTemplate
        switch target {
        case let .new(sortOrder):
            template = WorkoutTemplate(name: trimmedName, sortOrder: sortOrder)
            modelContext.insert(template)
        case let .edit(existing):
            template = existing
            template.name = trimmedName
        }
        template.scheduledWeekdays = draft.scheduledWeekdays
        draft.replaceExercises(of: template, in: modelContext)

        do {
            try modelContext.saveOrRollback()
            WidgetSnapshotWriter.writeAll(in: modelContext)
            SpotlightIndexer.index(template)
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.soft()
        onSaved?(template)
        dismiss()
    }
}

/// The editor body shared by the sheet and the live detail. It edits only
/// the bound draft; the host owns persistence.
struct TemplateEditorForm: View {
    @Binding var draft: TemplateDraft
    let focusesNameOnAppear: Bool

    @Environment(\.sessionAnalytics) private var sessionAnalytics
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    /// A catalog pick captured from the picker, held until the picker
    /// finishes dismissing so the configure sheet can present cleanly
    /// (sequential-sheet pattern — never two sheets at once).
    @State private var pendingPick: ExerciseCatalogItem? = nil

    @State private var showPicker: Bool = false
    @State private var configureTarget: ConfigureExerciseTarget? = nil
    @State private var blockedPerSetExerciseName: String? = nil
    @State private var isEditing: Bool = false

    /// Auto-focus the name field on a new template — first action is
    /// always "name the thing." Skipped on edit so we don't shove the
    /// keyboard over existing content.
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                editList
            } else {
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
            }
        }
        .screenBackground()
        .sheet(isPresented: $showPicker, onDismiss: presentConfigureForPendingPick) {
            ExercisePickerSheet(
                purpose: .addToTemplate,
                onPick: { item in
                    pendingPick = item
                    showPicker = false
                }
            )
        }
        .sheet(item: $configureTarget) { cfg in
            ConfigureExerciseSheet(target: cfg, history: history(for: cfg)) { updated in
                applyConfigured(updated)
            }
        }
        .onAppear {
            if focusesNameOnAppear { nameFieldFocused = true }
        }
        .onChange(of: draft.exercises.isEmpty) { _, isEmpty in
            if isEmpty { isEditing = false }
        }
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

    private func history(for target: ConfigureExerciseTarget) -> ExerciseHistorySummary? {
        switch target {
        case let .adding(item): sessionAnalytics?.exerciseHistorySummaries[item.historyKey]
        case let .editing(draft): sessionAnalytics?.exerciseHistorySummaries[draft.historyKey]
        }
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
            exercisesHeader

            if draft.exercises.isEmpty {
                emptyPrompt
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(draft.exercises.enumerated()), id: \.element.id) { idx, exercise in
                        if idx > 0 { seamControl(before: idx) }
                        exerciseRow(exercise, at: idx)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var exercisesHeader: some View {
        if draft.exercises.isEmpty {
            SectionHeader(title: "Exercises")
        } else {
            HStack(alignment: .center) {
                SectionHeader(title: "Exercises")
                Spacer(minLength: Space.sm)
                editToggle
                    .padding(.top, Space.sm)
            }
        }
    }

    private var editToggle: some View {
        Button {
            setEditing(!isEditing)
        } label: {
            Text(isEditing ? "Done" : "Edit")
                .font(Typography.sectionHeading)
                .foregroundStyle(Tint.inProgress)
                .frame(minWidth: Space.tapMin, minHeight: Space.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("templateEditToggle")
        .accessibilityHint(isEditing ? "Returns to the exercise details" : "Shows delete buttons and drag handles for the exercises")
    }

    private func setEditing(_ on: Bool) {
        if reduceMotion {
            isEditing = on
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { isEditing = on }
        }
        Haptics.selection()
    }

    // MARK: - Edit

    /// Compact list for deleting and reordering exercises. A native List
    /// is used only here: in the detailed view the seam buttons sit
    /// between rows and would compete with a drag gesture.
    private var editList: some View {
        let tags = SupersetGrouping.tags(inIDs: draft.exercises.map(\.supersetID))
        return List {
            exercisesHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Space.md, leading: Space.gutter, bottom: Space.sm, trailing: Space.gutter))

            ForEach(Array(draft.exercises.enumerated()), id: \.element.id) { idx, exercise in
                editRow(exercise, tag: tags[idx])
                    .accessibilityActions { moveActions(at: idx) }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Surface.edge)
                    .listRowInsets(EdgeInsets(top: 0, leading: Space.gutter, bottom: 0, trailing: Space.gutter))
            }
            .onMove { source, destination in
                guard let from = source.first else { return }
                moveExercise(from: from, to: destination, animated: false)
            }
            .onDelete(perform: removeExercises)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }

    private func editRow(_ exercise: ExerciseDraft, tag: String?) -> some View {
        HStack(spacing: Space.md) {
            Capsule(style: .continuous)
                .fill(tag == nil ? Color.clear : Tint.inProgress)
                .frame(width: 3)
                .padding(.vertical, Space.xs)
                .accessibilityHidden(true)
            if let tag {
                Text(tag)
                    .font(Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(Tint.inProgress)
                    .accessibilityLabel("Superset position \(tag)")
            }
            Text(exercise.name)
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .frame(minHeight: Space.tapMin)
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func moveActions(at index: Int) -> some View {
        if index > 0 {
            Button("Move Up") { moveExercise(from: index, to: index - 1) }
        }
        if index < draft.exercises.count - 1 {
            Button("Move Down") { moveExercise(from: index, to: index + 2) }
        }
    }

    /// `destination` is an insertion offset into the current order, as
    /// `onMove` reports it.
    private func moveExercise(from source: Int, to destination: Int, animated: Bool = true) {
        let result = SupersetGrouping.moving(
            from: source,
            to: destination,
            inIDs: draft.exercises.map(\.supersetID)
        )
        guard result.order != Array(draft.exercises.indices) else { return }
        var reordered = result.order.map { draft.exercises[$0] }
        for i in reordered.indices {
            reordered[i].supersetID = result.ids[i]
        }
        if animated, !reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { draft.exercises = reordered }
        } else {
            draft.exercises = reordered
        }
        Haptics.selection()
    }

    // MARK: - Superset seam

    /// The tappable gap between two adjacent exercises — where the
    /// superset relationship lives. Unlinked it reads as the section
    /// divider carrying a quiet chain glyph; linked it becomes a volt
    /// bracket labelled SUPERSET. One tap links, one tap reverses.
    private func seamControl(before index: Int) -> some View {
        let seam = index - 1
        let ids = draft.exercises.map(\.supersetID)
        let linked = SupersetGrouping.isSeamLinked(at: seam, inIDs: ids)
        let letter = SupersetGrouping.groupLetter(at: seam, inIDs: ids)
        return Button {
            toggleSeam(at: seam)
        } label: {
            HStack(spacing: Space.sm) {
                seamLine(linked: linked)
                Image(systemName: "link")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(linked ? Tint.inProgress : Ink.quaternary)
                if linked, let letter {
                    // The group letter makes boundaries legible: two
                    // seams reading "Superset A" are one group; "A" then
                    // "B" means two separate supersets.
                    Text("Superset \(letter)")
                        .panelLegendType()
                        .foregroundStyle(Tint.inProgress)
                }
                seamLine(linked: linked)
            }
            .frame(maxWidth: .infinity, minHeight: Space.tapMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            linked
                ? "Unlink superset \(letter ?? "") between \(draft.exercises[seam].name) and \(draft.exercises[index].name)"
                : "Link \(draft.exercises[seam].name) and \(draft.exercises[index].name) as a superset"
        )
    }

    private func seamLine(linked: Bool) -> some View {
        Rectangle()
            .fill(linked ? Tint.inProgress.opacity(0.35) : Surface.edge)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private func toggleSeam(at seam: Int) {
        let ids = draft.exercises.map(\.supersetID)
        let updated = SupersetGrouping.isSeamLinked(at: seam, inIDs: ids)
            ? SupersetGrouping.unlinkingSeam(at: seam, inIDs: ids)
            : SupersetGrouping.linkingSeam(at: seam, inIDs: ids)
        for (i, id) in updated.enumerated() {
            draft.exercises[i].supersetID = id
        }
        Haptics.soft()
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

    private func exerciseRow(_ exercise: ExerciseDraft, at index: Int) -> some View {
        Button {
            if exercise.isPerSet {
                blockedPerSetExerciseName = exercise.name
            } else {
                configureTarget = .editing(exercise)
            }
        } label: {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Space.sm) {
                        if let tag = supersetTag(for: exercise) {
                            Text(tag)
                                .font(Typography.caption)
                                .monospacedDigit()
                                .foregroundStyle(Tint.inProgress)
                                .accessibilityLabel("Superset position \(tag)")
                        }
                        Text(exercise.name)
                            .font(Typography.title)
                            .foregroundStyle(Ink.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(exercise.loadSummary(history: sessionAnalytics?.exerciseHistorySummaries[exercise.historyKey], unit: unit))
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
        .accessibilityActions { moveActions(at: index) }
        .contextMenu {
            if index > 0 {
                Button {
                    moveExercise(from: index, to: index - 1)
                } label: {
                    Label("Move Up", systemImage: "arrow.up")
                }
            }
            if index < draft.exercises.count - 1 {
                Button {
                    moveExercise(from: index, to: index + 2)
                } label: {
                    Label("Move Down", systemImage: "arrow.down")
                }
            }
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
        _ = sessionAnalytics?.resolvedExerciseHistory(in: modelContext)
        configureTarget = .adding(item)
    }

    /// Commit a configured exercise back into the draft — replace an
    /// existing row (edit) or append a new one (add). Identity is the
    /// draft's stable UUID, preserved across the configure round-trip.
    private func applyConfigured(_ updated: ExerciseDraft) {
        var classified = updated
        if classified.classification == nil {
            switch configureTarget {
            case let .some(.adding(item)):
                classified.classification = item.classification
            case let .some(.editing(original)):
                classified.classification = original.classification
            case nil:
                break
            }
        }

        if let idx = draft.exercises.firstIndex(where: { $0.id == classified.id }) {
            // The superset link belongs to the row's position in the
            // list, not to the configure sheet — carry it across the
            // round-trip.
            classified.supersetID = draft.exercises[idx].supersetID
            draft.exercises[idx] = classified
        } else {
            draft.exercises.append(classified)
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
        normalizeSupersets()
        Haptics.soft()
    }

    /// The List animates its own row removal.
    private func removeExercises(at offsets: IndexSet) {
        draft.exercises.remove(atOffsets: offsets)
        normalizeSupersets()
        Haptics.soft()
    }

    /// A group whose member was removed may be down to one exercise —
    /// dissolve it back to straight sets.
    private func normalizeSupersets() {
        let normalized = SupersetGrouping.normalizing(draft.exercises.map(\.supersetID))
        for (i, groupID) in normalized.enumerated() {
            draft.exercises[i].supersetID = groupID
        }
    }

    /// "A1"-style tag for a draft row, derived from the current list.
    private func supersetTag(for exercise: ExerciseDraft) -> String? {
        guard let index = draft.exercises.firstIndex(where: { $0.id == exercise.id }) else {
            return nil
        }
        return SupersetGrouping.tag(at: index, inIDs: draft.exercises.map(\.supersetID))
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
        case let .new(s): "new-\(s)"
        case let .edit(t): "edit-\(t.id.uuidString)"
        }
    }
}
