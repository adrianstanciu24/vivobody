//
//  BrowserSelectionTests.swift
//  vivobodyTests
//
//  Pins how a browser keeps its selection as the list changes: a valid
//  selection stays, a missing or removed one falls back to the first
//  item, an empty list clears it, and reapplying the rule changes nothing.
//

import Testing
@testable import vivobody

@MainActor
struct BrowserSelectionTests {
    private let ids = ["newest", "older", "oldest"]

    private func reconcile(_ current: String?, in ids: [String]) -> String? {
        BrowserSelection.retainOrFirst(current, isValid: ids.contains, first: ids.first)
    }

    @Test func noSelectionPicksTheFirstItem() {
        #expect(reconcile(nil, in: ids) == "newest")
    }

    @Test func validSelectionIsRetained() {
        #expect(reconcile("oldest", in: ids) == "oldest")
    }

    @Test func removedSelectionFallsBackToTheFirstItem() {
        #expect(reconcile("deleted", in: ids) == "newest")
    }

    @Test func emptyListClearsTheSelection() {
        #expect(reconcile("older", in: []) == nil)
        #expect(reconcile(nil, in: []) == nil)
    }

    @Test func reapplyingTheRuleChangesNothing() {
        for current in [nil, "older", "deleted"] {
            let once = reconcile(current, in: ids)
            #expect(reconcile(once, in: ids) == once)
        }
    }
}
