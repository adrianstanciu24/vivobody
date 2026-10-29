//
//  LibraryListingTests.swift
//  vivobodyTests
//
//  Pins the Library rows that drive both the sidebar and the regular-width
//  selection: template search and today-first order, segment-scoped IDs in
//  display order, and record lookup that keeps exercise and template IDs
//  apart while still finding a record whose row is hidden.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct LibraryListingTests {
    private let monday = 2

    private func template(_ name: String, id: UUID = UUID(), scheduledOn weekdays: [Int] = []) -> WorkoutTemplate {
        let template = WorkoutTemplate(id: id, name: name)
        template.scheduledWeekdays = weekdays
        return template
    }

    private func exercise(_ name: String, id: UUID = UUID(), group: MuscleGroup = .back) -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            id: id,
            catalogID: nil,
            name: name,
            group: group,
            defaultWeight: 100,
            modality: .dynamicStrength,
            equipment: .barbell,
            mechanic: .compound,
            trainingRole: nil,
            pattern: .pull,
            direction: .horizontal,
            isUserCreated: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func listing(
        _ segment: LibrarySegment,
        exercises: [ExerciseCatalogItem] = [],
        templates: [WorkoutTemplate] = [],
        search: String = ""
    ) -> LibraryListing {
        LibraryListing(
            segment: segment,
            browser: ExerciseCatalogBrowserSnapshot(
                items: exercises,
                query: search,
                filter: .all,
                lastInstanceLookup: [:],
                unit: .kg
            ),
            templates: templates,
            searchText: search,
            weekday: monday
        )
    }

    @Test func todaysTemplatesLeadAndBothPartitionsKeepManualOrder() {
        let templates = [
            template("Upper A"),
            template("Lower B", scheduledOn: [monday]),
            template("Full Body", scheduledOn: [monday, 5]),
            template("Mobility", scheduledOn: [4]),
        ]

        let rows = listing(.templates, templates: templates).templateRows

        #expect(rows.map(\.name) == ["Lower B", "Full Body", "Upper A", "Mobility"])
    }

    @Test func templateSearchMatchesTrimmedNamesIgnoringCase() {
        let templates = [template("Upper A"), template("Lower B"), template("upper b")]

        #expect(listing(.templates, templates: templates, search: "  UPPER ").templateRows.map(\.name)
            == ["Upper A", "upper b"])
        #expect(listing(.templates, templates: templates, search: "zzz").templateRows.isEmpty)
    }

    @Test func orderedIDsFollowTheVisibleSegment() {
        let row = exercise("Cable Row", group: .back)
        let press = exercise("Bench Press", group: .chest)
        let plan = template("Upper A")

        let exercises = listing(.exercises, exercises: [row, press], templates: [plan])
        #expect(exercises.orderedIDs == [.exercise(press.id), .exercise(row.id)])

        let templates = listing(.templates, exercises: [row, press], templates: [plan])
        #expect(templates.orderedIDs == [.template(plan.id)])
    }

    @Test func searchingExercisesListsOnlyTheRankedResults() {
        let row = exercise("Cable Row")
        let press = exercise("Bench Press", group: .chest)

        let searched = listing(.exercises, exercises: [row, press], search: "press")

        #expect(searched.orderedIDs == [.exercise(press.id)])
    }

    @Test func recordsResolveOnlyInTheirOwnTable() {
        let sharedID = UUID()
        let item = exercise("Cable Row", id: sharedID)
        let plan = template("Upper A", id: sharedID)
        let both = listing(.exercises, exercises: [item], templates: [plan])

        guard case let .exercise(foundItem)? = both.record(for: .exercise(sharedID)),
              case let .template(foundPlan)? = both.record(for: .template(sharedID))
        else {
            Issue.record("Both records should resolve")
            return
        }
        #expect(foundItem === item)
        #expect(foundPlan === plan)
        #expect(both.record(for: .exercise(UUID())) == nil)
        #expect(listing(.exercises, exercises: [item]).record(for: .template(sharedID)) == nil)
    }

    @Test func aRowHiddenBySearchStillResolvesForAPushedDetail() {
        let row = exercise("Cable Row")
        let press = exercise("Bench Press", group: .chest)

        let searched = listing(.exercises, exercises: [row, press], search: "press")

        #expect(!searched.orderedIDs.contains(.exercise(row.id)))
        #expect(searched.record(for: .exercise(row.id)) != nil)
    }
}
