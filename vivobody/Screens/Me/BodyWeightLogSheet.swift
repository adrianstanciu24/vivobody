//
//  BodyWeightLogSheet.swift
//  vivobody
//
//  Quick-log experience for body weight. Two controls:
//    • DatePicker — defaults to "today" for new entries; locked to
//      the entry's own date when editing.
//    • WeightScrubber (.body) — fine-grained step (0.2 lb / 0.1 kg)
//      with a body-weight-appropriate range. Reads the user's unit
//      preference automatically; canonical lb stays at the binding.
//
//  Behavior:
//    • New + date already has an entry → save UPDATES that entry
//      (no duplicates per day in the default flow).
//    • New + date has no entry → save inserts a fresh row.
//    • Editing an existing entry → save mutates the original, unless
//      the new date already has another row; then it merges into that
//      row and deletes the duplicate.
//
//  Sheet is reused from both the Me-tab card (empty state) and the
//  BodyWeightDetail screen.
//

import SwiftUI
import SwiftData

/// What the sheet is being asked to do. The view branches on this
/// to decide whether to seed the scrubber from the previous entry
/// (when creating new) or from the row being edited.
enum BodyWeightLogTarget: Identifiable {
    case create
    case edit(BodyWeightEntry)

    var id: String {
        switch self {
        case .create:        return "create"
        case .edit(let e):   return "edit-\(e.id.uuidString)"
        }
    }
}

struct BodyWeightLogSheet: View {
    let target: BodyWeightLogTarget

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// All known entries — needed so we can detect "today already
    /// has a row" during a `.create` flow and overwrite rather than
    /// insert. The detail screen also consults it for its history.
    @Query(sort: \BodyWeightEntry.date, order: .reverse)
    private var entries: [BodyWeightEntry]

    @State private var date: Date = Date()
    @State private var weight: Double = 180

    /// True while a save is in flight — guards against double-tap
    /// duplicates from impatient fingers. SwiftData inserts are
    /// fast in practice; this is belt-and-suspenders.
    @State private var isSaving: Bool = false

    /// Surfaces a save-failure alert and keeps the sheet open so the
    /// user can retry. saveOrRollback has already reverted the
    /// context, so a same-day overwrite that failed won't leave a
    /// half-mutated row.
    @State private var saveError: SaveErrorBox? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Surface.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xxl) {
                        dateField
                        weightScrubber
                        Spacer(minLength: 12)
                    }
                    .padding(.top, 8)
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            }
            .navigationTitle(isEditing ? "Edit Entry" : "Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear(perform: hydrate)
        .saveErrorAlert($saveError)
    }

    // MARK: - Hydration

    /// Seed the local @State from the editing target. For .create
    /// we lean on the most recent prior entry as a sensible default
    /// (people usually log near their last value); falling back to
    /// 180 lb only when the user has zero history.
    private func hydrate() {
        switch target {
        case .create:
            date = Date()
            if let todayEntry = entries.entry(on: Date()) {
                weight = todayEntry.weight
            } else if let last = entries.latest {
                weight = last.weight
            } else {
                weight = 180
            }
        case .edit(let entry):
            date = entry.date
            weight = entry.weight
        }
    }

    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    // MARK: - Sections

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .sectionLabelStyle(Opacity.medium)

            DatePicker(
                "Date",
                selection: $date,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(Tint.primary)
        }
    }

    private var weightScrubber: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight")
                .sectionLabelStyle(Opacity.medium)

            WeightScrubber(
                canonicalWeight: $weight,
                purpose: .body,
                label: nil,
                valueFontSize: 56,
                verticalPadding: 24
            )
        }
    }

    // MARK: - Save

    private var canSave: Bool {
        !isSaving && weight >= 60
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        Haptics.soft()

        switch target {
        case .create:
            // Same-day overwrite policy: if a row already exists on
            // the picked date, mutate it in place. Keeps the chart
            // honest — one weigh-in per day is the model's intent.
            if let existing = entries.entry(on: date) {
                existing.weight = weight
                existing.date = date
            } else {
                let entry = BodyWeightEntry(date: date, weight: weight)
                context.insert(entry)
            }
        case .edit(let entry):
            if let existing = entries.entry(on: date), existing.id != entry.id {
                existing.weight = weight
                existing.date = date
                context.delete(entry)
            } else {
                entry.weight = weight
                entry.date = date
            }
        }

        do {
            try context.saveOrRollback()
            WidgetSnapshotWriter.writeAll(in: context)
            dismiss()
        } catch {
            saveError = SaveErrorBox(error)
            isSaving = false
        }
    }
}

#Preview("Log") {
    BodyWeightLogSheet(target: .create)
        .modelContainer(for: BodyWeightEntry.self, inMemory: true)
}
