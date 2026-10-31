//
//  ActiveExerciseCardDensityTests.swift
//  vivobodyTests
//
//  Pins when the phone column packs an exercise page tighter: only a page
//  shorter than the standard column, such as the folded iPhone Duo display,
//  and never before the page has a size.
//

import CoreGraphics
import Testing
@testable import vivobody

struct ActiveExerciseCardDensityTests {
    @Test func aShortPageIsCompact() {
        #expect(ActiveExerciseCardDensity(pageHeight: 512) == .compact)
        #expect(ActiveExerciseCardDensity(pageHeight: 599) == .compact)
    }

    @Test func aPhonePageStaysRegular() {
        #expect(ActiveExerciseCardDensity(pageHeight: 600) == .regular)
        #expect(ActiveExerciseCardDensity(pageHeight: 639) == .regular)
    }

    @Test func aPageBeforeItsFirstLayoutStaysRegular() {
        #expect(ActiveExerciseCardDensity(pageHeight: 0) == .regular)
    }

    @Test func compactTakesOneNameLineAndASmallerWorkingValue() {
        let compact = ActiveExerciseCardDensity.compact
        #expect(compact.nameLineLimit == 1)
        #expect(compact.heroFontSize(104) == 83)
        #expect(compact.heroFontSize(80) == 64)

        let regular = ActiveExerciseCardDensity.regular
        #expect(regular.nameLineLimit == 2)
        #expect(regular.heroFontSize(104) == 104)
    }
}
