//
//  ExerciseSubstitutionCopy.swift
//  vivobody
//
//  Deterministic user-facing wording for typed exercise-substitution facts.
//  Copy stays derived from the ranker's preservation and change values so the
//  app never describes a tradeoff that the ranking model did not observe.
//

import Foundation

extension ExerciseSubstitution.MatchTier {
    var copy: String {
        switch self {
        case .closest: "Closest match"
        case .strong: "Good match"
        case .partial: "Partial match"
        }
    }
}

extension ExerciseSubstitution.Preservation {
    var copy: String {
        switch self {
        case .family:
            "the same exercise family"
        case let .primaryMuscles(muscles):
            "primary emphasis on \(ExerciseSubstitutionCopy.muscleList(muscles))"
        case let .secondaryMuscles(muscles):
            "secondary roles for \(ExerciseSubstitutionCopy.muscleList(muscles))"
        case let .movement(movement):
            "the \(movement.displayName.lowercased()) pattern"
        case let .planes(planes):
            "\(ExerciseSubstitutionCopy.planeList(planes)) movement"
        case let .modality(modality):
            "the \(modality.displayName.lowercased()) exercise type"
        case let .tracking(trackingMode):
            "\(ExerciseSubstitutionCopy.trackingLabel(trackingMode)) tracking"
        case let .loadMode(loadMode):
            ExerciseSubstitutionCopy.loadPreservation(loadMode)
        case let .laterality(laterality):
            "\(laterality.displayName.lowercased()) execution"
        case let .mechanic(mechanic):
            "\(mechanic.displayName.lowercased()) mechanics"
        case let .equipment(equipment):
            "the \(equipment.displayName.lowercased()) setup"
        }
    }

    /// Short card copy for the live-workout glance surface. The complete
    /// sentence remains available through `copy` for VoiceOver and other
    /// explanatory contexts.
    var glanceCopy: String {
        switch self {
        case .family:
            "Same exercise family"
        case let .primaryMuscles(muscles):
            "Primary · \(ExerciseSubstitutionCopy.muscleList(muscles))"
        case let .secondaryMuscles(muscles):
            "Secondary · \(ExerciseSubstitutionCopy.muscleList(muscles))"
        case let .movement(movement):
            "\(movement.displayName) pattern"
        case let .planes(planes):
            "\(ExerciseSubstitutionCopy.planeList(planes)) movement"
        case let .modality(modality):
            "\(modality.displayName) type"
        case let .tracking(trackingMode):
            "\(ExerciseSubstitutionCopy.trackingLabel(trackingMode)) tracking"
        case let .loadMode(loadMode):
            ExerciseSubstitutionCopy.loadPreservation(loadMode)
        case let .laterality(laterality):
            "\(laterality.displayName) execution"
        case let .mechanic(mechanic):
            "\(mechanic.displayName) mechanics"
        case let .equipment(equipment):
            "\(equipment.displayName) setup"
        }
    }
}

extension ExerciseSubstitution.Change {
    var copy: String {
        switch self {
        case let .primaryMuscles(from, to):
            "primary emphasis from \(ExerciseSubstitutionCopy.muscleList(from)) to \(ExerciseSubstitutionCopy.muscleList(to))"
        case let .movement(from, to):
            "movement from \(ExerciseSubstitutionCopy.movementLabel(from)) to \(ExerciseSubstitutionCopy.movementLabel(to))"
        case let .laterality(from, to):
            "laterality from \(from.displayName.lowercased()) to \(to.displayName.lowercased())"
        case let .loadMode(from, to):
            "load semantics from \(from.displayName.lowercased()) to \(to.displayName.lowercased())"
        case let .planes(from, to):
            "movement planes from \(ExerciseSubstitutionCopy.planeList(from)) to \(ExerciseSubstitutionCopy.planeList(to))"
        case let .mechanic(from, to):
            "mechanics from \(from.displayName.lowercased()) to \(to.displayName.lowercased())"
        case let .equipment(from, to):
            "equipment from \(from.displayName.lowercased()) to \(to.displayName.lowercased())"
        case let .secondaryMuscles(from, to):
            "secondary roles from \(ExerciseSubstitutionCopy.muscleList(from)) to \(ExerciseSubstitutionCopy.muscleList(to))"
        case .family:
            "exercise family"
        case .exerciseVariant:
            "the exact exercise variant"
        }
    }

    /// Compact visual delta. Arrow notation turns verbose from/to prose into
    /// a comparison that can be understood without reading a sentence.
    var glanceCopy: String {
        switch self {
        case let .primaryMuscles(from, to):
            "Primary · \(ExerciseSubstitutionCopy.muscleList(from)) → \(ExerciseSubstitutionCopy.muscleList(to))"
        case let .movement(from, to):
            "\(ExerciseSubstitutionCopy.movementLabel(from)) → \(ExerciseSubstitutionCopy.movementLabel(to))"
        case let .laterality(from, to):
            "\(from.displayName) → \(to.displayName)"
        case let .loadMode(from, to):
            "\(from.displayName) → \(to.displayName) load"
        case let .planes(from, to):
            "\(ExerciseSubstitutionCopy.planeList(from)) → \(ExerciseSubstitutionCopy.planeList(to))"
        case let .mechanic(from, to):
            "\(from.displayName) → \(to.displayName)"
        case let .equipment(from, to):
            "\(from.displayName) → \(to.displayName)"
        case let .secondaryMuscles(from, to):
            "Secondary · \(ExerciseSubstitutionCopy.muscleList(from)) → \(ExerciseSubstitutionCopy.muscleList(to))"
        case .family:
            "Exercise family"
        case .exerciseVariant:
            "Exact exercise variant"
        }
    }
}

extension ExerciseSubstitution.Recommendation {
    /// Compact deterministic explanation. The full typed fact arrays remain
    /// available when a caller needs a different visual hierarchy.
    var explanation: String {
        var sentences = ["\(tier.copy)."]
        let visiblePreservations = preserves.prefix(3).map(\.copy)
        if !visiblePreservations.isEmpty {
            sentences.append(
                "Preserves \(ExerciseSubstitutionCopy.englishList(visiblePreservations))."
            )
        }
        let visibleChanges = changes.prefix(2).map(\.copy)
        if visibleChanges.isEmpty {
            sentences.append("No scored catalog differences are authored.")
        } else {
            sentences.append(
                "Changes \(ExerciseSubstitutionCopy.englishList(visibleChanges))."
            )
        }
        return sentences.joined(separator: " ")
    }
}

private enum ExerciseSubstitutionCopy {
    static func muscleList(_ muscles: [Muscle]) -> String {
        guard !muscles.isEmpty else { return "no authored muscle" }
        return englishList(muscles.map(\.displayName))
    }

    static func planeList(_ planes: [MovementPlane]) -> String {
        guard !planes.isEmpty else { return "no authored plane" }
        return englishList(planes.map { $0.displayName.lowercased() })
    }

    static func movementLabel(
        _ movement: ExerciseSubstitution.Movement?
    ) -> String {
        movement?.displayName.lowercased() ?? "no compound pattern"
    }

    static func trackingLabel(_ trackingMode: TrackingMode) -> String {
        switch trackingMode {
        case .reps: "rep"
        case .duration: "time"
        }
    }

    static func loadPreservation(_ loadMode: ExerciseLoadMode) -> String {
        switch loadMode {
        case .external: "comparable external-load progression"
        case .bodyweightAdded: "bodyweight-plus-load progression"
        case .assistanceSubtracted: "assistance-subtracted progression"
        case .nonComparable: "non-comparable resistance semantics"
        }
    }

    static func englishList(_ values: [String]) -> String {
        switch values.count {
        case 0: ""
        case 1: values[0]
        case 2: "\(values[0]) and \(values[1])"
        default: "\(values.dropLast().joined(separator: ", ")), and \(values.last!)"
        }
    }
}
