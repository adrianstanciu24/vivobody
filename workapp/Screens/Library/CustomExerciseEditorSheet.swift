//
//  CustomExerciseEditorSheet.swift
//  workapp
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
            Text("NAME")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            TextField("", text: $draft.name, prompt: Text("e.g. Bulgarian Split Squat")
                .foregroundStyle(.white.opacity(0.35)))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        }
    }

    private var muscleGroupField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MUSCLE GROUP")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

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
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(
                Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(isSelected ? 0 : 0.10), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var defaultsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEFAULTS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            HStack(spacing: 12) {
                WeightScrubber(
                    canonicalWeight: $draft.defaultWeight,
                    purpose: .strength,
                    label: "WEIGHT",
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
                    label: "REPS",
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

        switch target {
        case .create:
            let item = ExerciseCatalogItem(
                name: trimmedName,
                group: draft.group,
                defaultWeight: draft.defaultWeight,
                defaultReps: draft.defaultReps,
                isUserCreated: true
            )
            modelContext.insert(item)

        case .edit(let item):
            item.name = trimmedName
            item.group = draft.group
            item.defaultWeight = draft.defaultWeight
            item.defaultReps = draft.defaultReps
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

    static let empty = CatalogDraft(
        name: "",
        group: .chest,
        defaultWeight: 0,
        defaultReps: 8
    )

    init(name: String, group: MuscleGroup, defaultWeight: Double, defaultReps: Int) {
        self.name = name
        self.group = group
        self.defaultWeight = defaultWeight
        self.defaultReps = defaultReps
    }

    init(from item: ExerciseCatalogItem) {
        self.name = item.name
        self.group = item.group
        self.defaultWeight = item.defaultWeight
        self.defaultReps = item.defaultReps
    }
}
