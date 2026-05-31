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

    @State private var draft: CatalogDraft

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

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    nameField
                    muscleGroupField
                    equipmentField
                    mechanicField
                    if draft.mechanic == .compound {
                        patternField
                    }
                    planeField
                    lateralityField
                    aliasesField
                    trackingModeField
                    defaultsRow
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.md)
                .padding(.bottom, Space.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .screenBackground()
            .navigationTitle(isEditMode ? "Edit Exercise" : "New Exercise")
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
                if !isEditMode {
                    // Focus the name field for create-mode; the
                    // keyboard slides up immediately so the user can
                    // start typing without an extra tap.
                    nameFieldFocused = true
                }
            }
        }
    }

    // MARK: - Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Name")
                .sectionLabelStyle(0.55)

            TextField("", text: $draft.name, prompt: Text("e.g. Bulgarian Split Squat")
                .foregroundStyle(Ink.quaternary))
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .padding(.vertical, Space.sm)

            Rectangle()
                .fill(Surface.edge)
                .frame(height: 1)
        }
    }

    private var muscleGroupField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Muscle group")
                .sectionLabelStyle(0.55)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    ForEach(MuscleGroup.allCases, id: \.self) { g in
                        chip(label: g.displayName, isSelected: draft.group == g) {
                            Haptics.selection()
                            draft.group = g
                        }
                    }
                }
            }
        }
    }

    // MARK: - Equipment

    private var equipmentField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Equipment")
                .sectionLabelStyle(0.55)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    ForEach(Equipment.allCases, id: \.self) { e in
                        chip(label: e.displayName, symbol: e.symbol, isSelected: draft.equipment == e) {
                            Haptics.selection()
                            draft.equipment = e
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
                .sectionLabelStyle(0.55)

            HStack(spacing: Space.sm) {
                ForEach(Mechanic.allCases, id: \.self) { m in
                    chip(label: m.displayName, isSelected: draft.mechanic == m, fullWidth: true) {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            draft.mechanic = m
                            if m == .isolation {
                                draft.pattern = nil
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
                .sectionLabelStyle(0.55)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    chip(label: "None", isSelected: draft.pattern == nil) {
                        Haptics.selection()
                        draft.pattern = nil
                    }
                    ForEach(MovementPattern.allCases, id: \.self) { p in
                        chip(label: p.displayName, isSelected: draft.pattern == p) {
                            Haptics.selection()
                            draft.pattern = p
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
                .sectionLabelStyle(0.55)

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

    // MARK: - Laterality (every exercise)

    private var lateralityField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Sides")
                .sectionLabelStyle(0.55)

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

    // MARK: - Chip

    /// The one selectable chip used across every field: lime fill +
    /// black text when chosen, a hairline outline when not — the
    /// exact pair used by the picker and catalog equipment strips.
    /// No muscle-color dots, no glass: one accent, one hairline.
    private func chip(
        label: String,
        symbol: String? = nil,
        isSelected: Bool,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? Space.md : Space.lg)
            .frame(minHeight: 44)
            .background {
                if isSelected { Capsule().fill(Tint.inProgress) }
            }
            .overlay {
                if !isSelected { Capsule().stroke(Surface.edge, lineWidth: 1) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Aliases

    private var aliasesField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Aliases")
                    .sectionLabelStyle(0.55)
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

            Rectangle()
                .fill(Surface.edge)
                .frame(height: 1)
        }
    }

    // MARK: - Measure (reps vs. time)

    /// Chooses how the exercise is logged. Time turns the defaults
    /// row into a Hold + Load pair (vs. Weight + Reps), and is what
    /// makes a plank / dead hang / loaded carry track as a held
    /// interval instead of a rep count.
    private var trackingModeField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Measure")
                .sectionLabelStyle(0.55)

            HStack(spacing: Space.sm) {
                ForEach(TrackingMode.allCases, id: \.self) { m in
                    chip(label: m.displayName, isSelected: draft.trackingMode == m, fullWidth: true) {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            draft.trackingMode = m
                        }
                    }
                }
            }
        }
    }

    private var defaultsRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Defaults")
                .sectionLabelStyle(0.55)

            HStack(alignment: .top, spacing: Space.xxl) {
                switch draft.trackingMode {
                case .reps:
                    valueColumn(label: "Weight") {
                        BareScrubber(
                            value: defaultWeightBinding,
                            range: unit.strengthRange,
                            step: unit.strengthStep,
                            pointsPerStep: 8,
                            fontSize: 40,
                            unit: unit.symbol,
                            unitFontSize: 13,
                            numberColor: Ink.primary,
                            unitColor: Ink.tertiary
                        )
                    }
                    valueColumn(label: "Reps") {
                        BareScrubber(
                            value: defaultRepsBinding,
                            range: 1...100,
                            step: 1,
                            pointsPerStep: 16,
                            fontSize: 40,
                            numberColor: Ink.primary
                        )
                    }
                case .duration:
                    valueColumn(label: "Hold") {
                        BareScrubber(
                            value: defaultDurationBinding,
                            range: DurationFormatter.scrubRange,
                            step: DurationFormatter.scrubStep,
                            pointsPerStep: 10,
                            fontSize: 40,
                            numberColor: Ink.primary,
                            formatter: { DurationFormatter.string($0) }
                        )
                    }
                    valueColumn(label: "Load") {
                        BareScrubber(
                            value: defaultWeightBinding,
                            range: unit.strengthRange,
                            step: unit.strengthStep,
                            pointsPerStep: 8,
                            fontSize: 40,
                            unit: unit.symbol,
                            unitFontSize: 13,
                            numberColor: Ink.primary,
                            unitColor: Ink.tertiary
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
                .sectionLabelStyle(0.45)
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

    private var defaultRepsBinding: Binding<Double> {
        Binding(
            get: { Double(draft.defaultReps) },
            set: { draft.defaultReps = max(1, Int($0)) }
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

        switch target {
        case .create:
            let item = ExerciseCatalogItem(
                name: trimmedName,
                group: draft.group,
                defaultWeight: draft.defaultWeight,
                defaultReps: draft.defaultReps,
                trackingMode: draft.trackingMode,
                defaultDuration: draft.defaultDuration,
                equipment: draft.equipment,
                mechanic: draft.mechanic,
                pattern: draft.mechanic == .compound ? draft.pattern : nil,
                plane: draft.plane,
                laterality: draft.laterality,
                aliases: parsedAliases,
                isUserCreated: true
            )
            modelContext.insert(item)

        case .edit(let item):
            item.name = trimmedName
            item.group = draft.group
            item.defaultWeight = draft.defaultWeight
            item.defaultReps = draft.defaultReps
            item.trackingMode = draft.trackingMode
            item.defaultDuration = draft.defaultDuration
            item.equipment = draft.equipment
            // Setting mechanic to isolation auto-clears pattern via
            // the model's didSet hook, so we don't need to clear it
            // here explicitly. Order matters: mechanic first.
            item.mechanic = draft.mechanic
            item.pattern = draft.mechanic == .compound ? draft.pattern : nil
            item.plane = draft.plane
            item.laterality = draft.laterality
            item.aliases = parsedAliases
        }

        try? modelContext.save()
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
    var group: MuscleGroup
    var defaultWeight: Double
    var defaultReps: Int
    var trackingMode: TrackingMode
    var defaultDuration: TimeInterval
    var equipment: Equipment
    var mechanic: Mechanic
    var pattern: MovementPattern?
    var plane: MovementPlane
    var laterality: Laterality

    /// Raw editor input for aliases — comma-separated free text.
    /// Parsed into `[String]` on save via `parsedAliases`. Keeping
    /// the raw form here lets the user keep typing without us
    /// reformatting their input mid-stream.
    var aliasesInput: String

    static let empty = CatalogDraft(
        name: "",
        group: .chest,
        defaultWeight: 0,
        defaultReps: 8,
        trackingMode: .reps,
        defaultDuration: 45,
        equipment: .barbell,
        mechanic: .compound,
        pattern: nil,
        plane: .sagittal,
        laterality: .bilateral,
        aliasesInput: ""
    )

    init(
        name: String,
        group: MuscleGroup,
        defaultWeight: Double,
        defaultReps: Int,
        trackingMode: TrackingMode,
        defaultDuration: TimeInterval,
        equipment: Equipment,
        mechanic: Mechanic,
        pattern: MovementPattern?,
        plane: MovementPlane,
        laterality: Laterality,
        aliasesInput: String
    ) {
        self.name = name
        self.group = group
        self.defaultWeight = defaultWeight
        self.defaultReps = defaultReps
        self.trackingMode = trackingMode
        self.defaultDuration = defaultDuration
        self.equipment = equipment
        self.mechanic = mechanic
        self.pattern = pattern
        self.plane = plane
        self.laterality = laterality
        self.aliasesInput = aliasesInput
    }

    init(from item: ExerciseCatalogItem) {
        self.name = item.name
        self.group = item.group
        self.defaultWeight = item.defaultWeight
        self.defaultReps = item.defaultReps
        self.trackingMode = item.trackingMode
        self.defaultDuration = item.defaultDuration > 0 ? item.defaultDuration : 45
        self.equipment = item.equipment
        self.mechanic = item.mechanic
        self.pattern = item.pattern
        self.plane = item.plane
        self.laterality = item.laterality
        // Rebuild the comma-separated string so the editor's text
        // field reflects the stored list. Two-space readability for
        // long lists, but the parser tolerates either.
        self.aliasesInput = item.aliases.joined(separator: ", ")
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
