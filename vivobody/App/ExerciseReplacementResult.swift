//
//  ExerciseReplacementResult.swift
//  vivobody
//
//  Explicit outcomes from replacing an exercise in an active workout draft.
//

import Foundation

enum ExerciseReplacementBlockReason: Equatable {
    case staleSession, exerciseNotFound
    case exerciseAlreadyStarted, persistenceUnavailable
}

enum ExerciseReplacementResult: Equatable {
    case replaced(newExerciseID: UUID)
    case blocked(ExerciseReplacementBlockReason)
    case saveFailed
}
