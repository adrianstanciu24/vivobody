//
//  ExercisePickerSheet.swift
//  vivobody
//
//  Purpose-driven modal browser for the exercise catalog. The purpose
//  keeps each caller's title, tap behavior, trailing affordance,
//  accessibility hint, comparison availability, and exclusions together:
//  workout flows explore detail before adding (with comparison suppressed
//  during a live session), template editing adds immediately, and exercise
//  comparison immediately chooses any exercise except its anchor.
//
//  Catalog is SwiftData-backed (see ExerciseCatalogItem.swift), so general
//  browsing purposes let users extend it inline:
//    • Toolbar "+" — create a new custom exercise.
//    • Long-press on any row — context menu with Favorite, Edit, optional
//      Duplicate as Custom, and Delete. Edit opens the same
//      CustomExerciseEditorSheet; Delete asks for confirmation.
//
//  Routine-planning purposes instead expose only compatible bundled strength
//  records and suppress every catalog mutation affordance.
//
//  Favorited exercises carry a star next to their name, and the chip
//  strip always offers a Favorites scope.
//
//  Sectioned by muscle group for browsing; while a search query is
//  active the sections collapse into a flat, relevance-ranked list
//  (see ExerciseSearch) so "pull" surfaces "Pull-Up" first instead
//  of respecting muscle-group enum order. Search uses
//  .searchable(placement: .toolbar) + .searchToolbarBehavior(.minimize)
//  — the field lives in the bottom toolbar and collapses on scroll,
//  matching Library's house style.
//
//  ExerciseCatalogBrowserHost owns the shared catalog/history projection and
//  persisted row actions; this file owns purpose-specific selection and layout.
//

import SwiftUI
import VivoKit

struct ExercisePickerSheet: View {
    let purpose: ExercisePickerPurpose
    let onPick: (ExerciseCatalogItem) -> Void

    init(
        purpose: ExercisePickerPurpose = .explore,
        onPick: @escaping (ExerciseCatalogItem) -> Void
    ) {
        self.purpose = purpose
        self.onPick = onPick
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var query: String = ""
    @State private var editorTarget: CatalogEditorTarget?

    /// Catalog scope chosen in the chip strip — All, Favorites, a training
    /// role, or one equipment. The picker never offers the Library-only Core
    /// shortcut.
    @State private var filter: ExerciseCatalogFilter = .all

    var body: some View {
        ExerciseCatalogBrowserHost(
            query: query,
            filter: filter,
            includes: { purpose.includes($0) },
            allowsCatalogEditing: purpose.allowsCatalogEditing,
            onEdit: { editorTarget = .edit($0) },
            onDuplicate: { editorTarget = .duplicate($0) }
        ) { browser, actions in
            NavigationStack {
                ZStack {
                    Surface.background.ignoresSafeArea()

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Space.section) {
                            equipmentFilterStrip(browser)
                            if browser.isSearching {
                                searchResultsList(browser, actions: actions)
                            } else {
                                ForEach(browser.sections, id: \.group) { section in
                                    groupSection(
                                        group: section.group,
                                        items: section.items,
                                        browser: browser,
                                        actions: actions
                                    )
                                }
                                if browser.sections.isEmpty {
                                    emptyState
                                }
                            }
                        }
                        .padding(.top, Space.md)
                        .padding(.bottom, Space.xxl)
                    }
                    .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                }
                .navigationTitle(purpose.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        if purpose.allowsCatalogEditing {
                            Button {
                                editorTarget = .create
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("Create custom exercise")
                        }
                    }
                }
                .searchable(text: $query, placement: .toolbar, prompt: Text("Search exercises"))
                .searchToolbarBehavior(.minimize)
                .sheet(item: $editorTarget) { target in
                    CustomExerciseEditorSheet(target: target)
                }
            }
        }
    }

    // MARK: - Catalog filter strip

    /// Horizontal chip strip at the top of the picker. Equipment choices come
    /// from purpose-eligible items, so routine constraints never expose a chip
    /// that can only lead to an empty result.
    @ViewBuilder
    private func equipmentFilterStrip(_ browser: ExerciseCatalogBrowserSnapshot) -> some View {
        if browser.hasEligibleItems {
            ExerciseCatalogFilterStrip(
                options: browser.filterOptions(includingCore: false),
                selection: $filter,
                accessibilityPrefix: "exercisePickerFilter",
                spacing: 8,
                horizontalContentPadding: 2
            )
            // Counter the LazyVStack's padding so the chips align
            // with the screen edges, not the content insets.
            .padding(.horizontal, -Space.gutter)
            .padding(.horizontal, Space.gutter)
        }
    }

    // MARK: - Sections / rows

    // MARK: - Search results (flat, ranked)

    /// While a query is active, drops the muscle-group sections for
    /// one flat, best-match-first list — the grouped layout can only
    /// rank within a group, so it can never put "Pull-Up" above
    /// "Cable Pull-Through" by relevance. Rows reuse `pickerRow` so
    /// the pick-on-tap / navigate / context-menu behavior is
    /// identical to the grouped path.
    @ViewBuilder
    private func searchResultsList(
        _ browser: ExerciseCatalogBrowserSnapshot,
        actions: ExerciseCatalogBrowserActions
    ) -> some View {
        if browser.searchResults.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(Array(browser.searchResults.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { SectionDivider() }
                    pickerRow(item, browser: browser, actions: actions)
                }
            }
        }
    }

    private func groupSection(
        group: MuscleGroup,
        items: [ExerciseCatalogItem],
        browser: ExerciseCatalogBrowserSnapshot,
        actions: ExerciseCatalogBrowserActions
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: group.displayName)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { SectionDivider() }
                    pickerRow(item, browser: browser, actions: actions)
                }
            }
        }
    }

    @ViewBuilder
    private func pickerRow(
        _ item: ExerciseCatalogItem,
        browser: ExerciseCatalogBrowserSnapshot,
        actions: ExerciseCatalogBrowserActions
    ) -> some View {
        let last = browser.lastInstance(for: item)

        Group {
            switch purpose {
            case .addToTemplate, .compare, .routineInclude, .routineAvoid, .routineSwap:
                // Direct selection is purpose-specific: templates use
                // an add glyph, comparisons use a bidirectional arrow.
                Button {
                    Haptics.soft()
                    onPick(item)
                    dismiss()
                } label: {
                    rowBody(
                        item: item,
                        last: last,
                        accessory: purpose.rowAccessory,
                        browser: browser
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint(purpose.directPickAccessibilityHint)

            case .explore, .addToActiveWorkout:
                // Row taps navigate to detail instead of immediately
                // picking; the user commits via the "Add to Workout"
                // CTA on the detail screen.
                NavigationLink {
                    ExerciseDetailScreen(
                        item: item,
                        allowsComparison: purpose.allowsComparison,
                        onPickAndDismiss: { picked in
                            onPick(picked)
                            dismiss()
                        }
                    )
                } label: {
                    rowBody(
                        item: item,
                        last: last,
                        accessory: purpose.rowAccessory,
                        browser: browser
                    )
                }
                .buttonStyle(.plain)
            }
        }
        // General browsing keeps catalog actions available. Routine purposes
        // intentionally expose an immutable bundled subset.
        .exerciseCatalogActions(for: item, actions: actions)
    }

    private func rowBody(
        item: ExerciseCatalogItem,
        last: LastExerciseInstance?,
        accessory: ExercisePickerRowAccessory,
        browser: ExerciseCatalogBrowserSnapshot
    ) -> some View {
        let isProminent = accessory != .disclosure
        let accessoryColor: Color = switch accessory {
        case .add: Tint.inProgress
        case .compare, .swap: Ink.secondary
        case .disclosure: Ink.quaternary
        }
        return HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                    Text(item.name)
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(Typography.caption)
                            .foregroundStyle(Tint.complete)
                            .accessibilityLabel("Favorite")
                    }
                }
                Text(browser.metadataLine(for: item))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.sm)

            // Right side is history-only — it answers "what should
            // I aim to beat?" while the picker is still open. Never-
            // logged exercises show nothing there: the catalog holds
            // facts, not prescriptions, so no invented numbers.
            rowRightSide(last: last, unit: browser.unit)

            Image(systemName: accessory.systemName)
                .font(isProminent ? Typography.headline : Typography.caption)
                .foregroundStyle(accessoryColor)
                .accessibilityHidden(true)
        }
        .frame(minHeight: Space.rowMin)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Right-side rendering of a picker row. History-only: shows
    /// `LAST · 145 lb × 8` plus the relative date below in dim mono.
    /// If that last top set is also the all-time best, it renders in
    /// the complete tint so the user knows their last bench WAS
    /// their PR. Never-logged exercises get nothing — catalog
    /// defaults are input seeds, not numbers worth displaying.
    @ViewBuilder
    private func rowRightSide(last: LastExerciseInstance?, unit: WeightUnit) -> some View {
        if let last {
            VStack(alignment: .trailing, spacing: 2) {
                Text(last.metricLabel(unit: unit))
                    .font(Typography.metricInline)
                    .foregroundStyle(last.isAllTimeBest ? Tint.complete : Ink.primary)
                    .monospacedDigit()
                Text(RelativeDate.short(last.sessionDate))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
        }
    }

    // MARK: - Empty state

    /// The Favorites scope gets a teaching empty state (title +
    /// smaller description, no CTA) — creating a new exercise
    /// wouldn't fill it; starring an existing one would.
    @ViewBuilder
    private var emptyState: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty, filter == .favorites {
            if purpose.allowsCatalogEditing {
                ContentUnavailableView {
                    Label("No favorite exercises yet", systemImage: "dumbbell")
                } description: {
                    Text("Long-press an exercise to favorite it.")
                }
            } else {
                ContentUnavailableView(
                    "No favorite exercises available",
                    systemImage: "dumbbell"
                )
            }
        } else if purpose.allowsCatalogEditing {
            ContentUnavailableView {
                Label(emptyStateMessage, systemImage: "dumbbell")
            } actions: {
                Button {
                    editorTarget = .create
                } label: {
                    Text("Create custom exercise")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        } else {
            ContentUnavailableView(emptyStateMessage, systemImage: "dumbbell")
        }
    }

    private var emptyStateMessage: String {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return "No exercises match \"\(trimmed)\"."
        }
        switch filter {
        case .all:
            return purpose.isRoutinePurpose
                ? "No compatible exercises."
                : "Your catalog is empty.\nTap below to add an exercise."
        case .favorites:
            return "No favorite exercises available."
        case .core:
            return "No Core exercises."
        case let .trainingRole(role):
            return "No \(role.displayName) exercises."
        case .equipment:
            return "No exercises for that equipment."
        }
    }
}
