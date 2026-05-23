//
//  ExerciseCatalog.swift
//  workapp
//
//  Persistent catalog of lifts the user picks from when building a
//  template or adding an exercise mid-workout. Stored as @Model so
//  the user can extend it with custom entries — name + muscle group
//  + sensible defaults — and edit/delete them in place.
//
//  On first launch the catalog is empty; AppRoot calls `seedIfEmpty`
//  to populate it with a starter list (see `seedItems` below). After
//  that, user adds/edits/deletes flow through SwiftData like any
//  other model. Templates and sessions don't hold references — they
//  copy `name`, `group`, `defaultWeight`, `defaultReps` at creation
//  time — so deleting a catalog item never breaks existing history.
//

import Foundation
import SwiftData

/// One entry in the picker. Carries a sensible default starting
/// weight so the user doesn't always have to scrub from zero; the
/// weight can still be adjusted per-template afterward.
@Model
final class ExerciseCatalogItem: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var muscleGroupRaw: String = MuscleGroup.chest.rawValue
    var defaultWeight: Double = 0
    var defaultReps: Int = 8

    /// Stamped at creation. Used as a sort tiebreaker after
    /// muscle-group and name, so two items with the same name (which
    /// shouldn't happen but isn't enforced) have a stable order.
    var createdAt: Date = Date()

    /// True for entries the user added themselves; false for ones
    /// the first-launch seeder inserted. Not user-visible today
    /// (edit/delete work the same for both), but kept for a potential
    /// future "Reset catalog to defaults" affordance.
    var isUserCreated: Bool = false

    var group: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .chest }
        set { muscleGroupRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        group: MuscleGroup,
        defaultWeight: Double,
        defaultReps: Int = 8,
        isUserCreated: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.muscleGroupRaw = group.rawValue
        self.defaultWeight = defaultWeight
        self.defaultReps = defaultReps
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
    }
}

// MARK: - Seeding

extension ExerciseCatalogItem {
    /// Starter catalog inserted on first launch. Order inside each
    /// group is compound-first; muscle-group order follows the
    /// MuscleGroup enum's `allCases` declaration order.
    static let seedItems: [(name: String, group: MuscleGroup, weight: Double, reps: Int)] = [
        // Chest
        ("Bench Press",            .chest,     135, 8),
        ("Incline Bench Press",    .chest,     115, 8),
        ("Dumbbell Press",         .chest,     40,  8),
        ("Cable Fly",              .chest,     30,  12),
        ("Push-Up",                .chest,     0,   15),

        // Back
        ("Deadlift",               .back,      225, 5),
        ("Barbell Row",            .back,      115, 8),
        ("Pull-Up",                .back,      0,   8),
        ("Lat Pulldown",           .back,      100, 10),
        ("Seated Cable Row",       .back,      100, 10),

        // Shoulders
        ("Overhead Press",         .shoulders, 95,  8),
        ("Dumbbell Shoulder Press",.shoulders, 30,  8),
        ("Lateral Raise",          .shoulders, 15,  12),
        ("Face Pull",              .shoulders, 40,  15),

        // Legs
        ("Back Squat",             .legs,      185, 8),
        ("Front Squat",            .legs,      135, 8),
        ("Romanian Deadlift",      .legs,      155, 8),
        ("Leg Press",              .legs,      270, 10),
        ("Walking Lunge",          .legs,      30,  12),
        ("Leg Curl",               .legs,      80,  12),

        // Arms
        ("Barbell Curl",           .arms,      65,  10),
        ("Hammer Curl",            .arms,      25,  10),
        ("Tricep Pushdown",        .arms,      50,  12),
        ("Skullcrusher",           .arms,      60,  10),

        // Core
        ("Plank",                  .core,      0,   60),
        ("Hanging Leg Raise",      .core,      0,   12),
        ("Cable Crunch",           .core,      50,  15),
    ]

    /// Insert the starter catalog when the store is empty. Idempotent
    /// — bails immediately if any catalog item already exists. Called
    /// from AppRoot.onAppear so the picker is never empty even on a
    /// brand-new install.
    static func seedIfEmpty(in context: ModelContext) {
        let descriptor = FetchDescriptor<ExerciseCatalogItem>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        // Stagger createdAt slightly so the seed order is preserved
        // when we tie-break by date — otherwise every item shares the
        // same timestamp and falls back to arbitrary FetchDescriptor
        // ordering.
        let base = Date()
        for (i, seed) in seedItems.enumerated() {
            let item = ExerciseCatalogItem(
                name: seed.name,
                group: seed.group,
                defaultWeight: seed.weight,
                defaultReps: seed.reps,
                isUserCreated: false,
                createdAt: base.addingTimeInterval(Double(i) * 0.001)
            )
            context.insert(item)
        }
        try? context.save()
    }
}

// MARK: - Grouping helper

extension Array where Element == ExerciseCatalogItem {
    /// Group catalog items by muscle group for the sectioned picker
    /// UI. Group order follows the MuscleGroup enum; items inside
    /// each group are sorted by createdAt (preserves seed order;
    /// user-added items come after the seeded ones in their group).
    var groupedByMuscle: [(group: MuscleGroup, items: [ExerciseCatalogItem])] {
        MuscleGroup.allCases.compactMap { group in
            let items = self
                .filter { $0.group == group }
                .sorted { $0.createdAt < $1.createdAt }
            return items.isEmpty ? nil : (group: group, items: items)
        }
    }
}
