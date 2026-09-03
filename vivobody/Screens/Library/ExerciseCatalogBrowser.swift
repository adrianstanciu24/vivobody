//
//  ExerciseCatalogBrowser.swift
//  vivobody
//
//  Shared catalog-browsing contract for Library and exercise pickers. It owns
//  the common SwiftData queries, cached history projection, filtering/search
//  snapshot, and persisted row actions while each surface keeps its own
//  navigation, layout, empty-state copy, and tap behavior.
//

import SwiftData
import SwiftUI
import VivoKit

/// One mutually exclusive catalog scope shared by Library and exercise pickers.
enum ExerciseCatalogFilter: Hashable {
    case all
    case favorites
    case core
    case trainingRole(TrainingRole)
    case equipment(Equipment)

    func matches(_ item: ExerciseCatalogItem) -> Bool {
        switch self {
        case .all:
            true
        case .favorites:
            item.isFavorite
        case .core:
            item.group == .core
        case let .trainingRole(role):
            item.trainingRole == role
        case let .equipment(equipment):
            item.equipment == equipment
        }
    }

    var displayName: String {
        switch self {
        case .all: "All"
        case .favorites: "Favorites"
        case .core: "Core"
        case let .trainingRole(role): role.displayName
        case let .equipment(equipment): equipment.displayName
        }
    }

    var accessibilitySuffix: String {
        switch self {
        case .all: "All"
        case .favorites: "Favorites"
        case .core: "Core"
        case let .trainingRole(role): role.displayName
        case let .equipment(equipment): equipment.displayName.replacingOccurrences(of: " ", with: "")
        }
    }
}

/// Pure, render-ready projection of catalog items and personal history.
struct ExerciseCatalogBrowserSnapshot {
    struct Section {
        let group: MuscleGroup
        let items: [ExerciseCatalogItem]
    }

    let eligibleItems: [ExerciseCatalogItem]
    let searchResults: [ExerciseCatalogItem]
    let sections: [Section]
    let availableEquipment: Set<Equipment>
    let isSearching: Bool
    let unit: WeightUnit

    private let lastInstanceLookup: [String: LastExerciseInstance]

    init(
        items: [ExerciseCatalogItem],
        query: String,
        filter: ExerciseCatalogFilter,
        lastInstanceLookup: [String: LastExerciseInstance],
        unit: WeightUnit,
        includes: (ExerciseCatalogItem) -> Bool = { _ in true }
    ) {
        let eligibleItems = items.filter(includes)
        let scopedItems = eligibleItems.filter(filter.matches)
        let isSearching = !query.trimmingCharacters(in: .whitespaces).isEmpty

        self.eligibleItems = eligibleItems
        self.isSearching = isSearching
        self.availableEquipment = Set(eligibleItems.map(\.equipment))
        self.lastInstanceLookup = lastInstanceLookup
        self.unit = unit

        if isSearching {
            searchResults = ExerciseSearch.rank(
                items: scopedItems,
                query: query,
                trackedKeys: Set(lastInstanceLookup.keys)
            )
            sections = []
        } else {
            searchResults = []
            sections = scopedItems.groupedByMuscle.map {
                Section(group: $0.group, items: $0.items)
            }
        }
    }

    var hasEligibleItems: Bool {
        !eligibleItems.isEmpty
    }

    func lastInstance(for item: ExerciseCatalogItem) -> LastExerciseInstance? {
        lastInstanceLookup[item.historyKey]
    }

    func filterOptions(includingCore: Bool) -> [ExerciseCatalogFilter] {
        var options: [ExerciseCatalogFilter] = [
            .all,
            .favorites,
            .trainingRole(.push),
            .trainingRole(.pull),
        ]
        if includingCore, eligibleItems.contains(where: { $0.group == .core }) {
            options.append(.core)
        }
        options.append(contentsOf: Equipment.allCases.compactMap { equipment in
            availableEquipment.contains(equipment) ? .equipment(equipment) : nil
        })
        return options
    }

    /// Shared row vocabulary: equipment followed by movement or isolation role.
    func metadataLine(for item: ExerciseCatalogItem) -> String {
        var parts: [String] = [item.equipment.displayName]
        if item.mechanic == .compound, let movementLabel = item.movementLabel {
            parts.append(movementLabel)
        } else if item.mechanic == .isolation {
            if let trainingRole = item.trainingRole {
                parts.append(trainingRole.displayName)
            }
            parts.append("Isolation")
        }
        return parts.joined(separator: " · ")
    }
}

/// Persisted actions exposed to both catalog-row renderers.
struct ExerciseCatalogBrowserActions {
    let allowsEditing: Bool

    private let onToggleFavorite: (ExerciseCatalogItem) -> Void
    private let onEdit: (ExerciseCatalogItem) -> Void
    private let onDuplicate: (ExerciseCatalogItem) -> Void
    private let onRequestDelete: (ExerciseCatalogItem) -> Void

    init(
        allowsEditing: Bool,
        onToggleFavorite: @escaping (ExerciseCatalogItem) -> Void,
        onEdit: @escaping (ExerciseCatalogItem) -> Void,
        onDuplicate: @escaping (ExerciseCatalogItem) -> Void,
        onRequestDelete: @escaping (ExerciseCatalogItem) -> Void
    ) {
        self.allowsEditing = allowsEditing
        self.onToggleFavorite = onToggleFavorite
        self.onEdit = onEdit
        self.onDuplicate = onDuplicate
        self.onRequestDelete = onRequestDelete
    }

    func toggleFavorite(_ item: ExerciseCatalogItem) {
        onToggleFavorite(item)
    }

    func edit(_ item: ExerciseCatalogItem) {
        onEdit(item)
    }

    func duplicate(_ item: ExerciseCatalogItem) {
        onDuplicate(item)
    }

    func requestDelete(_ item: ExerciseCatalogItem) {
        onRequestDelete(item)
    }
}

/// Query and mutation host. Its content closure keeps surface rendering local.
struct ExerciseCatalogBrowserHost<Content: View>: View {
    let query: String
    let filter: ExerciseCatalogFilter
    let includes: (ExerciseCatalogItem) -> Bool
    let allowsCatalogEditing: Bool
    let onEdit: (ExerciseCatalogItem) -> Void
    let onDuplicate: (ExerciseCatalogItem) -> Void
    let content: (ExerciseCatalogBrowserSnapshot, ExerciseCatalogBrowserActions) -> Content

    @Environment(\.modelContext) private var modelContext
    @Environment(\.sessionAnalytics) private var sessionAnalytics

    @Query private var items: [ExerciseCatalogItem]

    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: \WorkoutSession.completedAt,
        order: .reverse
    )
    private var completedSessions: [WorkoutSession]

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    @State private var pendingDeleteItem: ExerciseCatalogItem?
    @State private var saveError: SaveErrorBox?

    init(
        query: String,
        filter: ExerciseCatalogFilter,
        includes: @escaping (ExerciseCatalogItem) -> Bool = { _ in true },
        allowsCatalogEditing: Bool = true,
        onEdit: @escaping (ExerciseCatalogItem) -> Void,
        onDuplicate: @escaping (ExerciseCatalogItem) -> Void,
        @ViewBuilder content: @escaping (
            ExerciseCatalogBrowserSnapshot,
            ExerciseCatalogBrowserActions
        ) -> Content
    ) {
        self.query = query
        self.filter = filter
        self.includes = includes
        self.allowsCatalogEditing = allowsCatalogEditing
        self.onEdit = onEdit
        self.onDuplicate = onDuplicate
        self.content = content
    }

    var body: some View {
        let analyticsRequest = sessionAnalytics?.requestKey(for: completedSessions)
        let lookup = sessionAnalytics?.lastInstances
            ?? completedSessions.lastInstanceByExercise()
        let snapshot = ExerciseCatalogBrowserSnapshot(
            items: items,
            query: query,
            filter: filter,
            lastInstanceLookup: lookup,
            unit: WeightUnit(rawValue: unitRaw) ?? .lb,
            includes: includes
        )
        let actions = ExerciseCatalogBrowserActions(
            allowsEditing: allowsCatalogEditing,
            onToggleFavorite: toggleFavorite,
            onEdit: onEdit,
            onDuplicate: onDuplicate,
            onRequestDelete: { pendingDeleteItem = $0 }
        )

        content(snapshot, actions)
            .task(id: analyticsRequest) {
                sessionAnalytics?.requestCore(for: completedSessions)
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
                Text("This removes the exercise from your catalog. Templates and history that already reference it stay intact.")
            }
            .saveErrorAlert($saveError)
    }

    private func toggleFavorite(_ item: ExerciseCatalogItem) {
        item.isFavorite.toggle()
        do {
            try modelContext.saveOrRollback()
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.tick()
    }

    private func delete(_ item: ExerciseCatalogItem) {
        do {
            try CatalogMutationBoundary(context: modelContext).delete(item)
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.soft()
    }
}

/// Shared chip semantics with surface-owned strip padding and placement.
struct ExerciseCatalogFilterStrip: View {
    let options: [ExerciseCatalogFilter]
    @Binding var selection: ExerciseCatalogFilter
    let accessibilityPrefix: String
    let spacing: CGFloat
    let horizontalContentPadding: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: spacing) {
                HStack(spacing: spacing) {
                    ForEach(options, id: \.self) { option in
                        chip(option)
                    }
                }
            }
            .padding(.horizontal, horizontalContentPadding)
        }
        .scrollClipDisabled()
    }

    private func chip(_ option: ExerciseCatalogFilter) -> some View {
        let isSelected = selection == option
        return Button {
            Haptics.selection()
            selection = option
        } label: {
            Text(option.displayName)
                .font(Typography.sectionLabel)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .padding(.horizontal, Space.lg)
                .frame(minHeight: Space.tapMin)
                .coloredGlassControl(
                    cornerRadius: Radius.pill,
                    fill: isSelected ? Tint.inProgress : nil
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(accessibilityPrefix)\(option.accessibilitySuffix)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct ExerciseCatalogActionMenu: View {
    let item: ExerciseCatalogItem
    let actions: ExerciseCatalogBrowserActions

    var body: some View {
        Button {
            actions.toggleFavorite(item)
        } label: {
            Label(
                item.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: item.isFavorite ? "star.slash" : "star"
            )
        }

        Button {
            actions.edit(item)
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        if item.catalogID != nil, !item.isUserCreated {
            Button {
                actions.duplicate(item)
            } label: {
                Label("Duplicate as Custom", systemImage: "plus.square.on.square")
            }
        }

        Button(role: .destructive) {
            actions.requestDelete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

extension View {
    @ViewBuilder
    func exerciseCatalogActions(
        for item: ExerciseCatalogItem,
        actions: ExerciseCatalogBrowserActions
    ) -> some View {
        if actions.allowsEditing {
            contextMenu {
                ExerciseCatalogActionMenu(item: item, actions: actions)
            }
        } else {
            self
        }
    }
}
