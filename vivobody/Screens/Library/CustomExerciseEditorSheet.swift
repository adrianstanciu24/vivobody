//
//  CustomExerciseEditorSheet.swift
//  vivobody
//
//  Create-or-edit sheet for a catalog entry. Used in both modes:
//    • Create — `target = .create`, builds a new ExerciseCatalogItem
//      and inserts it into the context on Save.
//    • Edit   — `target = .edit(item)`, mutates the existing entry's
//      properties in place.
//
//  Value-type draft buffer (CatalogDraft) — the @Model is only
//  touched on Save, so the editor can be dismissed without polluting
//  the catalog with half-typed entries.
//

import VivoKit
import SwiftUI
import SwiftData

enum CatalogEditorTarget: Identifiable {
    case create
    case edit(ExerciseCatalogItem)

    var id: String {
        switch self {
        case .create:           return "create"
        case .edit(let item):   return "edit-\(item.id)"
        }
    }
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

    @FocusState private var nameFieldFocused: Bool

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    init(target: CatalogEditorTarget) {
        self.target = target
        switch target {
        case .create:
            _draft = State(initialValue: CatalogDraft.empty)
        case .edit(let item):
            _draft = State(initialValue: CatalogDraft(from: item))
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
        guard case .edit(let item) = target else { return false }
        return item.catalogID != nil && !item.isUserCreated
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.movementDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && hasValidMuscleRoles
            && (draft.mechanic != .compound || draft.pattern != nil)
            && (!draft.requiresDirection || draft.direction != nil)
            && hasValidLoadProfile
            && hasUniqueSearchTerms
    }

    private var editedItemID: UUID? {
        guard case .edit(let item) = target else { return nil }
        return item.id
    }

    private var hasValidMuscleRoles: Bool {
        let involvement = draft.muscleInvolvement
        guard !involvement.isEmpty else { return false }
        guard draft.modality.requiresPrimaryMuscle else { return true }
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
        let normalizedOwn = ownTerms.map(Self.normalizedSearchTerm)
        guard normalizedOwn.allSatisfy({ !$0.isEmpty }),
              Set(normalizedOwn).count == normalizedOwn.count else { return false }

        let occupied = Set(catalogItems
            .filter { $0.id != editedItemID }
            .flatMap { [$0.name] + $0.aliases }
            .map(Self.normalizedSearchTerm))
        return occupied.isDisjoint(with: normalizedOwn)
    }

    private static func normalizedSearchTerm(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    if isBundledEdit {
                        bundledIdentitySummary
                        defaultsRow
                    } else {
                        nameField
                        movementDefinitionField
                        muscleGroupField
                        muscleInvolvementField
                        equipmentField
                        modalityField
                        mechanicField
                        if draft.mechanic == .compound {
                            patternField
                            if draft.requiresDirection {
                                directionField
                            }
                        }
                        planeField
                        lateralityField
                        aliasesField
                        trackingModeField
                        loadModeField
                        if draft.loadMode == .bodyweightAdded
                            || draft.loadMode == .assistanceSubtracted {
                            bodyweightFractionField
                        }
                        defaultsRow
                    }
                }
                .padding(.top, Space.md)
                .padding(.bottom, Space.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .screenBackground()
            .navigationTitle(isBundledEdit ? "Exercise Defaults" : (isEditMode ? "Edit Exercise" : "New Exercise"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .bold()
                }
            }
            .onAppear {
                if !isBundledEdit, draft.equipment == .band {
                    draft.loadMode = .nonComparable
                    draft.bodyweightFraction = 0
                }
                if !isEditMode {
                    // Focus the name field for create-mode; the
                    // keyboard slides up immediately so the user can
                    // start typing without an extra tap.
                    nameFieldFocused = true
                }
            }
            .sheet(isPresented: $isMuscleEditorPresented) {
                MuscleInvolvementEditorSheet(
                    initialSnapshot: draft.muscleInvolvementSnapshot,
                    requiresPrimary: draft.modality.requiresPrimaryMuscle
                ) { snapshot in
                    draft.muscleInvolvementSnapshot = snapshot
                }
            }
            .saveErrorAlert($saveError)
        }
    }

    // MARK: - Fields

    private var bundledIdentitySummary: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(draft.name)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
            Text(draft.movementDefinition)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Canonical mechanics, modality, load semantics, and muscle roles are locked so this exercise keeps one stable history identity.")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
        }
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
        }
    }

    private var muscleGroupField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Muscle group")
                .sectionLabelStyle(Opacity.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        ForEach(MuscleGroup.allCases, id: \.self) { g in
                            chip(label: g.displayName, isSelected: draft.group == g) {
                                Haptics.selection()
                                guard draft.group != g else { return }
                                draft.group = g
                                // A browse group cannot safely infer anatomy
                                // (especially glute max vs glute med), so a
                                // group change requires an explicit re-pick.
                                draft.muscleInvolvementSnapshot = [:]
                            }
                        }
                    }
                }
            }
        }
    }

    private var muscleInvolvementField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Muscles worked")
                    .sectionLabelStyle(Opacity.medium)
                Spacer()
                Text("explicit roles")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }

            Button {
                Haptics.selection()
                isMuscleEditorPresented = true
            } label: {
                HStack(spacing: Space.md) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(draft.muscleSummary)
                            .font(Typography.body)
                            .foregroundStyle(Ink.secondary)
                            .multilineTextAlignment(.leading)
                        Text("Set each muscle as Primary, Secondary, Stabilizer, or None")
                            .font(Typography.caption)
                            .foregroundStyle(Ink.quaternary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: Space.sm)

                    Image(systemName: "chevron.right")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(Surface.cardTint)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit muscle involvement")
            .accessibilityValue(draft.muscleSummary)

            if draft.modality.requiresPrimaryMuscle,
               !hasValidMuscleRoles {
                Text("Choose a Primary muscle in the selected muscle group to save.")
                    .font(Typography.caption)
                    .foregroundStyle(Tint.danger)
            }
        }
    }

    private var movementDefinitionField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Movement definition")
                .sectionLabelStyle(Opacity.medium)

            TextField(
                "Describe the setup and joint movement",
                text: $draft.movementDefinition,
                axis: .vertical
            )
            .font(Typography.body)
            .foregroundStyle(Ink.primary)
            .lineLimit(3...6)
            .padding(.vertical, Space.sm)
            .accessibilityLabel("Movement definition")

            Rectangle()
                .fill(Surface.edge)
                .frame(height: 1)
                .accessibilityHidden(true)

            if draft.movementDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Describe the movement precisely enough to distinguish it from similar exercises.")
                    .font(Typography.caption)
                    .foregroundStyle(Tint.danger)
            }
        }
    }

    // MARK: - Equipment

    private var equipmentField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Equipment")
                .sectionLabelStyle(Opacity.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        ForEach(Equipment.allCases, id: \.self) { e in
                            chip(label: e.displayName, isSelected: draft.equipment == e) {
                                Haptics.selection()
                                draft.equipment = e
                                if e == .band {
                                    draft.loadMode = .nonComparable
                                    draft.bodyweightFraction = 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Modality

    private var modalityField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Modality")
                .sectionLabelStyle(Opacity.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        ForEach(ExerciseModality.allCases, id: \.self) { modality in
                            chip(
                                label: modality.displayName,
                                isSelected: draft.modality == modality
                            ) {
                                Haptics.selection()
                                draft.modality = modality
                                if modality == .dynamicStrength || modality == .power {
                                    draft.trackingMode = .reps
                                } else if modality == .isometricStrength {
                                    draft.trackingMode = .duration
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mechanic

    private var mechanicField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Mechanic")
                .sectionLabelStyle(Opacity.medium)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(Mechanic.allCases, id: \.self) { m in
                        chip(label: m.displayName, isSelected: draft.mechanic == m, fullWidth: true) {
                            Haptics.selection()
                            if reduceMotion {
                                draft.mechanic = m
                                if m == .isolation {
                                    draft.pattern = nil
                                    draft.direction = nil
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    draft.mechanic = m
                                    if m == .isolation {
                                        draft.pattern = nil
                                        draft.direction = nil
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pattern (compound only)

    private var patternField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Movement pattern")
                .sectionLabelStyle(Opacity.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        chip(label: "None", isSelected: draft.pattern == nil) {
                            Haptics.selection()
                            draft.pattern = nil
                            draft.direction = nil
                        }
                        ForEach(MovementPattern.allCases, id: \.self) { p in
                            chip(label: p.displayName, isSelected: draft.pattern == p) {
                                Haptics.selection()
                                draft.pattern = p
                                if p != .push && p != .pull {
                                    draft.direction = nil
                                }
                            }
                        }
                    }
                }
            }

            if draft.pattern == nil {
                Text("Choose the compound movement pattern to save.")
                    .font(Typography.caption)
                    .foregroundStyle(Tint.danger)
            }
        }
    }

    // MARK: - Direction (push/pull only)

    private var directionField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Direction")
                .sectionLabelStyle(Opacity.medium)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(PushPullDirection.allCases, id: \.self) { direction in
                        chip(
                            label: direction.displayName,
                            isSelected: draft.direction == direction,
                            fullWidth: true
                        ) {
                            Haptics.selection()
                            draft.direction = direction
                        }
                    }
                }
            }
        }
    }

    // MARK: - Plane (every exercise)

    private var planeField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Plane of movement")
                .sectionLabelStyle(Opacity.medium)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(MovementPlane.allCases, id: \.self) { p in
                        chip(label: p.displayName, isSelected: draft.plane == p, fullWidth: true) {
                            Haptics.selection()
                            draft.plane = p
                        }
                    }
                }
            }
        }
    }

    // MARK: - Laterality (every exercise)

    private var lateralityField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Sides")
                .sectionLabelStyle(Opacity.medium)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(Laterality.allCases, id: \.self) { l in
                        chip(label: l.displayName, isSelected: draft.laterality == l, fullWidth: true) {
                            Haptics.selection()
                            draft.laterality = l
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chip

    /// The one selectable chip used across every field: glass tinted
    /// lime when chosen, neutral translucent glass when not — matching
    /// the picker and catalog equipment strips, which share one
    /// continuous glass region via GlassEffectContainer.
    private func chip(
        label: String,
        isSelected: Bool,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(Typography.sectionLabel)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.horizontal, fullWidth ? Space.md : Space.lg)
                .frame(minHeight: 44)
                .coloredGlassControl(cornerRadius: Radius.pill, fill: isSelected ? Tint.inProgress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
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

            if !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !hasUniqueSearchTerms {
                Text("Name and aliases must be unique across the exercise catalog.")
                    .font(Typography.caption)
                    .foregroundStyle(Tint.danger)
            }
        }
    }

    // MARK: - Measure (reps vs. time)

    /// Chooses how the exercise is logged. Time replaces reps with a
    /// modality-aware duration: Hold for isometric strength, Interval
    /// for conditioning, and Time for other timed work.
    private var trackingModeField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Measure")
                .sectionLabelStyle(Opacity.medium)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(availableTrackingModes, id: \.self) { m in
                        chip(label: m.displayName, isSelected: draft.trackingMode == m, fullWidth: true) {
                            Haptics.selection()
                            if reduceMotion {
                                draft.trackingMode = m
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    draft.trackingMode = m
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var availableTrackingModes: [TrackingMode] {
        switch draft.modality {
        case .dynamicStrength, .power: return [.reps]
        case .isometricStrength: return [.duration]
        case .conditioning, .mobility: return TrackingMode.allCases
        }
    }

    private var loadModeField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Load interpretation")
                .sectionLabelStyle(Opacity.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        ForEach(
                            draft.equipment == .band ? [.nonComparable] : ExerciseLoadMode.allCases,
                            id: \.self
                        ) { mode in
                            chip(label: mode.displayName, isSelected: draft.loadMode == mode) {
                                Haptics.selection()
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
                        }
                    }
                }
            }
        }
    }

    private var bodyweightFractionField: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            valueColumn(label: "Bodyweight carried") {
                BareScrubber(
                    value: $draft.bodyweightFraction,
                    range: 0...1,
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
            if draft.bodyweightFraction == 0 {
                Text("Bodyweight load modes require a carried fraction above zero.")
                    .font(Typography.caption)
                    .foregroundStyle(Tint.danger)
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
    private func valueColumn<S: View>(
        label: String,
        @ViewBuilder scrubber: () -> S
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

    private func save() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let parsedAliases = draft.parsedAliases

        var savedItem: ExerciseCatalogItem?

        switch target {
        case .create:
            let item = ExerciseCatalogItem(
                name: trimmedName,
                group: draft.group,
                defaultWeight: draft.defaultWeight,
                trackingMode: draft.trackingMode,
                modality: draft.modality,
                loadMode: draft.loadMode,
                bodyweightFraction: draft.bodyweightFraction,
                defaultDuration: draft.defaultDuration,
                equipment: draft.equipment,
                mechanic: draft.mechanic,
                pattern: draft.mechanic == .compound ? draft.pattern : nil,
                direction: draft.requiresDirection ? draft.direction : nil,
                plane: draft.plane,
                laterality: draft.laterality,
                aliases: parsedAliases,
                movementDefinition: draft.movementDefinition.trimmingCharacters(in: .whitespacesAndNewlines),
                muscleInvolvement: draft.muscleInvolvement,
                isUserCreated: true
            )
            modelContext.insert(item)
            savedItem = item

        case .edit(let item):
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
            item.pattern = draft.mechanic == .compound ? draft.pattern : nil
            item.direction = draft.requiresDirection ? draft.direction : nil
            item.plane = draft.plane
            item.laterality = draft.laterality
            item.aliases = parsedAliases
            item.movementDefinition = draft.movementDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
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

// MARK: - Draft

/// Value-type buffer for the editor. The @Model isn't bound to the
/// fields directly — the editor mutates the draft, only writing back
/// to the model on Save. This avoids two known SwiftData/TextField
/// edge cases: typing latency and partial commits if the sheet is
/// dismissed before Save.
struct CatalogDraft {
    var name: String
    var movementDefinition: String
    var group: MuscleGroup
    var defaultWeight: Double
    var trackingMode: TrackingMode
    var modality: ExerciseModality
    var loadMode: ExerciseLoadMode
    var bodyweightFraction: Double
    var defaultDuration: TimeInterval
    var equipment: Equipment
    var mechanic: Mechanic
    var pattern: MovementPattern?
    var direction: PushPullDirection?
    var plane: MovementPlane
    var laterality: Laterality
    var muscleInvolvementSnapshot: [String: Double]

    /// Raw editor input for aliases — comma-separated free text.
    /// Parsed into `[String]` on save via `parsedAliases`. Keeping
    /// the raw form here lets the user keep typing without us
    /// reformatting their input mid-stream.
    var aliasesInput: String

    static let empty = CatalogDraft(
        name: "",
        movementDefinition: "",
        group: .chest,
        defaultWeight: 0,
        trackingMode: .reps,
        modality: .dynamicStrength,
        loadMode: .external,
        bodyweightFraction: 0,
        defaultDuration: 45,
        equipment: .barbell,
        mechanic: .compound,
        pattern: nil,
        direction: nil,
        plane: .sagittal,
        laterality: .bilateral,
        muscleInvolvementSnapshot: [:],
        aliasesInput: ""
    )

    init(
        name: String,
        movementDefinition: String,
        group: MuscleGroup,
        defaultWeight: Double,
        trackingMode: TrackingMode,
        modality: ExerciseModality,
        loadMode: ExerciseLoadMode,
        bodyweightFraction: Double,
        defaultDuration: TimeInterval,
        equipment: Equipment,
        mechanic: Mechanic,
        pattern: MovementPattern?,
        direction: PushPullDirection?,
        plane: MovementPlane,
        laterality: Laterality,
        muscleInvolvementSnapshot: [String: Double],
        aliasesInput: String
    ) {
        self.name = name
        self.movementDefinition = movementDefinition
        self.group = group
        self.defaultWeight = defaultWeight
        self.trackingMode = trackingMode
        self.modality = modality
        self.loadMode = loadMode
        self.bodyweightFraction = max(0, min(bodyweightFraction, 1))
        self.defaultDuration = defaultDuration
        self.equipment = equipment
        self.mechanic = mechanic
        self.pattern = pattern
        self.direction = direction
        self.plane = plane
        self.laterality = laterality
        self.muscleInvolvementSnapshot = muscleInvolvementSnapshot
        self.aliasesInput = aliasesInput
    }

    init(from item: ExerciseCatalogItem) {
        self.name = item.name
        self.movementDefinition = item.movementDefinition
        self.group = item.group
        self.defaultWeight = item.defaultWeight
        self.trackingMode = item.trackingMode
        self.modality = item.modality
        self.loadMode = item.loadMode
        self.bodyweightFraction = item.bodyweightFraction
        self.defaultDuration = item.defaultDuration > 0 ? item.defaultDuration : 45
        self.equipment = item.equipment
        self.mechanic = item.mechanic
        self.pattern = item.pattern
        self.direction = item.direction
        self.plane = item.plane
        self.laterality = item.laterality
        self.muscleInvolvementSnapshot = item.muscleInvolvementSnapshot
        // Rebuild the comma-separated string so the editor's text
        // field reflects the stored list. Two-space readability for
        // long lists, but the parser tolerates either.
        self.aliasesInput = item.aliases.joined(separator: ", ")
    }

    var muscleInvolvement: Muscle.Involvement {
        Muscle.Involvement(snapshot: muscleInvolvementSnapshot)
    }

    var requiresDirection: Bool {
        mechanic == .compound && (pattern == .push || pattern == .pull)
    }

    var muscleSummary: String {
        let involvement = muscleInvolvement
        let primary = involvement.primary.map(\.displayName).joined(separator: " · ")
        let supportingCount = involvement.secondary.count + involvement.stabilizers.count
        guard !primary.isEmpty else {
            let visual = (involvement.secondary + involvement.stabilizers)
                .map(\.displayName)
                .joined(separator: " · ")
            return visual.isEmpty ? "No muscles selected" : "\(visual) · Visual roles only"
        }
        guard supportingCount > 0 else { return "\(primary) · Primary" }
        let suffix = supportingCount == 1 ? "1 supporting muscle" : "\(supportingCount) supporting muscles"
        return "\(primary) · \(suffix)"
    }

    /// Split the comma-separated `aliasesInput` into a clean array.
    /// Trims whitespace per item, drops empties + duplicates (case-
    /// insensitive), preserves first-appearance order so the user's
    /// typing order isn't shuffled.
    var parsedAliases: [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for piece in aliasesInput.split(separator: ",") {
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                result.append(trimmed)
            }
        }
        return result
    }
}
