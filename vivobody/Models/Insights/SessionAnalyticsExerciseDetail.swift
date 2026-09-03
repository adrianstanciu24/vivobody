//
//  SessionAnalyticsExerciseDetail.swift
//  vivobody
//
//  Bridges Exercise Detail to one coherent published core generation without
//  traversing archived workout relationships during SwiftUI body evaluation.
//

extension SessionAnalytics {
    /// Last complete coherent generation, including the authoritative initial
    /// empty payload. A pending replacement never blanks the visible detail.
    func exerciseDetailCachedReports() -> ExerciseDetailReports {
        coreReports.exerciseDetail
    }
}
