//
//  ExercisePickerSheet.swift
//  workapp
//
//  Modal browser for the exercise catalog. Presented from the
//  TemplateEditorScreen ("Add Exercise") and from the active workout
//  Summary card ("Add Exercise" mid-workout). Returns a single picked
//  item via callback and dismisses; the caller decides what to do
//  with it.
//
//  Catalog is SwiftData-backed (see ExerciseCatalogItem.swift), so
//  users can extend it inline:
//    • Toolbar "+" — create a new custom exercise.
//    • Long-press on any row — context menu with Edit and Delete.
//      Edit opens the same CustomExerciseEditorSheet in edit mode;
//      Delete asks for confirmation, then removes the row.
//
//  Sectioned by muscle group, searchable across the full list.
//

import SwiftUI
import SwiftData

struct ExercisePickerSheet: View {
    let onPick: (ExerciseCatalogItem) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var items: [ExerciseCatalogItem]

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var query: String = ""
    @State private var editorTarget: CatalogEditorTarget?
    @State private var pendingDeleteItem: ExerciseCatalogItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(filteredGroups, id: \.group) { section in
                            groupSection(group: section.group, items: section.items)
                        }
                        if filteredGroups.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorTarget = .create
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create custom exercise")
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .sheet(item: $editorTarget) { target in
                CustomExerciseEditorSheet(target: target)
            }
            .alert(
                "Delete \"\(pendingDeleteItem?.name ?? "exercise")\"?",
                isPresented: Binding(
                    get: { pendingDeleteItem != nil },
                    set: { if !$0 { pendingDeleteItem = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let item = pendingDeleteItem {
                        delete(item)
                    }
                    pendingDeleteItem = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteItem = nil
                }
            } message: {
                Text("This removes the exercise from the picker. Templates and history that already reference it stay intact.")
            }
        }
    }

    // MARK: - Filtering / grouping

    private var filteredGroups: [(group: MuscleGroup, items: [ExerciseCatalogItem])] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        let scope: [ExerciseCatalogItem]
        if trimmed.isEmpty {
            scope = items
        } else {
            scope = items.filter { $0.name.lowercased().contains(trimmed) }
        }
        return scope.groupedByMuscle
    }

    // MARK: - Sections / rows

    private func groupSection(group: MuscleGroup, items: [ExerciseCatalogItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(group.accent).frame(width: 7, height: 7)
                Text(group.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
            }
            VStack(spacing: 6) {
                ForEach(items) { item in
                    pickerRow(item)
                }
            }
        }
    }

    private func pickerRow(_ item: ExerciseCatalogItem) -> some View {
        Button {
            onPick(item)
            Haptics.soft()
            dismiss()
        } label: {
            HStack {
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(WeightFormatter.string(item.defaultWeight, unit: unit)) · \(item.defaultReps) reps")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editorTarget = .edit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                pendingDeleteItem = item
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.30))
            Text(emptyStateMessage)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
            Button {
                editorTarget = .create
            } label: {
                Label("Create custom exercise", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(
                        Capsule().fill(Color.white.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyStateMessage: String {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return "Your catalog is empty.\nTap below to add an exercise."
        }
        return "No exercises match \"\(trimmed)\"."
    }

    // MARK: - Mutations

    private func delete(_ item: ExerciseCatalogItem) {
        modelContext.delete(item)
        try? modelContext.save()
        Haptics.soft()
    }
}
