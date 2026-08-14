//
//  WidgetPreviews.swift
//  vivobodyWidgets
//
//  Xcode previews for the widget family layouts and Live Activity
//  states. Timeline providers also expose placeholders; these previews
//  make the high-value sizes quick to inspect during UI iteration.
//

import SwiftUI
import VivoKit
import WidgetKit

#Preview("Up Next Small", as: .systemSmall) {
    UpNextWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: UpNextSnapshot.placeholder)
}

#Preview("Signature Small", as: .systemSmall) {
    SignatureWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: SignatureSnapshot.placeholder)
}

#Preview("Consistency Medium", as: .systemMedium) {
    ConsistencyWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: ConsistencySnapshot.placeholder)
}

#Preview("Strength Large", as: .systemLarge) {
    StrengthWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: StrengthSnapshot.placeholder)
}

#Preview("Live Activity Rest") {
    ActiveWorkoutActivityView(
        state: WorkoutActivityAttributes.ContentState(
            exerciseName: "Barbell Bench Press",
            exerciseIndex: 0,
            setNumber: 3,
            plannedSets: 5,
            setSpec: "225 x 5",
            isResting: true,
            restEndsAt: Date().addingTimeInterval(83),
            restDuration: 120,
            totalVolume: 8420,
            totalSetsCompleted: 12,
            isExerciseComplete: false
        )
    )
    .background(Color.black)
}

#Preview("Live Activity Set") {
    ActiveWorkoutActivityView(
        state: WorkoutActivityAttributes.ContentState(
            exerciseName: "Barbell Bench Press",
            exerciseIndex: 0,
            setNumber: 3,
            plannedSets: 5,
            setSpec: "225 x 5",
            isResting: false,
            restEndsAt: nil,
            restDuration: 120,
            totalVolume: 8420,
            totalSetsCompleted: 12,
            isExerciseComplete: false
        )
    )
    .background(Color.black)
}

#Preview("Live Activity Complete") {
    ActiveWorkoutActivityView(
        state: WorkoutActivityAttributes.ContentState(
            exerciseName: "Side Plank",
            exerciseIndex: 2,
            setNumber: 3,
            plannedSets: 3,
            setSpec: "45s",
            isResting: false,
            restEndsAt: nil,
            restDuration: 120,
            totalVolume: 3414,
            totalSetsCompleted: 10,
            isExerciseComplete: true
        )
    )
    .background(Color.black)
}
