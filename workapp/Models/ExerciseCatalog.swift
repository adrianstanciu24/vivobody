//
//  ExerciseCatalog.swift
//  workapp
//
//  Static catalog of common lifts the user picks from when building
//  a template. Keeping a fixed list (rather than free-text entry)
//  means exercise names stay consistent across templates and
//  archived sessions — which is what PR detection relies on (it
//  matches by name). A future "custom exercise" path can land on top
//  of this without breaking what's already here.
//

import Foundation

/// One entry in the picker. Carries a sensible default starting
/// weight so the user doesn't always have to scrub from zero; the
/// weight can still be adjusted per-template afterward.
struct ExerciseCatalogItem: Identifiable, Hashable {
    let id: String          // stable across launches; used as identifier
    let name: String
    let group: MuscleGroup
    let defaultWeight: Double
    let defaultReps: Int

    init(
        name: String,
        group: MuscleGroup,
        defaultWeight: Double,
        defaultReps: Int = 8
    ) {
        // Stable id derived from name — same exercise across builds
        // gets the same id even if order changes.
        self.id = name
        self.name = name
        self.group = group
        self.defaultWeight = defaultWeight
        self.defaultReps = defaultReps
    }
}

extension ExerciseCatalogItem {
    /// The full catalog, grouped logically but stored flat. Order
    /// inside a group is "most common / compound first."
    static let all: [ExerciseCatalogItem] = [
        // Chest
        Self(name: "Bench Press",          group: .chest,     defaultWeight: 135),
        Self(name: "Incline Bench Press",  group: .chest,     defaultWeight: 115),
        Self(name: "Dumbbell Press",       group: .chest,     defaultWeight: 40),
        Self(name: "Cable Fly",            group: .chest,     defaultWeight: 30, defaultReps: 12),
        Self(name: "Push-Up",              group: .chest,     defaultWeight: 0,  defaultReps: 15),

        // Back
        Self(name: "Deadlift",             group: .back,      defaultWeight: 225, defaultReps: 5),
        Self(name: "Barbell Row",          group: .back,      defaultWeight: 115),
        Self(name: "Pull-Up",              group: .back,      defaultWeight: 0,  defaultReps: 8),
        Self(name: "Lat Pulldown",         group: .back,      defaultWeight: 100, defaultReps: 10),
        Self(name: "Seated Cable Row",     group: .back,      defaultWeight: 100, defaultReps: 10),

        // Shoulders
        Self(name: "Overhead Press",       group: .shoulders, defaultWeight: 95),
        Self(name: "Dumbbell Shoulder Press", group: .shoulders, defaultWeight: 30),
        Self(name: "Lateral Raise",        group: .shoulders, defaultWeight: 15, defaultReps: 12),
        Self(name: "Face Pull",            group: .shoulders, defaultWeight: 40, defaultReps: 15),

        // Legs
        Self(name: "Back Squat",           group: .legs,      defaultWeight: 185),
        Self(name: "Front Squat",          group: .legs,      defaultWeight: 135),
        Self(name: "Romanian Deadlift",    group: .legs,      defaultWeight: 155),
        Self(name: "Leg Press",            group: .legs,      defaultWeight: 270, defaultReps: 10),
        Self(name: "Walking Lunge",        group: .legs,      defaultWeight: 30, defaultReps: 12),
        Self(name: "Leg Curl",             group: .legs,      defaultWeight: 80, defaultReps: 12),

        // Arms
        Self(name: "Barbell Curl",         group: .arms,      defaultWeight: 65, defaultReps: 10),
        Self(name: "Hammer Curl",          group: .arms,      defaultWeight: 25, defaultReps: 10),
        Self(name: "Tricep Pushdown",      group: .arms,      defaultWeight: 50, defaultReps: 12),
        Self(name: "Skullcrusher",         group: .arms,      defaultWeight: 60, defaultReps: 10),

        // Core
        Self(name: "Plank",                group: .core,      defaultWeight: 0,  defaultReps: 60),
        Self(name: "Hanging Leg Raise",    group: .core,      defaultWeight: 0,  defaultReps: 12),
        Self(name: "Cable Crunch",         group: .core,      defaultWeight: 50, defaultReps: 15),
    ]

    /// Catalog grouped by muscle group, for a sectioned picker UI.
    static var grouped: [(group: MuscleGroup, items: [ExerciseCatalogItem])] {
        MuscleGroup.allCases.compactMap { group in
            let items = all.filter { $0.group == group }
            return items.isEmpty ? nil : (group: group, items: items)
        }
    }
}
