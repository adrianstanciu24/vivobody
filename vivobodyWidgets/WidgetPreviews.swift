//
//  WidgetPreviews.swift
//  vivobodyWidgets
//
//  Xcode previews for the widget family layouts and Live Activity
//  states. Timeline providers also expose placeholders; these previews
//  make the high-value sizes quick to inspect during UI iteration.
//

import VivoKit
import SwiftUI
import WidgetKit

#Preview("Up Next Small", as: .systemSmall) {
    UpNextWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: UpNextSnapshot.placeholder)
}

#Preview("Up Next Medium", as: .systemMedium) {
    UpNextWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: UpNextSnapshot.placeholder)
}

#Preview("Up Next Large", as: .systemLarge) {
    UpNextWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: UpNextSnapshot.placeholder)
}

#Preview("Up Next Lock Rect", as: .accessoryRectangular) {
    UpNextWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: UpNextSnapshot.placeholder)
}

#Preview("Up Next Lock Inline", as: .accessoryInline) {
    UpNextWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: UpNextSnapshot.placeholder)
}

#Preview("Consistency Large", as: .systemLarge) {
    ConsistencyWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: ConsistencySnapshot.placeholder)
}

#Preview("Consistency Lock Circular", as: .accessoryCircular) {
    ConsistencyWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: ConsistencySnapshot.placeholder)
}

#Preview("Consistency Lock Rect", as: .accessoryRectangular) {
    ConsistencyWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: ConsistencySnapshot.placeholder)
}

#Preview("Signature Medium", as: .systemMedium) {
    SignatureWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: SignatureSnapshot.placeholder)
}

#Preview("Signature Large", as: .systemLarge) {
    SignatureWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: SignatureSnapshot.placeholder)
}

#Preview("Signature Lock Circular", as: .accessoryCircular) {
    SignatureWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: SignatureSnapshot.placeholder)
}

#Preview("Signature Lock Inline", as: .accessoryInline) {
    SignatureWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: SignatureSnapshot.placeholder)
}

#Preview("Live Activity Rest") {
    ActiveWorkoutActivityView(
        state: WorkoutActivityAttributes.ContentState(
            exerciseName: "Bench Press",
            exerciseIndex: 0,
            setNumber: 3,
            plannedSets: 5,
            setSpec: "225 x 5",
            isResting: true,
            restEndsAt: Date().addingTimeInterval(83),
            restDuration: 120,
            totalVolume: 8_420,
            totalSetsCompleted: 12
        )
    )
    .background(Color.black)
}

#Preview("Live Activity Set") {
    ActiveWorkoutActivityView(
        state: WorkoutActivityAttributes.ContentState(
            exerciseName: "Bench Press",
            exerciseIndex: 0,
            setNumber: 3,
            plannedSets: 5,
            setSpec: "225 x 5",
            isResting: false,
            restEndsAt: nil,
            restDuration: 120,
            totalVolume: 8_420,
            totalSetsCompleted: 12
        )
    )
    .background(Color.black)
}
