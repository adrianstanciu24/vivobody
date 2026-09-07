//
//  IncomingActionTests.swift
//  vivobodyTests
//
//  Keeps existing widget links useful after removing purchase-based access.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct IncomingActionTests {
    @Test func formerPurchaseLinkOpensInsights() throws {
        let url = try #require(URL(string: "vivobody://pro"))
        #expect(IncomingActionParser.from(url: url) == .openTab(.insights))
    }

    @Test func analyticsWidgetLinksOpenTheirContent() throws {
        for route in ["insights", "insights/consistency"] {
            let url = try #require(URL(string: "vivobody://\(route)"))
            #expect(IncomingActionParser.from(url: url) == .openTab(.insights))
        }
        let strengthURL = try #require(URL(string: "vivobody://library"))
        #expect(IncomingActionParser.from(url: strengthURL) == .openTab(.library))
    }
}
