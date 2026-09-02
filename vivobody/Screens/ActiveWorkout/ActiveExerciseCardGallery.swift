//
//  ActiveExerciseCardGallery.swift
//  vivobody
//
//  DEBUG gallery for the active exercise instrument's loaded and bodyweight
//  states. Completion uses the deliberate in-memory preview adapter.
//

#if DEBUG
    import SwiftUI

    #Preview("Exercise · active") {
        let session = WorkoutSession.sample
        return ActiveExerciseCard(
            exercise: session.orderedExercises[0],
            session: session
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    #Preview("Exercise · bodyweight") {
        let exercise = Exercise(
            name: "Pull-Up",
            group: .back,
            plannedSets: 3,
            plannedReps: 8,
            plannedWeight: 0,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        )
        let session = WorkoutSession(
            exercises: [exercise],
            bodyweightAtStart: 180
        )
        return ActiveExerciseCard(exercise: exercise, session: session)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }
#endif
