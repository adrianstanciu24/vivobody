//
//  ExerciseSubstitution.swift
//  vivobody
//
//  Deterministic, read-only ranking of catalog exercises that may replace
//  another exercise. The ranker uses only authored catalog and pick-time
//  snapshot facts plus caller-provided familiarity; it performs no queries,
//  writes, or UI work. Internal scores order candidates, while callers receive
//  an honest match tier and typed preservation/tradeoff facts instead of a
//  numeric claim of exercise equivalence.
//

import Foundation

enum ExerciseSubstitution {
    private static let similarityScale = 1000

    // MARK: - Inputs

    /// Immutable facts needed to rank replacements. An active exercise uses
    /// its pick-time classification so later catalog edits cannot reinterpret
    /// the movement being replaced.
    struct Subject {
        let catalogID: String?
        let catalogItemID: UUID?
        let familyID: String?
        let name: String
        let primaryMuscles: Set<Muscle>
        let secondaryMuscles: Set<Muscle>
        let mechanic: Mechanic?
        let pattern: MovementPattern?
        let direction: PushPullDirection?
        let planes: Set<MovementPlane>
        let modality: ExerciseModality
        let trackingMode: TrackingMode
        let loadMode: ExerciseLoadMode
        let equipment: Equipment?
        let laterality: Laterality?

        init(_ item: ExerciseCatalogItem) {
            let roles = item.muscleInvolvement.roles
            catalogID = item.catalogID
            catalogItemID = item.id
            familyID = item.familyID
            name = item.name
            primaryMuscles = Self.muscles(with: .primary, in: roles)
            secondaryMuscles = Self.muscles(with: .secondary, in: roles)
            mechanic = item.mechanic
            pattern = item.pattern
            direction = item.direction
            planes = Set(item.planes)
            modality = item.modality
            trackingMode = item.trackingMode
            loadMode = item.loadMode
            equipment = item.equipment
            laterality = item.laterality
        }

        init(_ exercise: Exercise) {
            let roles = exercise.muscleInvolvement.roles
            let classification = exercise.classification
            catalogID = exercise.catalogID
            catalogItemID = exercise.catalogItemID
            familyID = exercise.familyID
            name = exercise.name
            primaryMuscles = Self.muscles(with: .primary, in: roles)
            secondaryMuscles = Self.muscles(with: .secondary, in: roles)
            mechanic = classification?.mechanic
            pattern = classification?.pattern
            direction = classification?.direction
            planes = Set(classification?.planes ?? [])
            modality = exercise.modality
            trackingMode = exercise.trackingMode
            loadMode = exercise.loadMode
            equipment = classification?.equipment
            laterality = classification?.laterality
        }

        private static func muscles(
            with role: MuscleRole,
            in roles: [Muscle: MuscleRole]
        ) -> Set<Muscle> {
            Set(roles.compactMap { muscle, authoredRole in
                authoredRole == role ? muscle : nil
            })
        }

        var performanceKind: PerformanceSemanticKind {
            modality.performanceSemanticKind(
                for: trackingMode,
                loadMode: loadMode
            )
        }

        var workingMuscles: Set<Muscle> {
            primaryMuscles.union(secondaryMuscles)
        }

        var movement: Movement? {
            pattern.map { Movement(pattern: $0, direction: direction) }
        }
    }

    /// Personal history is deliberately a tie-breaker, not part of the
    /// structural substitution score.
    struct Familiarity: Hashable {
        let sessionCount: Int
        let lastPerformedAt: Date?

        init(sessionCount: Int, lastPerformedAt: Date?) {
            self.sessionCount = max(0, sessionCount)
            self.lastPerformedAt = lastPerformedAt
        }

        fileprivate static let none = Familiarity(
            sessionCount: 0,
            lastPerformedAt: nil
        )
    }

    // MARK: - Output

    enum MatchTier: Int, Hashable {
        case partial
        case strong
        case closest
    }

    struct Movement: Hashable {
        let pattern: MovementPattern
        let direction: PushPullDirection?

        var displayName: String {
            if let direction, pattern == .push || pattern == .pull {
                return "\(direction.displayName) \(pattern.displayName)"
            }
            return pattern.displayName
        }
    }

    enum Preservation: Hashable {
        case family
        case primaryMuscles([Muscle])
        case secondaryMuscles([Muscle])
        case movement(Movement)
        case planes([MovementPlane])
        case modality(ExerciseModality)
        case tracking(TrackingMode)
        case loadMode(ExerciseLoadMode)
        case laterality(Laterality)
        case mechanic(Mechanic)
        case equipment(Equipment)
    }

    enum Change: Hashable {
        case primaryMuscles(from: [Muscle], to: [Muscle])
        case movement(from: Movement?, to: Movement?)
        case laterality(from: Laterality, to: Laterality)
        case loadMode(from: ExerciseLoadMode, to: ExerciseLoadMode)
        case planes(from: [MovementPlane], to: [MovementPlane])
        case mechanic(from: Mechanic, to: Mechanic)
        case equipment(from: Equipment, to: Equipment)
        case secondaryMuscles(from: [Muscle], to: [Muscle])
        case family
        case exerciseVariant
    }

    struct Recommendation {
        let candidate: ExerciseCatalogItem
        let tier: MatchTier
        let preserves: [Preservation]
        let changes: [Change]
    }

    // MARK: - Ranking

    static func rank(
        anchor: ExerciseCatalogItem,
        candidates: [ExerciseCatalogItem],
        availableEquipment: Set<Equipment>? = nil,
        familiarityByHistoryKey: [String: Familiarity] = [:],
        limit: Int = 5
    ) -> [Recommendation] {
        rank(
            anchor: Subject(anchor),
            candidates: candidates,
            availableEquipment: availableEquipment,
            familiarityByHistoryKey: familiarityByHistoryKey,
            limit: limit
        )
    }

    static func rank(
        anchor: Subject,
        candidates: [ExerciseCatalogItem],
        availableEquipment: Set<Equipment>? = nil,
        familiarityByHistoryKey: [String: Familiarity] = [:],
        limit: Int = 5
    ) -> [Recommendation] {
        guard limit > 0 else { return [] }

        let scored = candidates.compactMap { candidate -> Scored? in
            guard !isSameExercise(anchor, candidate) else { return nil }
            if let availableEquipment,
               !availableEquipment.contains(candidate.equipment)
            {
                return nil
            }

            let candidateSubject = Subject(candidate)
            guard anchor.modality == candidateSubject.modality,
                  anchor.trackingMode == candidateSubject.trackingMode
            else {
                return nil
            }
            guard isPlausible(anchor, candidateSubject) else { return nil }
            let recommendation = Recommendation(
                candidate: candidate,
                tier: matchTier(anchor, candidateSubject),
                preserves: preservationFacts(anchor, candidateSubject),
                changes: changeFacts(anchor, candidateSubject)
            )
            return Scored(
                recommendation: recommendation,
                structuralScore: structuralScore(anchor, candidateSubject),
                familiarity: familiarityByHistoryKey[candidate.historyKey] ?? .none
            )
        }

        return scored.sorted(by: ranksBefore).prefix(limit).map(\.recommendation)
    }

    private struct Scored {
        let recommendation: Recommendation
        let structuralScore: Int
        let familiarity: Familiarity
    }

    private static func ranksBefore(_ lhs: Scored, _ rhs: Scored) -> Bool {
        if lhs.recommendation.tier != rhs.recommendation.tier {
            return lhs.recommendation.tier.rawValue > rhs.recommendation.tier.rawValue
        }
        if lhs.structuralScore != rhs.structuralScore {
            return lhs.structuralScore > rhs.structuralScore
        }
        if lhs.recommendation.candidate.isFavorite
            != rhs.recommendation.candidate.isFavorite
        {
            return lhs.recommendation.candidate.isFavorite
        }
        if lhs.familiarity.sessionCount != rhs.familiarity.sessionCount {
            return lhs.familiarity.sessionCount > rhs.familiarity.sessionCount
        }
        if lhs.familiarity.lastPerformedAt != rhs.familiarity.lastPerformedAt {
            return (lhs.familiarity.lastPerformedAt ?? .distantPast)
                > (rhs.familiarity.lastPerformedAt ?? .distantPast)
        }
        let leftName = normalizedName(lhs.recommendation.candidate.name)
        let rightName = normalizedName(rhs.recommendation.candidate.name)
        if leftName != rightName { return leftName < rightName }
        return stableIdentity(lhs.recommendation.candidate)
            < stableIdentity(rhs.recommendation.candidate)
    }

    // MARK: - Score policy

    private enum Weight {
        static let family = 160
        static let primaryMuscles = 180
        static let secondaryMuscles = 90
        static let mechanic = 40
        static let pattern = 100
        static let direction = 80
        static let planes = 60
        static let loadMode = 40
        static let laterality = 40
    }

    private static func structuralScore(
        _ anchor: Subject,
        _ candidate: Subject
    ) -> Int {
        var score = 0
        score += Weight.family * exactFamily(anchor, candidate)
        score += Weight.primaryMuscles * dice(
            anchor.primaryMuscles,
            candidate.primaryMuscles
        )
        score += Weight.secondaryMuscles * dice(
            anchor.secondaryMuscles,
            candidate.secondaryMuscles
        )
        score += Weight.mechanic * exact(anchor.mechanic, candidate.mechanic)
        score += Weight.pattern * exact(anchor.pattern, candidate.pattern)
        score += Weight.direction * exact(anchor.direction, candidate.direction)
        score += Weight.planes * jaccard(anchor.planes, candidate.planes)
        score += Weight.loadMode * loadSimilarity(anchor.loadMode, candidate.loadMode)
        score += Weight.laterality * exact(anchor.laterality, candidate.laterality)
        return score
    }

    private static func matchTier(
        _ anchor: Subject,
        _ candidate: Subject
    ) -> MatchTier {
        let samePerformance = anchor.performanceKind == candidate.performanceKind
        if exactFamily(anchor, candidate) == similarityScale,
           anchor.primaryMuscles == candidate.primaryMuscles,
           samePerformance,
           exact(anchor.laterality, candidate.laterality) == similarityScale
        {
            return .closest
        }
        if anchor.pattern == .hang, candidate.pattern == .hang {
            return .partial
        }
        if exactFamily(anchor, candidate) == similarityScale
            || !anchor.primaryMuscles.intersection(candidate.primaryMuscles).isEmpty
            || movementsMatch(anchor, candidate)
        {
            return .strong
        }
        return .partial
    }

    private static func isPlausible(
        _ anchor: Subject,
        _ candidate: Subject
    ) -> Bool {
        if exactFamily(anchor, candidate) == similarityScale { return true }
        if !anchor.primaryMuscles.intersection(candidate.primaryMuscles).isEmpty {
            return true
        }
        let anchorKeepsPrimary = !anchor.primaryMuscles
            .intersection(candidate.workingMuscles).isEmpty
        let candidateKeepsPrimary = !candidate.primaryMuscles
            .intersection(anchor.workingMuscles).isEmpty
        if anchorKeepsPrimary, candidateKeepsPrimary { return true }
        return movementsMatch(anchor, candidate)
    }

    private static func movementsMatch(
        _ anchor: Subject,
        _ candidate: Subject
    ) -> Bool {
        guard let pattern = anchor.pattern, pattern == candidate.pattern else {
            return false
        }
        if pattern == .push || pattern == .pull {
            guard let direction = anchor.direction else { return false }
            return candidate.direction == direction
        }
        return true
    }

    private static func exactFamily(
        _ anchor: Subject,
        _ candidate: Subject
    ) -> Int {
        guard let familyID = anchor.familyID, let otherID = candidate.familyID else {
            return 0
        }
        return familyID == otherID ? similarityScale : 0
    }

    private static func exact<Value: Equatable>(
        _ lhs: Value?,
        _ rhs: Value?
    ) -> Int {
        guard let lhs, let rhs else { return 0 }
        return lhs == rhs ? similarityScale : 0
    }

    private static func exact<Value: Equatable>(_ lhs: Value, _ rhs: Value) -> Int {
        lhs == rhs ? similarityScale : 0
    }

    private static func dice<Value: Hashable>(
        _ lhs: Set<Value>,
        _ rhs: Set<Value>
    ) -> Int {
        guard !lhs.isEmpty || !rhs.isEmpty else { return 0 }
        return 2 * similarityScale * lhs.intersection(rhs).count
            / (lhs.count + rhs.count)
    }

    private static func jaccard<Value: Hashable>(
        _ lhs: Set<Value>,
        _ rhs: Set<Value>
    ) -> Int {
        let union = lhs.union(rhs)
        guard !union.isEmpty else { return 0 }
        return similarityScale * lhs.intersection(rhs).count / union.count
    }

    private static func loadSimilarity(
        _ lhs: ExerciseLoadMode,
        _ rhs: ExerciseLoadMode
    ) -> Int {
        if lhs == rhs { return similarityScale }
        return lhs.supportsLoadComparison && rhs.supportsLoadComparison
            ? similarityScale / 2
            : 0
    }

    // MARK: - Typed facts

    private static func preservationFacts(
        _ anchor: Subject,
        _ candidate: Subject
    ) -> [Preservation] {
        var facts: [Preservation] = []
        if exactFamily(anchor, candidate) == similarityScale { facts.append(.family) }

        let sharedPrimary = anchor.primaryMuscles.intersection(candidate.primaryMuscles)
        if !sharedPrimary.isEmpty {
            facts.append(.primaryMuscles(sortedMuscles(sharedPrimary)))
        }
        if let movement = anchor.movement, movement == candidate.movement {
            facts.append(.movement(movement))
        }
        let sharedSecondary = anchor.secondaryMuscles.intersection(candidate.secondaryMuscles)
        if !sharedSecondary.isEmpty {
            facts.append(.secondaryMuscles(sortedMuscles(sharedSecondary)))
        }
        if !anchor.planes.isEmpty, anchor.planes == candidate.planes {
            facts.append(.planes(sortedPlanes(anchor.planes)))
        }
        // Compatibility is a hard ranker gate, so these facts are guaranteed.
        facts.append(.modality(anchor.modality))
        facts.append(.tracking(anchor.trackingMode))
        if anchor.loadMode == candidate.loadMode { facts.append(.loadMode(anchor.loadMode)) }
        if let laterality = anchor.laterality, laterality == candidate.laterality {
            facts.append(.laterality(laterality))
        }
        if let mechanic = anchor.mechanic, mechanic == candidate.mechanic {
            facts.append(.mechanic(mechanic))
        }
        if let equipment = anchor.equipment, equipment == candidate.equipment {
            facts.append(.equipment(equipment))
        }
        return facts
    }

    private static func changeFacts(
        _ anchor: Subject,
        _ candidate: Subject
    ) -> [Change] {
        var facts: [Change] = []
        if anchor.primaryMuscles != candidate.primaryMuscles {
            facts.append(.primaryMuscles(
                from: sortedMuscles(anchor.primaryMuscles),
                to: sortedMuscles(candidate.primaryMuscles)
            ))
        }
        if anchor.movement != candidate.movement,
           anchor.movement != nil || candidate.movement != nil
        {
            facts.append(.movement(from: anchor.movement, to: candidate.movement))
        }
        if let laterality = anchor.laterality,
           let otherLaterality = candidate.laterality,
           laterality != otherLaterality
        {
            facts.append(.laterality(from: laterality, to: otherLaterality))
        }
        if anchor.loadMode != candidate.loadMode {
            facts.append(.loadMode(from: anchor.loadMode, to: candidate.loadMode))
        }
        if !anchor.planes.isEmpty,
           !candidate.planes.isEmpty,
           anchor.planes != candidate.planes
        {
            facts.append(.planes(
                from: sortedPlanes(anchor.planes),
                to: sortedPlanes(candidate.planes)
            ))
        }
        if let mechanic = anchor.mechanic,
           let otherMechanic = candidate.mechanic,
           mechanic != otherMechanic
        {
            facts.append(.mechanic(from: mechanic, to: otherMechanic))
        }
        if let equipment = anchor.equipment,
           let otherEquipment = candidate.equipment,
           equipment != otherEquipment
        {
            facts.append(.equipment(from: equipment, to: otherEquipment))
        }
        if anchor.secondaryMuscles != candidate.secondaryMuscles {
            facts.append(.secondaryMuscles(
                from: sortedMuscles(anchor.secondaryMuscles),
                to: sortedMuscles(candidate.secondaryMuscles)
            ))
        }
        if anchor.familyID != candidate.familyID,
           anchor.familyID != nil || candidate.familyID != nil
        {
            facts.append(.family)
        }
        if facts.isEmpty { facts.append(.exerciseVariant) }
        return facts
    }

    // MARK: - Stable identity

    private static func isSameExercise(
        _ anchor: Subject,
        _ candidate: ExerciseCatalogItem
    ) -> Bool {
        if let catalogID = anchor.catalogID, let otherID = candidate.catalogID {
            return catalogID == otherID
        }
        return anchor.catalogItemID == candidate.id
    }

    private static func sortedMuscles(_ muscles: Set<Muscle>) -> [Muscle] {
        muscles.sorted { $0.displayName < $1.displayName }
    }

    private static func sortedPlanes(_ planes: Set<MovementPlane>) -> [MovementPlane] {
        MovementPlane.allCases.filter(planes.contains)
    }

    private static func normalizedName(_ value: String) -> String {
        value
            .folding(
                options: [.diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
    }

    private static func stableIdentity(_ item: ExerciseCatalogItem) -> String {
        item.catalogID ?? "custom:\(item.id.uuidString.lowercased())"
    }
}
