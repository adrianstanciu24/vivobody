//
//  LibraryExercisesContent.swift
//  vivobody
//
//  Exercises segment content for the Library screen. Extracted
//  from LibraryScreen.swift for file size management. Shared catalog queries,
//  history projection, filtering, and row actions live in
//  ExerciseCatalogBrowserHost; this file owns Library-specific hierarchy.
//

import SwiftUI
import VivoKit

// MARK: - Exercises content

/// Exercises segment — browsable catalog. Tap an exercise row to
/// push its detail screen (no commit CTA in this context). Long-
/// press for Favorite / Edit / Duplicate / Delete via context menu. The filter
/// strip offers training-role and equipment scopes plus prominent
/// Favorites and Core shortcuts; favorited rows carry a star next
/// to the name.
struct LibraryExercisesContent: View {
    let searchText: String
    @Binding var segment: LibrarySegment
    @Binding var customExerciseTarget: CatalogEditorTarget?

    /// Owned by LibraryScreen so the selected chip survives segment
    /// switches — this content view is recreated on every switch.
    @Binding var exerciseFilter: ExerciseCatalogFilter

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ExerciseCatalogBrowserHost(
            query: searchText,
            filter: exerciseFilter,
            onEdit: { customExerciseTarget = .edit($0) },
            onDuplicate: { customExerciseTarget = .duplicate($0) }
        ) { browser, actions in
            Group {
                if browser.isSearching {
                    searchList(browser, actions: actions)
                } else if browser.sections.isEmpty {
                    VStack(spacing: 0) {
                        LibrarySegmentBar(selection: $segment)
                        catalogFilterStrip(browser)
                        emptyState
                    }
                } else {
                    exerciseList(browser, actions: actions)
                }
            }
        }
    }

    // MARK: - Catalog filter strip

    /// Favorites is always offered — selecting it with no stars set
    /// lands on an empty state that teaches the long-press gesture.
    @ViewBuilder
    private func catalogFilterStrip(_ browser: ExerciseCatalogBrowserSnapshot) -> some View {
        if browser.hasEligibleItems {
            ExerciseCatalogFilterStrip(
                options: browser.filterOptions(includingCore: true),
                selection: $exerciseFilter,
                accessibilityPrefix: "libraryExerciseFilter",
                spacing: Space.md,
                horizontalContentPadding: Space.gutter
            )
            .padding(.bottom, Space.lg)
        }
    }

    // MARK: - Exercise list

    private func exerciseList(
        _ browser: ExerciseCatalogBrowserSnapshot,
        actions: ExerciseCatalogBrowserActions
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header scrolls with the catalog so the large title
                // collapses cleanly instead of fighting a pinned bar.
                LibrarySegmentBar(selection: $segment)
                    .padding(.horizontal, -Space.gutter)
                catalogFilterStrip(browser)
                    .padding(.horizontal, -Space.gutter)

                LazyVStack(alignment: .leading, spacing: Space.section) {
                    ForEach(Array(browser.sections.enumerated()), id: \.element.group) { index, section in
                        groupSection(
                            group: section.group,
                            items: section.items,
                            browser: browser,
                            actions: actions
                        )
                        .settleIn(index)
                    }
                }
                .padding(.bottom, Space.xxl + Space.xs)
            }
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    // MARK: - Search list (flat, ranked)

    /// While a search query is active, muscle-group sections are
    /// dropped in favor of one flat, best-match-first list — the
    /// grouped layout can only rank *within* a group, so it can never
    /// put "Pull-Up" (back) above "Cable Pull-Through" (legs) by
    /// relevance. Rows reuse the same `row(_:)` renderer as the
    /// grouped path so the prominent/recent decoration stays
    /// consistent. Empty query keeps the grouped browse (`exerciseList`).
    private func searchList(
        _ browser: ExerciseCatalogBrowserSnapshot,
        actions: ExerciseCatalogBrowserActions
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LibrarySegmentBar(selection: $segment)
                    .padding(.horizontal, -Space.gutter)
                catalogFilterStrip(browser)
                    .padding(.horizontal, -Space.gutter)

                if browser.searchResults.isEmpty {
                    emptyState
                        .padding(.top, Space.xxl)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(browser.searchResults.enumerated()), id: \.element.id) { idx, item in
                            if idx > 0 { insetRowDivider }
                            row(item, browser: browser, actions: actions)
                                .settleIn(idx)
                        }
                    }
                    .contentCard()
                    .padding(.bottom, Space.xxl + Space.xs)
                }
            }
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    /// One muscle group as a ledger block, mirroring History's date
    /// groups: the `SectionHeader` stays on black, the group's rows
    /// sit together inside a single content card with inset
    /// hairlines between them.
    private func groupSection(
        group: MuscleGroup,
        items: [ExerciseCatalogItem],
        browser: ExerciseCatalogBrowserSnapshot,
        actions: ExerciseCatalogBrowserActions
    ) -> some View {
        let trackedCount = items.reduce(into: 0) { acc, item in
            if browser.lastInstance(for: item) != nil { acc += 1 }
        }

        return VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(
                title: group.displayName,
                trailing: sectionSubtitle(total: items.count, tracked: trackedCount)
            )
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { insetRowDivider }
                    row(item, browser: browser, actions: actions)
                }
            }
            .contentCard()
        }
    }

    /// In-card hairline between rows, inset so it never runs into
    /// the card's rounded corners.
    private var insetRowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
            .padding(.horizontal, Space.lg)
            .accessibilityHidden(true)
    }

    private func sectionSubtitle(total: Int, tracked: Int) -> String {
        let exercises = total == 1 ? "1 exercise" : "\(total) exercises"
        guard tracked > 0 else { return exercises }
        return "\(exercises) · \(tracked) tracked"
    }

    /// Row classifier: an exercise lifted within the last 14 days
    /// reads prominent (brighter name, larger weight×reps numeral);
    /// everything else stays tighter. Mirrors the History list's
    /// elevated-recent / quiet-older split, keyed on the exercise's
    /// last-performed date.
    private func row(
        _ item: ExerciseCatalogItem,
        browser: ExerciseCatalogBrowserSnapshot,
        actions: ExerciseCatalogBrowserActions
    ) -> some View {
        let last = browser.lastInstance(for: item)
        let isRecent: Bool = {
            guard let last else { return false }
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: last.sessionDate),
                to: Calendar.current.startOfDay(for: Date())
            ).day ?? .max
            return days <= 14
        }()

        return rowLink(item: item, actions: actions) {
            exerciseRow(
                item: item,
                last: last,
                prominent: last != nil && isRecent,
                browser: browser
            )
        }
    }

    /// Detail screen receives no onPickAndDismiss callback — in the
    /// Library context there's nothing to "pick into," so the
    /// detail's bottom CTA hides automatically. Extracted so both
    /// row tiers share one navigation site + one context menu.
    private func rowLink(
        item: ExerciseCatalogItem,
        actions: ExerciseCatalogBrowserActions,
        @ViewBuilder label: () -> some View
    ) -> some View {
        NavigationLink {
            ExerciseDetailScreen(item: item, onPickAndDismiss: nil)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .exerciseCatalogActions(for: item, actions: actions)
    }

    // MARK: Exercise row

    /// One catalog row inside its muscle-group card, divided from
    /// its neighbours by an inset hairline. Name + sentence-case
    /// meta (which carries the equipment) on the left; on the right
    /// the last session's heaviest set as a monospaced `weight×reps`
    /// numeral (gold when it's an all-time best) over a relative
    /// date, or nothing when the exercise has never been logged.
    /// `prominent` (lifted within 14 days) brightens the name and
    /// enlarges the numeral.
    private func exerciseRow(
        item: ExerciseCatalogItem,
        last: LastExerciseInstance?,
        prominent: Bool,
        browser: ExerciseCatalogBrowserSnapshot
    ) -> some View {
        HStack(alignment: .center, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                    Text(item.name)
                        .font(Typography.sectionHeading)
                        .foregroundStyle(prominent ? Ink.primary : Ink.secondary)
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
                    .foregroundStyle(prominent ? Ink.tertiary : Ink.quaternary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: Space.sm)

            rowTrailing(last: last, prominent: prominent, unit: browser.unit)

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: prominent ? 64 : Space.rowMin, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Trailing side is history-only. Never-logged exercises show
    /// nothing here — catalog defaults are input seeds, not numbers
    /// worth displaying as if they were the user's own.
    @ViewBuilder
    private func rowTrailing(
        last: LastExerciseInstance?,
        prominent: Bool,
        unit: WeightUnit
    ) -> some View {
        if let last {
            // Keep the numeral on one line and let it hold its width:
            // a long name should wrap to two lines rather than squeeze
            // "180 × 10" into a wrapped, oversized stack over the date.
            VStack(alignment: .trailing, spacing: 2) {
                Text(last.metricLabel(unit: unit))
                    .font(prominent ? Typography.statValueCompact : Typography.metricInline)
                    .foregroundStyle(last.isAllTimeBest ? Tint.complete : Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(RelativeDate.short(last.sessionDate))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
            .layoutPriority(1)
        }
    }

    // MARK: - Empty state

    /// The Favorites scope gets a teaching empty state (title +
    /// smaller description, no CTA) — creating a new exercise
    /// wouldn't fill it; starring an existing one would.
    @ViewBuilder
    private var emptyState: some View {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty,
           exerciseFilter == .favorites
        {
            ContentUnavailableView {
                Label("No favorite exercises yet", systemImage: "dumbbell")
            } description: {
                Text("Long-press an exercise to favorite it.")
            }
        } else {
            ContentUnavailableView {
                Label(emptyMessage, systemImage: "dumbbell")
            } actions: {
                Button {
                    customExerciseTarget = .create
                } label: {
                    Text("Create custom exercise")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var emptyMessage: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return "No exercises match \"\(trimmed)\"."
        }
        switch exerciseFilter {
        case .all, .favorites:
            return "Your catalog is empty."
        case .core:
            return "No Core exercises."
        case let .trainingRole(role):
            return "No \(role.displayName) exercises."
        case .equipment:
            return "No exercises for that equipment."
        }
    }
}
