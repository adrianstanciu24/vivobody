//
//  BodyWeightLogSheet.swift
//  vivobody
//
//  Quick-log experience for body weight. Two controls:
//    • DatePicker — defaults to "today" for new entries; locked to
//      the entry's own date when editing.
//    • Bare WeightScrubber (.body) — the same number-first control as
//      Active Workout, with a fine-grained step (0.2 lb / 0.1 kg) and
//      a body-weight-appropriate range. Reads the user's unit
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

import VivoKit
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

    /// When non-nil, a confirmation alert is showing because the user
    /// is editing an entry to a date that already has another entry.
    /// Holds the existing entry that would be overwritten.
    @State private var pendingMergeTarget: BodyWeightEntry? = nil

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
        .alert(
            "Overwrite existing entry?",
            isPresented: Binding(
                get: { pendingMergeTarget != nil },
                set: { if !$0 { pendingMergeTarget = nil } }
            ),
            presenting: pendingMergeTarget
        ) { _ in
            Button("Overwrite", role: .destructive) {
                performMergeAndSave()
            }
            Button("Cancel", role: .cancel) {
                pendingMergeTarget = nil
            }
        } message: { _ in
            Text("An entry already exists on \(date.formatted(date: .abbreviated, time: .omitted)). Overwriting will replace its weight with the new value.")
        }
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
                .panelLegend()

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
                .panelLegend()

            WeightScrubber(
                canonicalWeight: $weight,
                purpose: .body,
                label: nil,
                valueFontSize: 72,
                presentation: .bare
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
            performSave()

        case .edit(let entry):
            if let existing = entries.entry(on: date), existing.id != entry.id {
                // Date collision with another entry — confirm before
                // overwriting it and deleting the one being edited.
                isSaving = false
                pendingMergeTarget = existing
            } else {
                entry.weight = weight
                entry.date = date
                performSave()
            }
        }
    }

    /// Complete the merge after the user confirms the collision alert:
    /// overwrite the target entry's weight and delete the one being
    /// edited.
    private func performMergeAndSave() {
        guard let existing = pendingMergeTarget,
              case .edit(let entry) = target
        else { return }
        existing.weight = weight
        existing.date = date
        context.delete(entry)
        pendingMergeTarget = nil
        isSaving = true
        performSave()
    }

    private func performSave() {
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
