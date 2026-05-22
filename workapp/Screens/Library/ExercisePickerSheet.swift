//
//  ExercisePickerSheet.swift
//  workapp
//
//  Modal browser for the static exercise catalog. Presented from
//  inside the TemplateEditorScreen when the user taps "Add
//  Exercise". Returns a single picked item via callback and
//  dismisses; the caller decides what to do with it (build an
//  ExerciseDraft, append to the template, etc).
//
//  Sectioned by muscle group, .searchable across the entire
//  catalog. No selection state held here — single-tap pick.
//

import SwiftUI

struct ExercisePickerSheet: View {
    let onPick: (ExerciseCatalogItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

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
                            Text("No exercises match \"\(query)\"")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.40))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
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
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        }
    }

    private var filteredGroups: [(group: MuscleGroup, items: [ExerciseCatalogItem])] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return ExerciseCatalogItem.grouped }
        return ExerciseCatalogItem.grouped.compactMap { section in
            let matches = section.items.filter { $0.name.lowercased().contains(trimmed) }
            return matches.isEmpty ? nil : (group: section.group, items: matches)
        }
    }

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
                Text("\(Int(item.defaultWeight)) lb · \(item.defaultReps) reps")
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
    }
}
