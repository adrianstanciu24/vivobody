//
//  LibraryScreen.swift
//  vivobody
//
//  Two-segment browser for everything reusable in the app:
//    • Templates — the user's saved workout plans
//    • Exercises — the full exercise catalog (90 stock + customs)
//
//  Why a segmented control instead of a tab: both surfaces serve
//  the same mental model ("reusable workout content") and live at
//  the same level of importance. Tab-count stays at four (Today /
//  History / Library / Me). Matches Notes / Reminders / Music
//  patterns where collections + items share one tab.
//
//  Toolbar "+" is contextual:
//    • Templates segment → opens a name-prompt alert → creates a
//      blank template; user enters its detail to add exercises.
//    • Exercises segment → opens CustomExerciseEditorSheet in
//      .create mode → adds a new entry to the catalog.
//
//  Search bar (always visible, nav-bar drawer) filters whichever
//  segment is active: templates match by name; exercises match by
//  name or alias.
//

import SwiftUI
import SwiftData

struct LibraryScreen: View {
    @Bindable var appState: AppState

    @Environment(\.modelContext) private var modelContext

    @State private var segment: LibrarySegment = .templates
    @State private var searchText: String = ""

    /// New-template name-prompt alert state.
    @State private var isCreatingTemplate: Bool = false
    @State private var newTemplateName: String = ""

    /// Custom-exercise editor sheet target. `.create` for the "+"
    /// toolbar on the Exercises segment; `.edit(item)` for context
    /// menu Edit on a row.
    @State private var customExerciseTarget: CatalogEditorTarget? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                segmentPicker

                // Two distinct content views — each owns its own
                // SwiftData query + filter state so neither one
                // does extra work when the other segment is active.
                switch segment {
                case .templates:
                    LibraryTemplatesContent(
                        appState: appState,
                        searchText: searchText,
                        onRequestNew: presentNewTemplateAlert
                    )
                case .exercises:
                    LibraryExercisesContent(
                        searchText: searchText,
                        customExerciseTarget: $customExerciseTarget
                    )
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: searchPrompt
        )
        .toolbar { toolbar }
        .alert("New Template", isPresented: $isCreatingTemplate) {
            TextField("Name", text: $newTemplateName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {
                newTemplateName = ""
            }
            Button("Create") {
                createTemplate(named: newTemplateName)
                newTemplateName = ""
            }
        } message: {
            Text("Pick a name. You can rename it later by tapping the title on its detail screen.")
        }
        .sheet(item: $customExerciseTarget) { target in
            CustomExerciseEditorSheet(target: target)
        }
    }

    // MARK: - Segment picker

    private var segmentPicker: some View {
        Picker("Library segment", selection: $segment) {
            ForEach(LibrarySegment.allCases) { s in
                Text(s.label).tag(s)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: handlePlus) {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
            }
            .accessibilityLabel(plusAccessibilityLabel)
        }
    }

    private func handlePlus() {
        switch segment {
        case .templates:
            presentNewTemplateAlert()
        case .exercises:
            customExerciseTarget = .create
        }
    }

    private var plusAccessibilityLabel: String {
        switch segment {
        case .templates: return "New template"
        case .exercises: return "Create custom exercise"
        }
    }

    // MARK: - Search prompt

    /// Search field placeholder switches per segment so the user
    /// knows what's being searched. Subtle but reduces "what does
    /// this search?" friction.
    private var searchPrompt: String {
        switch segment {
        case .templates: return "Search templates"
        case .exercises: return "Search exercises"
        }
    }

    // MARK: - Mutations

    private func presentNewTemplateAlert() {
        newTemplateName = ""
        isCreatingTemplate = true
    }

    private func createTemplate(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let descriptor = FetchDescriptor<WorkoutTemplate>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0

        let template = WorkoutTemplate(name: trimmed, sortOrder: count)
        modelContext.insert(template)
        try? modelContext.save()
        Haptics.soft()
    }
}

// MARK: - Segment enum

enum LibrarySegment: String, CaseIterable, Identifiable {
    case templates
    case exercises
    var id: String { rawValue }
    var label: String {
        switch self {
        case .templates: return "Templates"
        case .exercises: return "Exercises"
        }
    }
}

// MARK: - Templates content

/// Templates segment — list of saved workout plans. Swipe-left to
/// delete, tap to enter detail. Empty state offers an inline create
/// button. Inherits search text from the parent and filters by name.
private struct LibraryTemplatesContent: View {
    @Bindable var appState: AppState
    let searchText: String
    let onRequestNew: () -> Void

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutTemplate.sortOrder)])
    private var templates: [WorkoutTemplate]

    @State private var deletingTemplate: WorkoutTemplate? = nil

    private var filtered: [WorkoutTemplate] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty { return templates }
        return templates.filter { $0.name.lowercased().contains(trimmed) }
    }

    var body: some View {
        Group {
            if templates.isEmpty {
                emptyState
            } else if filtered.isEmpty {
                noMatchesState
            } else {
                list
            }
        }
        .alert(
            "Delete this template?",
            isPresented: deleteAlertBinding,
            presenting: deletingTemplate
        ) { template in
            Button("Delete", role: .destructive) {
                deleteTemplate(template)
            }
            Button("Cancel", role: .cancel) { }
        } message: { template in
            Text("\(template.name) · \(template.orderedExercises.count) exercises. This can't be undone.")
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(filtered) { template in
                NavigationLink {
                    TemplateDetailScreen(
                        template: template,
                        appState: appState
                    )
                } label: {
                    TemplateCard(template: template)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 22, bottom: 8, trailing: 22))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deletingTemplate = template
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        deletingTemplate = template
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.30))

            Text("NO TEMPLATES YET")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))

            Text("Build a reusable workout — pick exercises, set target reps and weight. Start any time from here.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button(action: onRequestNew) {
                Text("Create Template")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: 220)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
    }

    private var noMatchesState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.30))
            Text("No templates match \"\(searchText)\".")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.50))
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
    }

    // MARK: - Plumbing

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingTemplate != nil },
            set: { if !$0 { deletingTemplate = nil } }
        )
    }

    private func deleteTemplate(_ template: WorkoutTemplate) {
        modelContext.delete(template)
        try? modelContext.save()
        for (i, t) in templates.enumerated() {
            t.sortOrder = i
        }
        try? modelContext.save()
        Haptics.soft()
        deletingTemplate = nil
    }
}

// MARK: - Exercises content

/// Exercises segment — browsable catalog. Tap an exercise row to
/// push its detail screen (no commit CTA in this context). Long-
/// press for Edit / Delete via context menu. Equipment filter strip
/// at the top mirrors the picker's chips so the two surfaces feel
/// continuous.
private struct LibraryExercisesContent: View {
    let searchText: String
    @Binding var customExerciseTarget: CatalogEditorTarget?

    @Environment(\.modelContext) private var modelContext

    @Query private var items: [ExerciseCatalogItem]

    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: \WorkoutSession.completedAt,
        order: .reverse
    )
    private var completedSessions: [WorkoutSession]

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var equipmentFilter: Equipment? = nil
    @State private var pendingDeleteItem: ExerciseCatalogItem? = nil

    private var lastInstanceLookup: [String: LastExerciseInstance] {
        completedSessions.lastInstanceByExercise()
    }

    var body: some View {
        VStack(spacing: 0) {
            equipmentFilterStrip

            if filteredGroups.isEmpty {
                emptyState
            } else {
                exerciseList
            }
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
            Text("This removes the exercise from the catalog. Templates and history that already reference it stay intact.")
        }
    }

    // MARK: - Filter / group

    private var filteredGroups: [(group: MuscleGroup, items: [ExerciseCatalogItem])] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        var scope = items
        if let filter = equipmentFilter {
            scope = scope.filter { $0.equipment == filter }
        }
        if !trimmed.isEmpty {
            scope = scope.filter { item in
                if item.name.lowercased().contains(trimmed) { return true }
                return item.aliases.contains { $0.lowercased().contains(trimmed) }
            }
        }
        return scope.groupedByMuscle
    }

    private var availableEquipment: Set<Equipment> {
        Set(items.map(\.equipment))
    }

    // MARK: - Equipment filter strip

    @ViewBuilder
    private var equipmentFilterStrip: some View {
        if availableEquipment.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    chip(nil, label: "All", symbol: nil)
                    ForEach(Equipment.allCases, id: \.self) { e in
                        if availableEquipment.contains(e) {
                            chip(e, label: e.displayName, symbol: e.symbol)
                        }
                    }
                }
                .padding(.horizontal, 22)
            }
            .padding(.bottom, 14)
        }
    }

    private func chip(_ value: Equipment?, label: String, symbol: String?) -> some View {
        let isSelected = equipmentFilter == value
        return Button {
            Haptics.selection()
            equipmentFilter = value
        } label: {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
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

    // MARK: - Exercise list

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(filteredGroups, id: \.group) { section in
                    groupSection(group: section.group, items: section.items)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
    }

    private func groupSection(group: MuscleGroup, items: [ExerciseCatalogItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(group.accent).frame(width: 8, height: 8)
                Text(group.displayName.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.60))
            }
            .padding(.bottom, 2)
            VStack(spacing: 8) {
                ForEach(items) { item in
                    row(item)
                }
            }
        }
    }

    private func row(_ item: ExerciseCatalogItem) -> some View {
        // Detail screen receives no onPickAndDismiss callback — in
        // the Library context there's nothing to "pick into," so the
        // detail's bottom CTA hides automatically.
        let last = lastInstanceLookup[item.name.lowercased()]
        return NavigationLink {
            ExerciseDetailScreen(item: item, onPickAndDismiss: nil)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.equipment.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(rowSubtitle(item))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.40))
                }

                Spacer(minLength: 8)

                rowRightSide(item: item, last: last)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                customExerciseTarget = .edit(item)
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

    /// Same branching as the picker — when we have history, surface
    /// "LAST · 145 × 8" + relative date with optional gold PR pill;
    /// otherwise show the catalog defaults.
    @ViewBuilder
    private func rowRightSide(item: ExerciseCatalogItem, last: LastExerciseInstance?) -> some View {
        if let last {
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 5) {
                    if last.isAllTimeBest {
                        Text("PR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color(.sRGB, red: 0.96, green: 0.78, blue: 0.32, opacity: 1))
                            )
                    }
                    Text("\(WeightFormatter.string(last.topWeight, unit: unit, includeUnit: false)) × \(last.topReps)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.90))
                }
                Text(RelativeDate.short(last.sessionDate))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }
        } else {
            Text("\(WeightFormatter.string(item.defaultWeight, unit: unit)) · \(item.defaultReps) reps")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private func rowSubtitle(_ item: ExerciseCatalogItem) -> String {
        var parts: [String] = [item.equipment.displayName.uppercased()]
        if item.mechanic == .compound, let pattern = item.pattern {
            parts.append(pattern.displayName.uppercased())
        } else if item.mechanic == .isolation {
            parts.append("ISOLATION")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.30))
            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.50))
                .multilineTextAlignment(.center)
            Button {
                customExerciseTarget = .create
            } label: {
                Label("Create custom exercise", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
    }

    private var emptyMessage: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return "No exercises match \"\(trimmed)\"."
        }
        if equipmentFilter != nil {
            return "No exercises for that equipment."
        }
        return "Your catalog is empty."
    }

    // MARK: - Mutations

    private func delete(_ item: ExerciseCatalogItem) {
        modelContext.delete(item)
        try? modelContext.save()
        Haptics.soft()
    }
}

// MARK: - Template card

/// Reusable card for a row in the Templates list. Same visual as
/// before — extracted here so the file's two content views stay
/// purely about layout + state.
private struct TemplateCard: View {
    let template: WorkoutTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(template.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let used = template.lastUsedAt {
                    Text(Self.relative.localizedString(for: used, relativeTo: Date()).uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Text("\(template.orderedExercises.count) exercises  ·  \(template.totalPlannedSets) sets")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.50))

            if !template.muscleGroups.isEmpty {
                HStack(spacing: 6) {
                    ForEach(template.muscleGroups, id: \.self) { group in
                        Text(group.displayName.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(group.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(group.accent.opacity(0.16))
                            )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

#Preview("Templates") {
    NavigationStack {
        LibraryScreen(appState: AppState())
            .navigationTitle("Library")
    }
    .preferredColorScheme(.dark)
}
