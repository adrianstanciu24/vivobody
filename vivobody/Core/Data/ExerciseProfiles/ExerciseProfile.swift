import Foundation

struct ExerciseProfile: Decodable {
    let exercise: ExerciseProfileExercise
    let targets: ExerciseProfileTargets
    let demands: ExerciseProfileDemands
    let biases: ExerciseProfileBiases
    let kinematics: ExerciseProfileKinematics
    let topMuscles: [ExerciseProfileTopMuscle]

    enum CodingKeys: String, CodingKey {
        case exercise, targets, demands, biases, kinematics
        case topMuscles = "top_muscles"
    }
}

// MARK: - Exercise

struct ExerciseProfileExercise: Decodable {
    let id: String
    let displayName: String
    let description: String
    let motionFamily: String
    let isBilateral: Bool
    let repDurationSec: Double
    let movementTags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case description
        case motionFamily = "motion_family"
        case isBilateral = "bilateral"
        case repDurationSec = "rep_duration_sec"
        case movementTags = "movement_tags"
    }
}

// MARK: - Targets

struct ExerciseProfileTargets: Decodable {
    let primary: [ExerciseProfileTarget]
    let secondary: [ExerciseProfileTarget]
    let stabilizers: [ExerciseProfileTarget]
    let all: [ExerciseProfileTarget]
}

struct ExerciseProfileTarget: Decodable {
    let id: String
    let label: String
    let share: Double
    let role: String
    let relativeRankScore10: Int

    enum CodingKeys: String, CodingKey {
        case id, label, share, role
        case relativeRankScore10 = "relative_rank_score_10"
    }
}

// MARK: - Demands

struct ExerciseProfileDemands: Decodable {
    let jointActions: [ExerciseProfileJointAction]
    let jointStress: [ExerciseProfileJointStress]
    let stability: ExerciseProfileStability
    let tempoSensitivity: ExerciseProfileTempoSensitivity
    let phaseBreakdown: [ExerciseProfilePhase]

    enum CodingKeys: String, CodingKey {
        case jointActions = "joint_actions"
        case jointStress = "joint_stress"
        case stability
        case tempoSensitivity = "tempo_sensitivity"
        case phaseBreakdown = "phase_breakdown"
    }
}

struct ExerciseProfileJointAction: Decodable {
    let action: String
    let label: String
    let share: Double
    let dominantGroup: String
    let absoluteLevelScore10: Int

    enum CodingKeys: String, CodingKey {
        case action, label, share
        case dominantGroup = "dominant_group"
        case absoluteLevelScore10 = "absolute_level_score_10"
    }
}

struct ExerciseProfileJointStress: Decodable {
    let joint: String
    let label: String
    let share: Double
    let level: String
    let absoluteLevelScore10: Int
    let summary: String

    enum CodingKeys: String, CodingKey {
        case joint, label, share, level, summary
        case absoluteLevelScore10 = "absolute_level_score_10"
    }
}

struct ExerciseProfileStability: Decodable {
    let level: String
    let score: Double
    let absoluteLevelScore10: Int
    let summary: String

    enum CodingKeys: String, CodingKey {
        case level, score, summary
        case absoluteLevelScore10 = "absolute_level_score_10"
    }
}

struct ExerciseProfileTempoSensitivity: Decodable {
    let level: String
    let score: Double
    let absoluteLevelScore10: Int
    let summary: String
    let slowerTempoBias: [String]
    let fasterTempoBias: [String]

    enum CodingKeys: String, CodingKey {
        case level, score, summary
        case absoluteLevelScore10 = "absolute_level_score_10"
        case slowerTempoBias = "slower_tempo_bias"
        case fasterTempoBias = "faster_tempo_bias"
    }
}

struct ExerciseProfilePhase: Decodable {
    let phase: String
    let label: String
    let primaryTargets: [ExerciseProfilePhaseTarget]
    let mainJointActions: [ExerciseProfilePhaseAction]

    enum CodingKeys: String, CodingKey {
        case phase, label
        case primaryTargets = "primary_targets"
        case mainJointActions = "main_joint_actions"
    }
}

struct ExerciseProfilePhaseTarget: Decodable {
    let id: String
    let label: String
}

struct ExerciseProfilePhaseAction: Decodable {
    let action: String
    let label: String
    let dominantGroup: ExerciseProfilePhaseTarget

    enum CodingKeys: String, CodingKey {
        case action, label
        case dominantGroup = "dominant_group"
    }
}

// MARK: - Biases

struct ExerciseProfileBiases: Decodable {
    let kneeVsHip: ExerciseProfileKneeVsHip
    let stretch: ExerciseProfileStretch

    enum CodingKeys: String, CodingKey {
        case kneeVsHip = "knee_vs_hip"
        case stretch
    }
}

struct ExerciseProfileKneeVsHip: Decodable {
    let bias: String
    let kneeShare: Double
    let hipShare: Double
    let absoluteLevelScore10: Int
    let summary: String

    enum CodingKeys: String, CodingKey {
        case bias, summary
        case kneeShare = "knee_share"
        case hipShare = "hip_share"
        case absoluteLevelScore10 = "absolute_level_score_10"
    }
}

struct ExerciseProfileStretch: Decodable {
    let level: String
    let peakRepPosition: String
    let topGroups: [ExerciseProfileStretchGroup]
    let absoluteLevelScore10: Int
    let summary: String

    enum CodingKeys: String, CodingKey {
        case level, summary
        case peakRepPosition = "peak_rep_position"
        case topGroups = "top_groups"
        case absoluteLevelScore10 = "absolute_level_score_10"
    }
}

struct ExerciseProfileStretchGroup: Decodable {
    let id: String
    let label: String
    let share: Double
}

// MARK: - Kinematics

struct ExerciseProfileKinematics: Decodable {
    let rangeOfMotion: [ExerciseProfileROM]
    let phaseWindows: [ExerciseProfilePhaseWindow]

    enum CodingKeys: String, CodingKey {
        case rangeOfMotion = "range_of_motion"
        case phaseWindows = "phase_windows"
    }
}

struct ExerciseProfileROM: Decodable {
    let joint: String
    let label: String
    let minDeg: Double
    let maxDeg: Double
    let rangeDeg: Double

    enum CodingKeys: String, CodingKey {
        case joint, label
        case minDeg = "min_deg"
        case maxDeg = "max_deg"
        case rangeDeg = "range_deg"
    }
}

struct ExerciseProfilePhaseWindow: Decodable {
    let phase: String
    let start: Double
    let end: Double
    let intensity: Double
}

// MARK: - Top Muscles

struct ExerciseProfileTopMuscle: Decodable {
    let muscle: String
    let group: String
    let groupLabel: String
    let estimatedRelativeLoad: Double
    let loadBucket: String
    let phaseBias: String
    let displayScore10: Int
    let relativeRankScore10: Int

    enum CodingKeys: String, CodingKey {
        case muscle, group
        case groupLabel = "group_label"
        case estimatedRelativeLoad = "estimated_relative_load"
        case loadBucket = "load_bucket"
        case phaseBias = "phase_bias"
        case displayScore10 = "display_score_10"
        case relativeRankScore10 = "relative_rank_score_10"
    }
}

// MARK: - Catalog Item

struct ExerciseCatalogItem: Identifiable, Hashable {
    let id: String
    let displayName: String
    let description: String
    let motionFamily: String
    let isBilateral: Bool
    let apiPath: String
    let muscleGroup: MuscleGroup
    let category: ExerciseCategory
    let primaryTag: String
    let secondaryTags: String

    var tags: String {
        guard !secondaryTags.isEmpty else { return primaryTag }
        guard !primaryTag.isEmpty else { return secondaryTags }
        return "\(primaryTag) · \(secondaryTags)"
    }
}
