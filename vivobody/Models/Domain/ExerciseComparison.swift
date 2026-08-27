//
//  ExerciseComparison.swift
//  vivobody
//
//  Pure, catalog-only comparison of two exercises. The model reads
//  only the authored catalog fields — muscle roles, classification,
//  and modality/tracking/load semantics — so it works on day one
//  with zero logged history and stays testable without a SwiftData
//  store. The comparison screen composes these
//  values; nothing here performs queries or writes.
//
//  Training-volume projections apply the same modality/tracking gate
//  as SetStimulus before role credit. Anatomy remains a separate,
//  per-exercise projection: callers can show only volume-bearing roles
//  or every authored role, including stabilizers, without collapsing
//  two exercises into one stronger-side map.
//

import Foundation

nonisolated struct ExerciseComparison {
    /// The exercise the user came from — the "what I already do" side.
    /// Rendered in the accent tint.
    let anchor: ExerciseCatalogItem
    /// The exercise being weighed against it. Rendered in the
    /// comparison tint.
    let other: ExerciseCatalogItem

    enum Side: Hashable {
        case anchor
        case other
    }

    /// The two honest readings of authored muscle roles. Training
    /// volume applies the hard-set gate and omits zero-credit roles;
    /// all involvement describes anatomy and retains stabilizers.
    enum AnatomyScope: Hashable {
        case trainingVolume
        case allInvolvement
    }

    /// Whether either exercise can assign hard-set credit to at least
    /// one authored muscle under its modality and tracking contract.
    enum TrainingVolumeAvailability: Hashable {
        case both
        case anchorOnly
        case otherOnly
        case neither
    }

    /// Factual stimulus overlap. Shared collections answer where both
    /// exercises assign nonzero hard-set credit; emphasized collections
    /// answer where one side assigns more credit. Those collections can
    /// overlap by design: a muscle may work in both exercises while one
    /// exercise emphasizes it more strongly.
    struct TrainingOverlap: Hashable {
        let sharedMuscles: [Muscle]
        let anchorEmphasizedMuscles: [Muscle]
        let otherEmphasizedMuscles: [Muscle]
        let sharedRegions: [MuscleGroup]
        let anchorEmphasizedRegions: [MuscleGroup]
        let otherEmphasizedRegions: [MuscleGroup]
    }

    // MARK: - Muscle deltas

    /// How one muscle's role differs between the two exercises.
    enum MuscleChange: Hashable {
        /// Same categorical role in both exercises.
        case shared(MuscleRole)
        /// Both exercises involve the muscle, at different roles.
        case roleChange(anchor: MuscleRole, other: MuscleRole)
        case anchorOnly(MuscleRole)
        case otherOnly(MuscleRole)
    }

    /// One muscle's standing across both exercises. `nil` role means
    /// the exercise does not involve the muscle at all.
    struct MuscleDelta: Hashable {
        let muscle: Muscle
        let anchorRole: MuscleRole?
        let otherRole: MuscleRole?
        /// Role credit after the exercise's modality/tracking gate.
        /// A primary power muscle therefore remains anatomically
        /// primary while correctly receiving zero training volume.
        let anchorVolumeCredit: Double
        let otherVolumeCredit: Double

        var change: MuscleChange {
            switch (anchorRole, otherRole) {
            case let (.some(anchorRole), .some(otherRole)):
                anchorRole == otherRole
                    ? .shared(anchorRole)
                    : .roleChange(anchor: anchorRole, other: otherRole)
            case let (.some(anchorRole), .none):
                .anchorOnly(anchorRole)
            case let (.none, .some(otherRole)):
                .otherOnly(otherRole)
            case (.none, .none):
                // Unreachable through `ExerciseComparison.muscleDeltas`,
                // which only emits muscles at least one side claims.
                .shared(.stabilizer)
            }
        }

        /// Sorts the role list by the stronger authored role without
        /// merging either side's anatomy presentation.
        var strongestRoleIntensity: Double {
            max(
                anchorRole?.anatomyIntensity ?? 0,
                otherRole?.anatomyIntensity ?? 0
            )
        }

        /// True when the muscle appears anatomically but earns no
        /// hard-set volume in either exercise. This includes
        /// stabilizers and every role in a modality/tracking contract
        /// that SetStimulus excludes.
        var earnsVolumeInNeither: Bool {
            anchorVolumeCredit == 0 && otherVolumeCredit == 0
        }
    }

    /// Every muscle either exercise involves, strongest-role first,
    /// alphabetical within a strength tier for a stable reading order.
    var muscleDeltas: [MuscleDelta] {
        let anchorRoles = anchor.muscleInvolvement.roles
        let otherRoles = other.muscleInvolvement.roles
        let anchorCredits = effectiveVolumeCredits(for: anchor)
        let otherCredits = effectiveVolumeCredits(for: other)
        let muscles = Set(anchorRoles.keys).union(otherRoles.keys)
        return muscles
            .map { muscle in
                MuscleDelta(
                    muscle: muscle,
                    anchorRole: anchorRoles[muscle],
                    otherRole: otherRoles[muscle],
                    anchorVolumeCredit: anchorCredits[muscle] ?? 0,
                    otherVolumeCredit: otherCredits[muscle] ?? 0
                )
            }
            .sorted { lhs, rhs in
                if lhs.strongestRoleIntensity != rhs.strongestRoleIntensity {
                    return lhs.strongestRoleIntensity > rhs.strongestRoleIntensity
                }
                return lhs.muscle.displayName < rhs.muscle.displayName
            }
    }

    var roleChanges: [MuscleDelta] {
        muscleDeltas.filter {
            if case .roleChange = $0.change { return true }
            return false
        }
    }

    var anchorOnlyDeltas: [MuscleDelta] {
        muscleDeltas.filter {
            if case .anchorOnly = $0.change { return true }
            return false
        }
    }

    var otherOnlyDeltas: [MuscleDelta] {
        muscleDeltas.filter {
            if case .otherOnly = $0.change { return true }
            return false
        }
    }

    var sharedDeltas: [MuscleDelta] {
        muscleDeltas.filter {
            if case .shared = $0.change { return true }
            return false
        }
    }

    /// Muscles that receive no effective hard-set credit on either
    /// side, including primary/secondary roles in gated modalities.
    var nonVolumeDeltas: [MuscleDelta] {
        muscleDeltas.filter(\.earnsVolumeInNeither)
    }

    /// The anatomical subset that is genuinely no stronger than a
    /// stabilizer on either side. Kept distinct from `nonVolumeDeltas`
    /// so a primary power role is never mislabeled as stabilization.
    var stabilizerOnlyDeltas: [MuscleDelta] {
        nonVolumeDeltas.filter {
            ($0.anchorRole?.volumeCredit ?? 0) == 0
                && ($0.otherRole?.volumeCredit ?? 0) == 0
        }
    }

    var trainingVolumeAvailability: TrainingVolumeAvailability {
        let anchorHasVolume = !effectiveVolumeCredits(for: anchor).isEmpty
        let otherHasVolume = !effectiveVolumeCredits(for: other).isEmpty
        return switch (anchorHasVolume, otherHasVolume) {
        case (true, true): .both
        case (true, false): .anchorOnly
        case (false, true): .otherOnly
        case (false, false): .neither
        }
    }

    var trainingOverlap: TrainingOverlap {
        let deltas = muscleDeltas
        let sharedMuscles = deltas.filter {
            $0.anchorVolumeCredit > 0 && $0.otherVolumeCredit > 0
        }.map(\.muscle)
        let anchorEmphasizedMuscles = deltas.filter {
            $0.anchorVolumeCredit > $0.otherVolumeCredit
        }.map(\.muscle)
        let otherEmphasizedMuscles = deltas.filter {
            $0.otherVolumeCredit > $0.anchorVolumeCredit
        }.map(\.muscle)

        var anchorCreditByRegion: [MuscleGroup: Double] = [:]
        var otherCreditByRegion: [MuscleGroup: Double] = [:]
        for delta in deltas {
            let region = delta.muscle.group
            anchorCreditByRegion[region] = max(
                anchorCreditByRegion[region] ?? 0,
                delta.anchorVolumeCredit
            )
            otherCreditByRegion[region] = max(
                otherCreditByRegion[region] ?? 0,
                delta.otherVolumeCredit
            )
        }

        let sharedRegions = MuscleGroup.allCases.filter {
            (anchorCreditByRegion[$0] ?? 0) > 0
                && (otherCreditByRegion[$0] ?? 0) > 0
        }
        let anchorEmphasizedRegions = MuscleGroup.allCases.filter {
            (anchorCreditByRegion[$0] ?? 0) > (otherCreditByRegion[$0] ?? 0)
        }
        let otherEmphasizedRegions = MuscleGroup.allCases.filter {
            (otherCreditByRegion[$0] ?? 0) > (anchorCreditByRegion[$0] ?? 0)
        }

        return TrainingOverlap(
            sharedMuscles: sharedMuscles,
            anchorEmphasizedMuscles: anchorEmphasizedMuscles,
            otherEmphasizedMuscles: otherEmphasizedMuscles,
            sharedRegions: sharedRegions,
            anchorEmphasizedRegions: anchorEmphasizedRegions,
            otherEmphasizedRegions: otherEmphasizedRegions
        )
    }

    /// One exercise at a time, with no stronger-side merging. The
    /// training-volume scope is empty for power and mismatched strength
    /// modality/tracking pairs.
    func anatomyChannels(
        for side: Side,
        scope: AnatomyScope
    ) -> [String: MuscleMapChannels] {
        let item = item(for: side)
        let credits = effectiveVolumeCredits(for: item)
        let tint: MuscleMapTint = side == .anchor ? .accent : .compare
        var result: [String: MuscleMapChannels] = [:]

        for contribution in item.muscleInvolvement.contributions
            where contribution.muscle.isVisualized
        {
            let intensity: Double = switch scope {
            case .trainingVolume:
                credits[contribution.muscle] ?? 0
            case .allInvolvement:
                contribution.role.anatomyIntensity
            }
            guard intensity > 0 else { continue }

            let channels = MuscleMapChannels(intensity: intensity, tint: tint)
            for node in contribution.muscle.nodeNames {
                result[node] = channels
            }
        }
        return result
    }

    /// Authored regions omitted from the mesh for one side and scope.
    /// The same inclusion rule as `anatomyChannels` keeps the figure's
    /// textual fallback accurate.
    func unvisualizedMuscles(
        for side: Side,
        scope: AnatomyScope
    ) -> [Muscle] {
        let item = item(for: side)
        let credits = effectiveVolumeCredits(for: item)
        return item.muscleInvolvement.contributions.compactMap { contribution in
            guard !contribution.muscle.isVisualized else { return nil }
            switch scope {
            case .trainingVolume:
                return (credits[contribution.muscle] ?? 0) > 0
                    ? contribution.muscle
                    : nil
            case .allInvolvement:
                return contribution.muscle
            }
        }
    }

    // MARK: - Classification rows

    /// One labeled fact with both exercises' values. `differs` lets
    /// the screen highlight exactly the rows that separate the two
    /// movements instead of decorating everything.
    struct FactRow: Hashable {
        let label: String
        let anchorValue: String
        let otherValue: String

        var differs: Bool {
            anchorValue != otherValue
        }
    }

    /// How each movement is built: pattern, mechanic, planes,
    /// laterality, equipment. Rows with nothing to say on either side
    /// hide themselves, mirroring MovementClassificationCard.
    var movementRows: [FactRow] {
        var rows: [FactRow] = []
        if anchor.movementLabel != nil || other.movementLabel != nil {
            rows.append(FactRow(
                label: "Pattern",
                anchorValue: Self.patternLabel(for: anchor),
                otherValue: Self.patternLabel(for: other)
            ))
        }
        if anchor.mechanic == .isolation || other.mechanic == .isolation,
           anchor.trainingRole != nil || other.trainingRole != nil
        {
            rows.append(FactRow(
                label: "Training",
                anchorValue: anchor.trainingRole?.displayName ?? "Not authored",
                otherValue: other.trainingRole?.displayName ?? "Not authored"
            ))
        }
        rows.append(FactRow(
            label: "Mechanic",
            anchorValue: anchor.mechanic.displayName,
            otherValue: other.mechanic.displayName
        ))
        rows.append(FactRow(
            label: "Planes",
            anchorValue: Self.planesLabel(anchor.planes),
            otherValue: Self.planesLabel(other.planes)
        ))
        if anchor.laterality != other.laterality
            || anchor.laterality == .unilateral
            || other.laterality == .unilateral
        {
            rows.append(FactRow(
                label: "Laterality",
                anchorValue: anchor.laterality.displayName,
                otherValue: other.laterality.displayName
            ))
        }
        rows.append(FactRow(
            label: "Equipment",
            anchorValue: anchor.equipment.displayName,
            otherValue: other.equipment.displayName
        ))
        return rows
    }

    /// Explains the authored direction dimension without conflating it
    /// with anatomical planes. Direction is available only to push/pull
    /// patterns, so a note hides when neither side has one.
    var directionNote: String? {
        switch (anchor.direction, other.direction) {
        case let (.some(anchorDirection), .some(otherDirection)):
            let comparison = if anchorDirection == otherDirection {
                "Both exercises are authored as \(anchorDirection.rawValue)"
            } else {
                "\(anchor.name) is authored as \(anchorDirection.rawValue), while \(other.name) is authored as \(otherDirection.rawValue)"
            }
            return "\(comparison) based on the primary resistance or travel direction. Anatomical planes describe motion components and are a separate classification."
        case let (.some(direction), .none):
            return "\(anchor.name) is authored as \(direction.rawValue) based on the primary resistance or travel direction. Anatomical planes describe motion components and are a separate classification."
        case let (.none, .some(direction)):
            return "\(other.name) is authored as \(direction.rawValue) based on the primary resistance or travel direction. Anatomical planes describe motion components and are a separate classification."
        case (.none, .none):
            return nil
        }
    }

    /// How each exercise is measured and progressed: exercise type,
    /// tracking unit, load semantics, and record eligibility. This is
    /// the "which one is easier to track progressively?" block.
    var trackingRows: [FactRow] {
        [
            FactRow(
                label: "Type",
                anchorValue: anchor.modality.categoryDisplayName,
                otherValue: other.modality.categoryDisplayName
            ),
            FactRow(
                label: "Measured",
                anchorValue: anchor.modality.measureDisplayName,
                otherValue: other.modality.measureDisplayName
            ),
            FactRow(
                label: "Load",
                anchorValue: anchor.loadMode.displayName,
                otherValue: other.loadMode.displayName
            ),
            FactRow(
                label: "Records",
                anchorValue: Self.recordLabel(anchor.performanceSemanticKind),
                otherValue: Self.recordLabel(other.performanceSemanticKind)
            ),
        ]
    }

    /// One-sentence progression note, emitted only when the two
    /// exercises genuinely differ in how progression can be tracked.
    /// Factual, never a recommendation.
    var progressionNote: String? {
        let anchorKind = anchor.performanceSemanticKind
        let otherKind = other.performanceSemanticKind
        if anchorKind.comparesLoad != otherKind.comparesLoad {
            let loadable = anchorKind.comparesLoad ? anchor.name : other.name
            let otherName = anchorKind.comparesLoad ? other.name : anchor.name
            return "Only \(loadable) has a comparable load axis; \(otherName) has no honest load-progression record."
        }
        if anchorKind.supportsRecord != otherKind.supportsRecord {
            let ranked = anchorKind.supportsRecord ? anchor.name : other.name
            return "Only \(ranked) earns performance records."
        }
        return nil
    }

    // MARK: - Training volume

    private func item(for side: Side) -> ExerciseCatalogItem {
        side == .anchor ? anchor : other
    }

    /// Mirrors SetStimulus's exact exercise-level gate. Role credit is
    /// meaningful only for repeated dynamic strength and timed
    /// isometric strength; broad modality eligibility alone is not
    /// sufficient for a mismatched tracking mode.
    private static func supportsTrainingVolume(
        modality: ExerciseModality,
        trackingMode: TrackingMode
    ) -> Bool {
        switch (modality, trackingMode) {
        case (.dynamicStrength, .reps), (.isometricStrength, .duration):
            true
        default:
            false
        }
    }

    private func effectiveVolumeCredits(
        for item: ExerciseCatalogItem
    ) -> [Muscle: Double] {
        guard Self.supportsTrainingVolume(
            modality: item.modality,
            trackingMode: item.trackingMode
        ) else { return [:] }
        return item.muscleInvolvement.volumeCredits.filter { $0.value > 0 }
    }

    // MARK: - Labels

    private static func planesLabel(_ planes: [MovementPlane]) -> String {
        let label = planes.map(\.displayName).joined(separator: " · ")
        return label.isEmpty ? "Not authored" : label
    }

    /// Isolation movements intentionally have no compound movement
    /// pattern. Keep that distinct from a compound exercise whose
    /// classification is genuinely missing.
    private static func patternLabel(for item: ExerciseCatalogItem) -> String {
        if let movementLabel = item.movementLabel { return movementLabel }
        return item.mechanic == .isolation ? "Not applicable" : "Not authored"
    }

    /// Record eligibility in the user's terms: what a best performance
    /// is made of, or that the movement intentionally stays unranked.
    static func recordLabel(_ kind: PerformanceSemanticKind) -> String {
        switch kind {
        case .dynamicLoadAndReps, .powerLoadAndReps:
            "Load × reps"
        case .isometricLoadAndDuration:
            "Load × time"
        case .isometricDuration:
            "Time only"
        case .unrankedReps, .unrankedDuration:
            "No records"
        }
    }
}
