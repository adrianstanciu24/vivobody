//
//  ExercisePickerPurpose.swift
//  vivobody
//
//  Caller contract for ExercisePickerSheet. Each purpose keeps its title,
//  row affordance, accessibility copy, exclusions, and permission to enter
//  long-form comparison together so workout, template, and comparison flows
//  cannot accidentally inherit one another's behavior.
//

import Foundation

enum ExercisePickerPurpose: Equatable {
    /// Opens exercise detail, where the user confirms with the existing
    /// Add to Workout control.
    case explore

    /// Opens the same add-detail flow from an in-progress workout while
    /// suppressing long-form comparison and its Pro prompt.
    case addToActiveWorkout

    /// Adds a row directly to the template draft before configuration.
    case addToTemplate

    /// Selects a comparison target directly while hiding the anchor.
    case compare(anchorID: UUID, anchorName: String)

    var navigationTitle: String {
        switch self {
        case .explore, .addToActiveWorkout, .addToTemplate: "Add Exercise"
        case .compare: "Compare With"
        }
    }

    var excludedItemID: UUID? {
        guard case let .compare(anchorID, _) = self else { return nil }
        return anchorID
    }

    var rowAccessory: ExercisePickerRowAccessory {
        switch self {
        case .explore, .addToActiveWorkout: .disclosure
        case .addToTemplate: .add
        case .compare: .compare
        }
    }

    var directPickAccessibilityHint: String {
        switch self {
        case .explore, .addToActiveWorkout: "Shows exercise details"
        case .addToTemplate: "Adds this exercise to your template"
        case let .compare(_, anchorName): "Compares this exercise with \(anchorName)"
        }
    }

    var allowsComparison: Bool {
        self != .addToActiveWorkout
    }
}

enum ExercisePickerRowAccessory {
    case disclosure
    case add
    case compare

    var systemName: String {
        switch self {
        case .disclosure: "chevron.right"
        case .add: "plus"
        case .compare: "arrow.left.arrow.right"
        }
    }
}
