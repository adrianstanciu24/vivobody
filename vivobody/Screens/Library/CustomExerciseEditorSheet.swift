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
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        nameField
                        muscleGroupField
                        equipmentField
                        mechanicField
                        if draft.mechanic == .compound {
                            patternField
                        }
                        aliasesField
                        defaultsRow
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .sectionLabelStyle(0.60)

            TextField("", text: $draft.name, prompt: Text("e.g. Bulgarian Split Squat")
                .foregroundStyle(.white.opacity(0.35)))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .glassChip(cornerRadius: 14)
        }
    }

    private var muscleGroupField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Muscle group")
                .sectionLabelStyle(0.60)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MuscleGroup.allCases, id: \.self) { g in
                        muscleChip(g)
                    }
                }
            }
        }
    }

    private func muscleChip(_ g: MuscleGroup) -> some View {
        let isSelected = draft.group == g
        return Button {
            Haptics.selection()
            draft.group = g
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(g.accent)
                    .frame(width: 7, height: 7)
                Text(g.displayName)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(
                Capsule().fill(isSelected ? Tint.primary : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.10),
                    lineWidth: 0.5
                )
            )
            .shadow(color: isSelected ? Tint.primary.opacity(0.35) : .clear, radius: 10, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Equipment

    private var equipmentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Equipment")
                .sectionLabelStyle(0.60)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Equipment.allCases, id: \.self) { e in
                        equipmentChip(e)
                    }
                }
            }
        }
    }

    private func equipmentChip(_ e: Equipment) -> some View {
        let isSelected = draft.equipment == e
        return Button {
            Haptics.selection()
            draft.equipment = e
        } label: {
            HStack(spacing: 6) {
                Image(systemName: e.symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(e.displayName)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(
                Capsule().fill(isSelected ? Tint.primary : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.10),
                    lineWidth: 0.5
                )
            )
            .shadow(color: isSelected ? Tint.primary.opacity(0.35) : .clear, radius: 10, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Mechanic

    private var mechanicField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mechanic")
                .sectionLabelStyle(0.60)

            HStack(spacing: 8) {
                ForEach(Mechanic.allCases, id: \.self) { m in
                    mechanicChip(m)
                }
            }
        }
    }

    private func mechanicChip(_ m: Mechanic) -> some View {
        let isSelected = draft.mechanic == m
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                draft.mechanic = m
                if m == .isolation {
                    draft.pattern = nil
                }
            }
        } label: {
            Text(m.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(
                    Capsule().fill(isSelected ? Tint.primary : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.10),
                        lineWidth: 0.5
                    )
                )
                .shadow(color: isSelected ? Tint.primary.opacity(0.35) : .clear, radius: 10, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Pattern (compound only)

    private var patternField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Movement pattern")
                .sectionLabelStyle(0.60)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    patternChip(nil)
                    ForEach(MovementPattern.allCases, id: \.self) { p in
                        patternChip(p)
                    }
                }
            }
        }
    }

    private func patternChip(_ p: MovementPattern?) -> some View {
        let isSelected = draft.pattern == p
        let label = p?.displayName ?? "None"
        return Button {
            Haptics.selection()
            draft.pattern = p
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(
                    Capsule().fill(isSelected ? Tint.primary : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.10),
                        lineWidth: 0.5
                    )
                )
                .shadow(color: isSelected ? Tint.primary.opacity(0.35) : .clear, radius: 10, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Aliases

    private var aliasesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Aliases")
                    .sectionLabelStyle(0.60)
                Spacer()
                Text("comma-separated")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.40))
            }

            TextField("", text: $draft.aliasesInput, prompt: Text("e.g. BP, Flat Bench")
                .foregroundStyle(.white.opacity(0.35)))
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .glassChip(cornerRadius: 14)
        }
    }

    private var defaultsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Defaults")
                .sectionLabelStyle(0.60)

            HStack(spacing: 12) {
                WeightScrubber(
                    canonicalWeight: $draft.defaultWeight,
                    purpose: .strength,
                    label: "Weight",
                    valueFontSize: 28,
                    verticalPadding: 12
                )
                NumberScrubber(
                    value: Binding(
                        get: { Double(draft.defaultReps) },
                        set: { draft.defaultReps = max(1, Int($0)) }
                    ),
                    range: 1...100,
                    step: 1,
                    unit: "reps",
                    label: "Reps",
                    valueFontSize: 28,
                    verticalPadding: 12
                )
            }
        }
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
                equipment: draft.equipment,
                mechanic: draft.mechanic,
                pattern: draft.mechanic == .compound ? draft.pattern : nil,
                aliases: parsedAliases,
                isUserCreated: true
            )
            modelContext.insert(item)

        case .edit(let item):
            item.name = trimmedName
            item.group = draft.group
            item.defaultWeight = draft.defaultWeight
            item.defaultReps = draft.defaultReps
            item.equipment = draft.equipment
            // Setting mechanic to isolation auto-clears pattern via
            // the model's didSet hook, so we don't need to clear it
            // here explicitly. Order matters: mechanic first.
            item.mechanic = draft.mechanic
            item.pattern = draft.mechanic == .compound ? draft.pattern : nil
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
    var equipment: Equipment
    var mechanic: Mechanic
    var pattern: MovementPattern?

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
        equipment: .barbell,
        mechanic: .compound,
        pattern: nil,
        aliasesInput: ""
    )

    init(
        name: String,
        group: MuscleGroup,
        defaultWeight: Double,
        defaultReps: Int,
        equipment: Equipment,
        mechanic: Mechanic,
        pattern: MovementPattern?,
        aliasesInput: String
    ) {
        self.name = name
        self.group = group
        self.defaultWeight = defaultWeight
        self.defaultReps = defaultReps
        self.equipment = equipment
        self.mechanic = mechanic
        self.pattern = pattern
        self.aliasesInput = aliasesInput
    }

    init(from item: ExerciseCatalogItem) {
        self.name = item.name
        self.group = item.group
        self.defaultWeight = item.defaultWeight
        self.defaultReps = item.defaultReps
        self.equipment = item.equipment
        self.mechanic = item.mechanic
        self.pattern = item.pattern
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
