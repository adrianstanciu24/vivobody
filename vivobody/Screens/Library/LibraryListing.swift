//
//  LibraryListing.swift
//  vivobody
//
//  The Library rows the user can see right now, in display order, and the
//  typed IDs that select them. One listing drives both the sidebar rows and
//  the regular-width selection, so a selection never points at a row the
//  list does not show.
//

import Foundation

/// A Library selection. The case keeps exercise and template UUIDs apart,
/// so an ID never resolves in the other table.
enum LibraryItemID: Hashable {
    case exercise(UUID)
    case template(UUID)
}

struct LibraryListing {
    enum Record {
        case exercise(ExerciseCatalogItem)
        case template(WorkoutTemplate)
    }

    let segment: LibrarySegment
    let browser: ExerciseCatalogBrowserSnapshot
    /// Every template in the user's manual order.
    let templates: [WorkoutTemplate]
    /// Templates whose name matches the search, with today's scheduled
    /// plans first. Both partitions keep the manual order.
    let templateRows: [WorkoutTemplate]

    init(
        segment: LibrarySegment,
        browser: ExerciseCatalogBrowserSnapshot,
        templates: [WorkoutTemplate],
        searchText: String,
        weekday: Int = Calendar.current.component(.weekday, from: Date())
    ) {
        self.segment = segment
        self.browser = browser
        self.templates = templates

        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let matches = query.isEmpty
            ? templates
            : templates.filter { $0.name.lowercased().contains(query) }
        templateRows = matches.filter { $0.isScheduled(on: weekday) }
            + matches.filter { !$0.isScheduled(on: weekday) }
    }

    /// The current segment's rows, top to bottom.
    var orderedIDs: [LibraryItemID] {
        switch segment {
        case .exercises:
            let items = browser.isSearching
                ? browser.searchResults
                : browser.sections.flatMap(\.items)
            return items.map { .exercise($0.id) }
        case .templates:
            return templateRows.map { .template($0.id) }
        }
    }

    /// Looks in every live record, not only the visible rows, so a pushed
    /// compact detail keeps its record while a search or filter hides the row.
    func record(for id: LibraryItemID) -> Record? {
        switch id {
        case let .exercise(itemID):
            browser.eligibleItems.first { $0.id == itemID }.map(Record.exercise)
        case let .template(templateID):
            templates.first { $0.id == templateID }.map(Record.template)
        }
    }
}
