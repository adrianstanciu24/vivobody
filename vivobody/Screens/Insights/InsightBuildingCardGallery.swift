//
//  InsightBuildingCardGallery.swift
//  vivobody
//
//  Debug-only gallery for the shared Insights qualification card.
//  Keeps zero-, partial-, and large-type states visible while tuning
//  the signal lamp, segmented evidence rail, and copy hierarchy.
//

#if DEBUG
import VivoKit
import SwiftUI

#Preview("Insight signal · empty") {
    ZStack {
        Color.black.ignoresSafeArea()
        InsightBuildingCard(
            title: "Your load range starts here",
            detail: "Complete working sets to begin the rolling seven-day line.",
            progress: 0,
            progressLabel: "0/28 DAYS · 0/3 ACTIVE WEEKS",
            accessibilityProgress: "0 of 28 days and 0 of 3 active weeks"
        )
        .padding(Space.gutter)
    }
    .preferredColorScheme(.dark)
}

#Preview("Insight signal · partial") {
    ZStack {
        Color.black.ignoresSafeArea()
        InsightBuildingCard(
            title: "Composition taking shape",
            detail: "Complete four more strength sets in this four-week window for a clearer allocation.",
            progress: 2.0 / 6.0,
            progressLabel: "2/6 STRENGTH SETS",
            accessibilityProgress: "2 of 6 strength sets"
        )
        .padding(Space.gutter)
    }
    .preferredColorScheme(.dark)
}

#Preview("Insight signal · accessibility") {
    ZStack {
        Color.black.ignoresSafeArea()
        InsightBuildingCard(
            title: "Your training rhythm starts here",
            detail: "Workout days and weekly set volume will collect here as you train.",
            progress: 0,
            progressLabel: "0/4 RECENT WORKOUTS",
            accessibilityProgress: "0 of 4 recent workouts"
        )
        .padding(Space.gutter)
    }
    .environment(\.dynamicTypeSize, .accessibility2)
    .preferredColorScheme(.dark)
}
#endif
