//
//  CatalogDraftValidation.swift
//  vivobody
//
//  Pure validation result for custom-exercise drafts. It owns field validity,
//  global search-term comparison, save eligibility, normalized save text, and
//  the editor's established first-invalid-field navigation order.
//

import Foundation

struct CatalogDraftValidation: Equatable {
    enum Anchor: Hashable {
        case name
        case muscles
        case movementPattern
        case direction
        case loadMode
        case aliases
    }

    let normalizedName: String
    let normalizedAliases: [String]
    let isNameEmpty: Bool
    let hasValidMuscleRoles: Bool
    let hasValidMovementPattern: Bool
    let hasValidDirection: Bool
    let hasMovementPlanes: Bool
    let hasValidLoadProfile: Bool
    let hasUniqueSearchTerms: Bool
    let canSave: Bool
    let firstInvalidAnchor: Anchor?

    init(draft: CatalogDraft, occupiedSearchTerms: [String]) {
        normalizedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedAliases = draft.parsedAliases
        isNameEmpty = normalizedName.isEmpty

        let involvement = draft.muscleInvolvement
        hasValidMuscleRoles = !involvement.isEmpty
            && involvement.primary.contains { $0.group == draft.group }
        hasValidMovementPattern = draft.mechanic != .compound || draft.pattern != nil
        hasValidDirection = !draft.requiresDirection || draft.direction != nil
        hasMovementPlanes = !draft.planes.isEmpty

        if draft.equipment.requiresNonComparableLoad {
            hasValidLoadProfile = draft.loadMode == .nonComparable
                && draft.bodyweightFraction == 0
        } else {
            switch draft.loadMode {
            case .external, .nonComparable:
                hasValidLoadProfile = draft.bodyweightFraction == 0
            case .bodyweightAdded, .assistanceSubtracted:
                hasValidLoadProfile = draft.bodyweightFraction > 0
            }
        }

        let ownTerms = [draft.name] + normalizedAliases
        let normalizedOwnTerms = ownTerms.map(\.catalogSearchTermKey)
        let occupiedKeys = Set(occupiedSearchTerms.map(\.catalogSearchTermKey))
        hasUniqueSearchTerms = normalizedOwnTerms.allSatisfy { !$0.isEmpty }
            && Set(normalizedOwnTerms).count == normalizedOwnTerms.count
            && occupiedKeys.isDisjoint(with: normalizedOwnTerms)

        // Keep the editor's established save predicate exactly: its direct
        // name check trims spaces, while search-term validation also rejects
        // every all-whitespace spelling.
        let hasSaveableName = !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
        canSave = hasSaveableName
            && hasValidMuscleRoles
            && hasValidMovementPattern
            && hasValidDirection
            && hasMovementPlanes
            && hasValidLoadProfile
            && hasUniqueSearchTerms

        if isNameEmpty {
            firstInvalidAnchor = .name
        } else if !hasValidMuscleRoles {
            firstInvalidAnchor = .muscles
        } else if !hasValidMovementPattern {
            firstInvalidAnchor = .movementPattern
        } else if !hasValidDirection {
            firstInvalidAnchor = .direction
        } else if !hasValidLoadProfile {
            firstInvalidAnchor = .loadMode
        } else if !hasUniqueSearchTerms {
            firstInvalidAnchor = .aliases
        } else {
            // Plane selection has always prevented removal of the final plane,
            // so the pre-extraction editor had no scroll anchor for this
            // defensive invalid state. Preserve that behavior in this slice.
            firstInvalidAnchor = nil
        }
    }
}
