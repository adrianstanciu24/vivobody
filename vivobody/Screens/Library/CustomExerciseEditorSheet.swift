//
//  CustomExerciseEditorSheet.swift
//  vivobody
//
//  Create-or-edit sheet for a catalog entry. Used in three modes:
//    • Create    — `target = .create`, builds a new ExerciseCatalogItem
//      and inserts it into the context on Save.
//    • Edit      — `target = .edit(item)`, mutates the existing entry's
//      properties in place. Bundled entries get a restricted
//      defaults-only form so their history identity stays stable.
//    • Duplicate — `target = .duplicate(item)`, create mode prefilled
//      from a bundled entry: the copy keeps the source's semantics but
//      gets a fresh identity (nil catalogID) and starts its own
//      history, which the sheet says out loud.
//
//  Value-type draft buffer (CatalogDraft) — the @Model is only
//  touched on Save, so the editor can be dismissed without polluting
//  the catalog with half-typed entries.
//

import SwiftData
import SwiftUI
import VivoKit

enum CatalogEditorTarget: Identifiable {
    case create
    case edit(ExerciseCatalogItem)
    /// Fork a bundled exercise into a fully editable user-created
    /// copy. The copy keeps the source's semantics but gets a fresh
    /// identity, so logged history stays with the bundled original.
    case duplicate(ExerciseCatalogItem)

    var id: String {
        switch self {
        case .create: "create"
        case let .edit(item): "edit-\(item.id)"
        case let .duplicate(item): "duplicate-\(item.id)"
        }
    }
}

private enum CatalogPicker: String, Identifiable {
    case muscleGroup
    case equipment
    case modality
    case trainingRole
    case movementPattern
    case loadMode

    var id: String {
        rawValue
    }
}

private enum CatalogValidationAnchor: Hashable {
    case name
    case muscles
    case movementPattern
    case direction
    case loadMode
    case aliases
}

struct CustomExerciseEditorSheet: View {
    let target: CatalogEditorTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Used only to enforce the same globally-unique canonical-name /
    /// alias namespace as the bundled catalog. The edited item is
    /// excluded from its own collision check.
    @Query private var catalogItems: [ExerciseCatalogItem]

    @State private var draft: CatalogDraft

    @State private var saveError: SaveErrorBox? = nil
    @State private var isMuscleEditorPresented = false
    @State private var activePicker: CatalogPicker? = nil
    @State private var showsValidationErrors = false
    /// One-shot guard for the duplicate name prefill — onAppear fires
    /// again when child sheets dismiss, and the user's typed name
    /// must never be overwritten after the first resolution.
    @State private var didResolveDuplicateName = false

    @FocusState private var nameFieldFocused: Bool

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    init(target: CatalogEditorTarget) {
        self.target = target
        switch target {
        case .create:
            _draft = State(initialValue: CatalogDraft.empty)
        case let .edit(item):
            _draft = State(initialValue: CatalogDraft(from: item))
        case let .duplicate(item):
            _draft = State(initialValue: CatalogDraft(
                duplicating: item,
                defaultWeight: item.defaultWeightSeed
            ))
        }
    }

    private var isEditMode: Bool {
        if case .edit = target { return true }
        return false
    }

    /// Bundled records own a stable semantic identity. Users may tune
    /// logging defaults, but changing anatomy, mechanics, modality, or
    /// load interpretation in place would merge an unrelated movement
    /// into the bundled exercise's history key.
    private var isBundledEdit: Bool {
        guard case let .edit(item) = target else { return false }
        return item.catalogID != nil && !item.isUserCreated
    }

    /// The bundled exercise a duplicate draft was prefilled from.
    /// Drives the history-split note and the unique-name prefill.
    private var duplicateSource: ExerciseCatalogItem? {
        guard case let .duplicate(item) = target else { return nil }
        return item
    }

    private var editorTitle: String {
        if isBundledEdit { return "Exercise Defaults" }
        switch target {
        case .create: return "New Exercise"
        case .edit: return "Edit Exercise"
        case .duplicate: return "Duplicate Exercise"
        }
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && hasValidMuscleRoles
            && (draft.mechanic != .compound || draft.pattern != nil)
            && (!draft.requiresDirection || draft.direction != nil)
            && !draft.planes.isEmpty
            && hasValidLoadProfile
            && hasUniqueSearchTerms
    }

    private var firstValidationAnchor: CatalogValidationAnchor? {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .name
        }
        if !hasValidMuscleRoles {
            return .muscles
        }
        if draft.mechanic == .compound, draft.pattern == nil {
            return .movementPattern
        }
        if draft.requiresDirection, draft.direction == nil {
            return .direction
        }
        if !hasValidLoadProfile {
            return .loadMode
        }
        if !hasUniqueSearchTerms {
            return .aliases
        }
        return nil
    }

    private var editedItemID: UUID? {
        guard case let .edit(item) = target else { return nil }
        return item.id
    }

    private var hasValidMuscleRoles: Bool {
        let involvement = draft.muscleInvolvement
        guard !involvement.isEmpty else { return false }
        return involvement.primary.contains { $0.group == draft.group }
    }

    private var hasValidLoadProfile: Bool {
        if draft.equipment == .band {
            return draft.loadMode == .nonComparable && draft.bodyweightFraction == 0
        }
        switch draft.loadMode {
        case .external, .nonComparable:
            return draft.bodyweightFraction == 0
        case .bodyweightAdded, .assistanceSubtracted:
            return draft.bodyweightFraction > 0
        }
    }

    private var hasUniqueSearchTerms: Bool {
        let ownTerms = [draft.name] + draft.parsedAliases
        let normalizedOwn = ownTerms.map(\.catalogSearchTermKey)
        guard normalizedOwn.allSatisfy({ !$0.isEmpty }),
              Set(normalizedOwn).count == normalizedOwn.count else { return false }

        let occupied = Set(catalogItems
            .filter { $0.id != editedItemID }
            .flatMap { [$0.name] + $0.aliases }
            .map(\.catalogSearchTermKey))
        return occupied.isDisjoint(with: normalizedOwn)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.section) {
                        if isBundledEdit {
                            bundledIdentitySummary
                            defaultsRow
                        } else {
                            if let source = duplicateSource {
                                duplicateOriginNote(source: source)
                            }
                            editorFields
                        }
                    }
                    .padding(.top, Space.md)
                    .padding(.bottom, Space.xxl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .scrollDismissesKeyboard(.interactively)
                .screenBackground()
                .navigationTitle(editorTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            attemptSave(using: scrollProxy)
                        }
                        .bold()
                    }
                }
                .onAppear {
                    if !isBundledEdit, draft.equipment == .band {
                        draft.loadMode = .nonComparable
                        draft.bodyweightFraction = 0
                    }
                    if let source = duplicateSource, !didResolveDuplicateName {
                        didResolveDuplicateName = true
                        // One-shot prefill: resolve the "(Custom)" name
                        // against the live catalog. A direct fetch, not
                        // the @Query, which may not have delivered on
                        // first appear.
                        let catalog = (try? modelContext.fetch(
                            FetchDescriptor<ExerciseCatalogItem>()
                        )) ?? []
                        let taken = Set(catalog.flatMap { [$0.name] + $0.aliases })
                        draft.name = CatalogDraft.duplicateName(base: source.name, taken: taken)
                    }
                    if !isEditMode {
                        // Focus the name field for create-mode; the
                        // keyboard slides up immediately so the user can
                        // start typing without an extra tap.
                        nameFieldFocused = true
                    }
                }
            }
        }
        .sheet(isPresented: $isMuscleEditorPresented) {
            MuscleInvolvementEditorSheet(
                initialSnapshot: draft.muscleInvolvementSnapshot
            ) { snapshot in
                draft.muscleInvolvementSnapshot = snapshot
            }
        }
        .sheet(item: $activePicker) { picker in
            pickerSheet(for: picker)
        }
        .saveErrorAlert($saveError)
    }

    // MARK: - Fields

    @ViewBuilder
    private var editorFields: some View {
        basicsSection
        classificationSection
        loggingDefaultsSection
        searchSection
    }

    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Basics")
            nameField
                .id(CatalogValidationAnchor.name)
            muscleGroupField
            muscleInvolvementField
                .id(CatalogValidationAnchor.muscles)
            equipmentField
        }
    }

    private var classificationSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Classification")
            modalityField
            mechanicField
            trainingRoleField

            if draft.mechanic == .compound {
                patternField
                    .id(CatalogValidationAnchor.movementPattern)
                    .transition(.move(edge: .top).combined(with: .opacity))

                if draft.requiresDirection {
                    directionField
                        .id(CatalogValidationAnchor.direction)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            planeField
            lateralityField
        }
    }

    private var loggingDefaultsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Logging defaults")

            loadModeField
                .id(CatalogValidationAnchor.loadMode)

            if draft.loadMode == .bodyweightAdded
                || draft.loadMode == .assistanceSubtracted
            {
                bodyweightFractionField
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            defaultsRow
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Search")
            aliasesField
                .id(CatalogValidationAnchor.aliases)
        }
    }

    private var bundledIdentitySummary: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(draft.name)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
            if let execution = draft.execution { ExerciseInstructionSummary(execution: execution) }
            Text("Canonical mechanics, modality, load semantics, and muscle roles are locked so this exercise keeps one stable history identity.")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
        }
    }

    /// The one consequence of duplicating the form can't show: the
    /// copy gets a fresh identity, so logged history stays with the
    /// bundled original.
    private func duplicateOriginNote(source: ExerciseCatalogItem) -> some View {
        Text("Starts its own history. Past workouts stay with \(source.name).")
            .font(Typography.caption)
            .foregroundStyle(Ink.quaternary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Name")
                .sectionLabelStyle(Opacity.medium)

            TextField("", text: $draft.name, prompt: Text("e.g. Bulgarian Split Squat")
                .foregroundStyle(Ink.quaternary))
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .padding(.vertical, Space.sm)
                .accessibilityLabel("Name")

            Rectangle()
                .fill(Surface.edge)
                .frame(height: 1)
                .accessibilityHidden(true)

            if showsValidationErrors,
               draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                validationMessage("Enter an exercise name.")
            }
        }
    }

    private var muscleGroupField: some View {
        pickerRow(title: "Muscle group", value: draft.group.displayName) {
            presentPicker(.muscleGroup)
        }
    }

    private var muscleInvolvementField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            pickerRow(
                title: "Muscles worked",
                subtitle: draft.muscleSummary
            ) {
                nameFieldFocused = false
                isMuscleEditorPresented = true
            }

            if showsValidationErrors, !hasValidMuscleRoles {
                validationMessage("Choose a Primary muscle in the selected muscle group.")
            }
        }
    }

    // MARK: - Equipment

    private var equipmentField: some View {
        pickerRow(title: "Equipment", value: draft.equipment.displayName) {
            presentPicker(.equipment)
        }
    }

    // MARK: - Modality

    private var modalityField: some View {
        pickerRow(title: "Exercise type", value: draft.modality.displayName) {
            presentPicker(.modality)
        }
    }

    // MARK: - Mechanic

    private var mechanicField: some View {
        segmentedField(
            title: "Mechanic",
            selection: Binding(
                get: { draft.mechanic },
                set: { mechanic in
                    applyAnimatedSelection { applyMechanic(mechanic) }
                }
            ),
            options: Mechanic.allCases,
            label: { $0.displayName }
        )
    }

    // MARK: - Training role

    private var trainingRoleField: some View {
        pickerRow(
            title: "Training role",
            value: draft.trainingRole.displayName
        ) {
            presentPicker(.trainingRole)
        }
    }

    /// Isolation lifts carry no pattern; compound always needs one,
    /// so returning to compound backfills Push/Horizontal instead of
    /// reopening an invalid nil-pattern state.
    private func applyMechanic(_ mechanic: Mechanic) {
        draft.mechanic = mechanic
        switch mechanic {
        case .isolation:
            draft.pattern = nil
            draft.direction = nil
        case .compound:
            if draft.pattern == nil {
                draft.pattern = .push
                draft.direction = .horizontal
            }
        }
    }

    // MARK: - Pattern (compound only)

    private var patternField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            pickerRow(
                title: "Movement pattern",
                value: draft.pattern?.displayName ?? "Choose"
            ) {
                presentPicker(.movementPattern)
            }

            if showsValidationErrors, draft.pattern == nil {
                validationMessage("Choose a compound movement pattern.")
            }
        }
    }

    // MARK: - Direction (push/pull only)

    private var directionField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            segmentedField(
                title: "Direction",
                selection: Binding(
                    get: { draft.direction ?? .horizontal },
                    set: { direction in
                        Haptics.selection()
                        draft.direction = direction
                    }
                ),
                options: PushPullDirection.allCases,
                label: { $0.displayName }
            )

            if showsValidationErrors, draft.direction == nil {
                validationMessage("Choose a push or pull direction.")
            }
        }
    }

    // MARK: - Plane (every exercise)

    private var planeField: some View {
        CatalogPlaneField(
            title: "Plane of movement",
            selection: $draft.planes
        )
    }

    // MARK: - Laterality (every exercise)

    private var lateralityField: some View {
        segmentedField(
            title: "Sides",
            selection: Binding(
                get: { draft.laterality },
                set: { laterality in
                    Haptics.selection()
                    draft.laterality = laterality
                }
            ),
            options: Laterality.allCases,
            label: { $0.displayName }
        )
    }

    // MARK: - Form controls

    /// Metadata with more than three choices uses the canonical row
    /// surface and opens a focused checkmark sheet. This keeps the
    /// editor vertically scannable without clipping options offscreen.
    private func pickerRow(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            KitRow(title: title, subtitle: subtitle) {
                HStack(spacing: Space.sm) {
                    if let value {
                        Text(value)
                            .font(Typography.body)
                            .foregroundStyle(Ink.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Image(systemName: "chevron.right")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value ?? subtitle ?? "Not set")
        .accessibilityHint("Opens choices")
    }

    /// Two- and three-way choices remain visible, but share one track
    /// with a single orange thumb instead of separate glass pills.
    private func segmentedField<Option: Hashable>(
        title: String,
        selection: Binding<Option>,
        options: [Option],
        label: @escaping (Option) -> String
    ) -> some View {
        CatalogSegmentedField(
            title: title,
            selection: selection,
            options: options,
            label: label
        )
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(Typography.caption)
            .foregroundStyle(Tint.danger)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func presentPicker(_ picker: CatalogPicker) {
        nameFieldFocused = false
        activePicker = picker
    }

    private func applyAnimatedSelection(_ changes: () -> Void) {
        Haptics.selection()
        if reduceMotion {
            changes()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                changes()
            }
        }
    }

    @ViewBuilder
    private func pickerSheet(for picker: CatalogPicker) -> some View {
        switch picker {
        case .muscleGroup:
            CatalogChoiceSheet(
                title: "Muscle Group",
                options: MuscleGroup.allCases,
                label: { $0.displayName },
                isSelected: { draft.group == $0 },
                onSelect: applyMuscleGroup
            )

        case .equipment:
            CatalogChoiceSheet(
                title: "Equipment",
                options: Equipment.allCases,
                label: { $0.displayName },
                isSelected: { draft.equipment == $0 },
                onSelect: applyEquipment
            )

        case .modality:
            CatalogChoiceSheet(
                title: "Exercise Type",
                options: ExerciseModality.customExerciseChoices,
                label: { $0.displayName },
                isSelected: { draft.modality == $0 },
                onSelect: applyModality
            )

        case .trainingRole:
            CatalogChoiceSheet(
                title: "Training Role",
                options: TrainingRole.allCases,
                label: { $0.displayName },
                isSelected: { draft.trainingRole == $0 },
                onSelect: { draft.trainingRole = $0 }
            )

        case .movementPattern:
            CatalogChoiceSheet(
                title: "Movement Pattern",
                options: MovementPattern.allCases,
                label: { $0.displayName },
                isSelected: { draft.pattern == $0 },
                onSelect: applyPattern
            )

        case .loadMode:
            CatalogChoiceSheet(
                title: "Load Interpretation",
                options: draft.equipment == .band
                    ? [ExerciseLoadMode.nonComparable]
                    : ExerciseLoadMode.allCases,
                label: { $0.customExerciseChoiceLabel },
                isSelected: { draft.loadMode == $0 },
                onSelect: applyLoadMode
            )
        }
    }

    private func applyMuscleGroup(_ group: MuscleGroup) {
        guard draft.group != group else { return }
        draft.group = group
        // A browse group cannot safely infer anatomy (especially glute
        // max vs. glute med), so a group change requires a fresh pick.
        draft.muscleInvolvementSnapshot = [:]
    }

    private func applyEquipment(_ equipment: Equipment) {
        draft.equipment = equipment
        if equipment == .band {
            draft.loadMode = .nonComparable
            draft.bodyweightFraction = 0
        }
    }

    private func applyModality(_ modality: ExerciseModality) {
        draft.modality = modality
        draft.trackingMode = modality.requiredTrackingMode
    }

    private func applyPattern(_ pattern: MovementPattern) {
        draft.pattern = pattern
        if pattern == .push || pattern == .pull {
            if draft.direction == nil {
                draft.direction = .horizontal
            }
        } else {
            draft.direction = nil
        }
    }

    private func applyLoadMode(_ mode: ExerciseLoadMode) {
        draft.loadMode = mode
        switch mode {
        case .external, .nonComparable:
            draft.bodyweightFraction = 0
        case .bodyweightAdded, .assistanceSubtracted:
            if draft.bodyweightFraction == 0 {
                draft.bodyweightFraction = 1
            }
        }
    }

    // MARK: - Aliases

    private var aliasesField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Aliases")
                    .sectionLabelStyle(Opacity.medium)
                Spacer()
                Text("comma-separated")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }

            TextField("", text: $draft.aliasesInput, prompt: Text("e.g. BP, Flat Bench")
                .foregroundStyle(Ink.quaternary))
                .font(Typography.body)
                .foregroundStyle(Ink.primary)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.words)
                .padding(.vertical, Space.sm)
                .accessibilityLabel("Aliases")

            Rectangle()
                .fill(Surface.edge)
                .frame(height: 1)
                .accessibilityHidden(true)

            if showsValidationErrors,
               !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !hasUniqueSearchTerms
            {
                validationMessage("Name and aliases must be unique across the exercise catalog.")
            }
        }
    }

    private var loadModeField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            pickerRow(
                title: "Load interpretation",
                value: draft.loadMode.customExerciseChoiceName
            ) {
                presentPicker(.loadMode)
            }

            if showsValidationErrors, !hasValidLoadProfile {
                validationMessage("Choose a load interpretation that matches this equipment.")
            }
        }
    }

    private var bodyweightFractionField: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            valueColumn(label: "Bodyweight carried") {
                BareScrubber(
                    value: $draft.bodyweightFraction,
                    range: 0 ... 1,
                    step: 0.05,
                    pointsPerStep: 14,
                    fontSize: 40,
                    numberColor: Ink.primary,
                    formatter: { value in
                        "\(Int((value * 100).rounded()))%"
                    },
                    accessibilityLabel: "Bodyweight carried"
                )
            }
            if showsValidationErrors, draft.bodyweightFraction == 0 {
                validationMessage("Bodyweight load modes require a carried fraction above zero.")
            }
        }
    }

    private var defaultsRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Defaults")
                .sectionLabelStyle(Opacity.medium)

            HStack(alignment: .top, spacing: Space.xxl) {
                switch draft.trackingMode {
                case .reps:
                    valueColumn(label: draft.loadMode.inputLabel) {
                        BareScrubber(
                            value: defaultWeightBinding,
                            range: unit.strengthRange,
                            step: unit.strengthStep,
                            pointsPerStep: 8,
                            fontSize: 40,
                            unit: unit.symbol,
                            unitFontSize: 13,
                            numberColor: Ink.primary,
                            unitColor: Ink.tertiary,
                            accessibilityLabel: draft.loadMode.inputLabel,
                            tickTone: .deep
                        )
                    }
                case .duration:
                    valueColumn(label: draft.modality.durationLabel) {
                        BareScrubber(
                            value: defaultDurationBinding,
                            range: DurationFormatter.scrubRange,
                            step: DurationFormatter.scrubStep,
                            pointsPerStep: 10,
                            fontSize: 40,
                            numberColor: Ink.primary,
                            formatter: { DurationFormatter.string($0) },
                            accessibilityLabel: draft.modality.durationLabel
                        )
                    }
                    valueColumn(label: draft.loadMode.inputLabel) {
                        BareScrubber(
                            value: defaultWeightBinding,
                            range: unit.strengthRange,
                            step: unit.strengthStep,
                            pointsPerStep: 8,
                            fontSize: 40,
                            unit: unit.symbol,
                            unitFontSize: 13,
                            numberColor: Ink.primary,
                            unitColor: Ink.tertiary,
                            accessibilityLabel: draft.loadMode.inputLabel,
                            tickTone: .deep
                        )
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// A small sentence-case label above a bare scrubbing numeral —
    /// the same composition the template editor uses, so the two
    /// editors read identically.
    private func valueColumn(
        label: String,
        @ViewBuilder scrubber: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label)
                .sectionLabelStyle(Opacity.soft)
            scrubber()
        }
    }

    // MARK: - Default bindings

    /// Scrubbed in display units; stored canonical (lb) on the draft.
    private var defaultWeightBinding: Binding<Double> {
        Binding(
            get: { WeightFormatter.toDisplay(draft.defaultWeight, unit: unit) },
            set: { draft.defaultWeight = WeightFormatter.toCanonical($0, unit: unit) }
        )
    }

    private var defaultDurationBinding: Binding<Double> {
        Binding(
            get: { draft.defaultDuration },
            set: { draft.defaultDuration = $0 }
        )
    }

    // MARK: - Save

    private func attemptSave(using scrollProxy: ScrollViewProxy) {
        guard canSave else {
            showsValidationErrors = true
            Haptics.soft()

            guard let anchor = firstValidationAnchor else { return }
            if anchor == .name {
                nameFieldFocused = true
            } else {
                nameFieldFocused = false
            }

            if reduceMotion {
                scrollProxy.scrollTo(anchor, anchor: .center)
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    scrollProxy.scrollTo(anchor, anchor: .center)
                }
            }
            return
        }

        save()
    }

    private func save() {
        guard canSave else { return }
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)

        let parsedAliases = draft.parsedAliases

        var savedItem: ExerciseCatalogItem?

        switch target {
        case .create, .duplicate:
            // A duplicate inherits the source's rep default — the
            // draft has no reps field, so the create flow's 8/12
            // heuristic would otherwise silently reset, say, a 5-rep
            // deadlift default.
            var sourceDefaultReps: Int? = nil
            if case let .duplicate(source) = target {
                sourceDefaultReps = source.defaultReps
            }
            let item = ExerciseCatalogItem(
                name: trimmedName,
                group: draft.group,
                defaultWeight: draft.defaultWeight,
                defaultReps: sourceDefaultReps,
                trackingMode: draft.trackingMode,
                modality: draft.modality,
                loadMode: draft.loadMode,
                bodyweightFraction: draft.bodyweightFraction,
                defaultDuration: draft.defaultDuration,
                equipment: draft.equipment,
                mechanic: draft.mechanic,
                trainingRole: draft.trainingRole,
                pattern: draft.mechanic == .compound ? draft.pattern : nil,
                direction: draft.requiresDirection ? draft.direction : nil,
                planes: draft.planes,
                laterality: draft.laterality,
                aliases: parsedAliases,
                execution: draft.execution,
                muscleInvolvement: draft.muscleInvolvement,
                isUserCreated: true
            )
            modelContext.insert(item)
            savedItem = item

        case let .edit(item):
            if isBundledEdit {
                let weightChanged = draft.defaultWeight != item.defaultWeight
                item.defaultWeight = draft.defaultWeight
                if weightChanged {
                    item.defaultWeightKg = unit == .kg
                        ? WeightFormatter.toDisplay(draft.defaultWeight, unit: .kg)
                        : nil
                }
                item.defaultDuration = draft.defaultDuration
                savedItem = item
                break
            }
            let editedPerformanceSignature = ExercisePerformanceSignature(
                modality: draft.modality,
                trackingMode: draft.trackingMode,
                loadMode: draft.loadMode,
                bodyweightFraction: draft.bodyweightFraction
            )
            let performanceSemanticsChanged =
                item.performanceSignature != editedPerformanceSignature
            item.name = trimmedName
            item.group = draft.group
            let weightChanged = draft.defaultWeight != item.defaultWeight
            item.defaultWeight = draft.defaultWeight
            if weightChanged {
                item.defaultWeightKg = unit == .kg
                    ? WeightFormatter.toDisplay(draft.defaultWeight, unit: .kg)
                    : nil
            }
            item.trackingMode = draft.trackingMode
            item.modality = draft.modality
            item.loadMode = draft.loadMode
            item.bodyweightFraction = draft.bodyweightFraction
            item.defaultDuration = draft.defaultDuration
            item.equipment = draft.equipment
            // Setting mechanic to isolation auto-clears pattern via
            // the model's didSet hook, so we don't need to clear it
            // here explicitly. Order matters: mechanic first.
            item.mechanic = draft.mechanic
            item.trainingRole = draft.trainingRole
            item.pattern = draft.mechanic == .compound ? draft.pattern : nil
            item.direction = draft.requiresDirection ? draft.direction : nil
            item.planes = draft.planes
            item.laterality = draft.laterality
            item.aliases = parsedAliases
            item.execution = draft.execution
            item.muscleInvolvementSnapshot = draft.muscleInvolvementSnapshot
            if performanceSemanticsChanged {
                // A measured max belongs to the old load equation. Do
                // not silently reinterpret it after a custom exercise
                // changes tracking, modality, assistance, or carried
                // bodyweight semantics.
                item.oneRepMax = nil
            }
            savedItem = item
        }

        do {
            try modelContext.saveOrRollback()
            if let item = savedItem {
                SpotlightIndexer.index(item)
            }
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.thunk()
        dismiss()
    }
}

// MARK: - Segmented field

/// Form-specific segmented control. The neutral track reads as one
/// control while the selected option owns the app's orange accent;
/// resting options stay grayscale so the selection is unmistakable.
private struct CatalogSegmentedField<Option: Hashable>: View {
    let title: String
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    @Namespace private var selectionThumb

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title)
                .sectionLabelStyle(Opacity.medium)

            HStack(spacing: 2) {
                ForEach(options, id: \.self) { option in
                    optionButton(option)
                }
            }
            .padding(2)
            .background {
                Capsule()
                    .fill(Surface.cardTintBright)
            }
            .overlay {
                Capsule()
                    .stroke(Surface.edge, lineWidth: 1)
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85),
            value: selection
        )
    }

    private func optionButton(_ option: Option) -> some View {
        let selected = option == selection
        return Button {
            guard !selected else { return }
            selection = option
        } label: {
            HStack(spacing: Space.xs) {
                if selected, differentiateWithoutColor {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }

                Text(label(option))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .font(Typography.body)
            .fontWeight(selected ? .semibold : .regular)
            .foregroundStyle(selected ? Tint.onAccent : Ink.primary)
            .padding(.horizontal, Space.sm)
            .frame(maxWidth: .infinity, minHeight: Space.tapMin)
            .background {
                if selected {
                    Capsule()
                        .fill(Tint.inProgress)
                        .matchedGeometryEffect(id: "selection", in: selectionThumb)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(option))
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Three independent cardinal-plane toggles. At least one remains
/// selected, while reviewed/custom multi-plane movements can retain
/// every component instead of being flattened to a dominant plane.
private struct CatalogPlaneField: View {
    let title: String
    @Binding var selection: [MovementPlane]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title)
                .sectionLabelStyle(Opacity.medium)

            HStack(spacing: Space.sm) {
                ForEach(MovementPlane.allCases, id: \.self) { plane in
                    let selected = selection.contains(plane)
                    Button {
                        var updated = Set(selection)
                        if selected {
                            guard updated.count > 1 else {
                                Haptics.rigid()
                                return
                            }
                            updated.remove(plane)
                        } else {
                            updated.insert(plane)
                        }
                        Haptics.selection()
                        selection = MovementPlane.allCases.filter(updated.contains)
                    } label: {
                        Text(plane.displayName)
                            .font(Typography.body)
                            .fontWeight(selected ? .semibold : .regular)
                            .foregroundStyle(selected ? Tint.onAccent : Ink.primary)
                            .frame(maxWidth: .infinity, minHeight: Space.tapMin)
                            .background(
                                Capsule().fill(selected ? Tint.inProgress : Surface.cardTintBright)
                            )
                            .overlay(Capsule().stroke(Surface.edge, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(plane.displayName)
                    .accessibilityValue(selected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Choice sheet

/// Focused single-choice list for the editor's longer taxonomies.
/// Selection applies immediately and dismisses, while the checkmark
/// keeps the current value legible before the user commits the draft.
private struct CatalogChoiceSheet<Option: Hashable>: View {
    let title: String
    let options: [Option]
    let label: (Option) -> String
    let isSelected: (Option) -> Bool
    let onSelect: (Option) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        choiceRow(option)

                        if option != options.last {
                            SectionDivider()
                                .padding(.horizontal, Space.lg)
                        }
                    }
                }
                .contentCard()
                .padding(.vertical, Space.md)
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .screenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func choiceRow(_ option: Option) -> some View {
        let selected = isSelected(option)
        return Button {
            Haptics.selection()
            onSelect(option)
            dismiss()
        } label: {
            HStack(spacing: Space.md) {
                Text(label(option))
                    .font(Typography.body)
                    .foregroundStyle(Ink.primary)

                Spacer(minLength: Space.sm)

                if selected {
                    Image(systemName: "checkmark")
                        .font(Typography.headline)
                        .foregroundStyle(Tint.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Space.lg)
            .frame(minHeight: Space.rowMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(option))
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
