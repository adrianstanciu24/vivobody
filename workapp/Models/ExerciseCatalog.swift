//
//  ExerciseCatalog.swift
//  workapp
//
//  Persistent catalog of lifts the user picks from when building a
//  template or adding an exercise mid-workout. Stored as @Model so
//  the user can extend it with custom entries — name + muscle group
//  + equipment + mechanic + pattern + aliases + sensible defaults —
//  and edit/delete them in place.
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

// MARK: - Equipment

/// Primary piece of gear the lift uses. Drives the equipment filter
/// chip strip at the top of the picker and shows as a small badge on
/// each row. Stored as the raw value on `ExerciseCatalogItem` so
/// the enum can evolve without migrations.
enum Equipment: String, Hashable, CaseIterable {
    case barbell
    case dumbbell
    case cable
    case machine
    case bodyweight
    case kettlebell
    case band
    case other

    var displayName: String {
        switch self {
        case .barbell:    return "Barbell"
        case .dumbbell:   return "Dumbbell"
        case .cable:      return "Cable"
        case .machine:    return "Machine"
        case .bodyweight: return "Bodyweight"
        case .kettlebell: return "Kettlebell"
        case .band:       return "Band"
        case .other:      return "Other"
        }
    }

    /// SF Symbol used in the picker's equipment filter chips and in
    /// the small badge on each row. Chosen for legibility at 11pt.
    var symbol: String {
        switch self {
        case .barbell:    return "dumbbell.fill"
        case .dumbbell:   return "dumbbell"
        case .cable:      return "cable.connector"
        case .machine:    return "gearshape.fill"
        case .bodyweight: return "figure.strengthtraining.functional"
        case .kettlebell: return "scalemass.fill"
        case .band:       return "wave.3.right"
        case .other:      return "questionmark.circle"
        }
    }
}

// MARK: - Mechanic

/// Compound (multi-joint) vs. isolation (single-joint). Affects
/// PR-detection sensitivity and which patterns make sense — only
/// compound lifts carry a `MovementPattern`.
enum Mechanic: String, Hashable, CaseIterable {
    case compound
    case isolation

    var displayName: String {
        switch self {
        case .compound:  return "Compound"
        case .isolation: return "Isolation"
        }
    }
}

// MARK: - Movement pattern

/// The primary motor pattern of the lift. Optional — only compound
/// lifts have a meaningful pattern; isolation work is left nil.
/// Useful for programming-aware features (push/pull balance,
/// session structure suggestions) we'll layer in later.
enum MovementPattern: String, Hashable, CaseIterable {
    case push     // bench, OHP, dips
    case pull     // rows, pulldowns
    case squat    // back squat, front squat, leg press
    case hinge    // deadlift, RDL, good morning
    case lunge    // split squat, step-up, walking lunge
    case carry    // farmer's carry, suitcase, yoke
    case core     // planks, leg raises, anti-rotation

    var displayName: String {
        switch self {
        case .push:  return "Push"
        case .pull:  return "Pull"
        case .squat: return "Squat"
        case .hinge: return "Hinge"
        case .lunge: return "Lunge"
        case .carry: return "Carry"
        case .core:  return "Core"
        }
    }
}

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

    /// Primary equipment used. Defaults to barbell on a new entry
    /// (matches the most common case for a serious lifter) but can
    /// be edited per-exercise. Stored as raw value so the Equipment
    /// enum can evolve without breaking the schema.
    var equipmentRaw: String = Equipment.barbell.rawValue

    /// Compound vs. isolation. Defaults to compound — a brand-new
    /// "Bench Press"-style entry is more likely compound than not.
    var mechanicRaw: String = Mechanic.compound.rawValue

    /// Movement pattern (push/pull/squat/hinge/lunge/carry/core).
    /// Optional because isolation work doesn't have a meaningful
    /// pattern. Nil-when-isolation is a soft rule, not enforced in
    /// the store — the editor just hides the pattern selector when
    /// mechanic is isolation.
    var patternRaw: String? = nil

    /// Alternate names / abbreviations the user might type to find
    /// this exercise. e.g. "BP", "Flat Bench" → Bench Press. Searched
    /// alongside `name` in the picker. Empty by default.
    var aliases: [String] = []

    /// Stamped at creation. Used as a sort tiebreaker after
    /// muscle-group and name, so two items with the same name (which
    /// shouldn't happen but isn't enforced) have a stable order.
    var createdAt: Date = Date()

    /// True for entries the user added themselves; false for ones
    /// the first-launch seeder inserted. Not user-visible today
    /// (edit/delete work the same for both), but kept for a potential
    /// future "Reset catalog to defaults" affordance.
    var isUserCreated: Bool = false

    // MARK: - Computed accessors

    var group: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .chest }
        set { muscleGroupRaw = newValue.rawValue }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .barbell }
        set { equipmentRaw = newValue.rawValue }
    }

    var mechanic: Mechanic {
        get { Mechanic(rawValue: mechanicRaw) ?? .compound }
        set {
            mechanicRaw = newValue.rawValue
            // Clearing the pattern when the user switches an exercise
            // to isolation keeps the data honest. The editor enforces
            // this in the UI but mutating directly should follow the
            // same rule.
            if newValue == .isolation {
                patternRaw = nil
            }
        }
    }

    var pattern: MovementPattern? {
        get { patternRaw.flatMap(MovementPattern.init(rawValue:)) }
        set { patternRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        group: MuscleGroup,
        defaultWeight: Double,
        defaultReps: Int = 8,
        equipment: Equipment = .barbell,
        mechanic: Mechanic = .compound,
        pattern: MovementPattern? = nil,
        aliases: [String] = [],
        isUserCreated: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.muscleGroupRaw = group.rawValue
        self.defaultWeight = defaultWeight
        self.defaultReps = defaultReps
        self.equipmentRaw = equipment.rawValue
        self.mechanicRaw = mechanic.rawValue
        self.patternRaw = (mechanic == .isolation) ? nil : pattern?.rawValue
        self.aliases = aliases
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
    }
}

// MARK: - Seeding

extension ExerciseCatalogItem {
    /// One entry in the starter catalog. Promoted to a struct (was a
    /// tuple) once the field count crossed five — keeps the seed
    /// list readable and gives us a stable spot to attach helpers
    /// like the `Equipment`/`Mechanic`/`MovementPattern` defaults.
    struct Seed {
        let name: String
        let group: MuscleGroup
        let weight: Double
        let reps: Int
        let equipment: Equipment
        let mechanic: Mechanic
        let pattern: MovementPattern?
        let aliases: [String]

        init(
            _ name: String,
            _ group: MuscleGroup,
            _ weight: Double,
            _ reps: Int,
            _ equipment: Equipment,
            _ mechanic: Mechanic = .compound,
            _ pattern: MovementPattern? = nil,
            _ aliases: [String] = []
        ) {
            self.name = name
            self.group = group
            self.weight = weight
            self.reps = reps
            self.equipment = equipment
            self.mechanic = mechanic
            self.pattern = pattern
            self.aliases = aliases
        }
    }

    /// Starter catalog inserted on first launch. Curated to be a
    /// realistic starting library for an intermediate lifter —
    /// covers the major barbell lifts and their common variations,
    /// the staple dumbbell movements, the cable/machine accessories
    /// most gyms have, and a useful core selection. Each entry is
    /// tagged with equipment + mechanic + movement pattern + a few
    /// search aliases.
    ///
    /// Order inside each muscle group: compound first (heaviest /
    /// most fundamental), then variations, then isolation. Group
    /// order follows `MuscleGroup.allCases` declaration order.
    static let seedItems: [Seed] = [
        // MARK: Chest
        .init("Bench Press",                .chest, 135, 8, .barbell,    .compound,   .push,  ["BP", "Flat Bench", "Barbell Bench"]),
        .init("Incline Bench Press",        .chest, 115, 8, .barbell,    .compound,   .push,  ["Incline Bench", "Incline BP"]),
        .init("Decline Bench Press",        .chest, 135, 8, .barbell,    .compound,   .push,  ["Decline Bench"]),
        .init("Close-Grip Bench Press",     .chest, 115, 8, .barbell,    .compound,   .push,  ["CGBP", "Close Grip"]),
        .init("Paused Bench Press",         .chest, 115, 5, .barbell,    .compound,   .push,  ["Pause Bench"]),
        .init("Dumbbell Bench Press",       .chest,  50, 8, .dumbbell,   .compound,   .push,  ["DB Bench", "DB Press"]),
        .init("Incline Dumbbell Press",     .chest,  40, 8, .dumbbell,   .compound,   .push,  ["Incline DB Press"]),
        .init("Dumbbell Fly",               .chest,  25, 12, .dumbbell,  .isolation,  nil,    ["DB Fly", "Pec Fly"]),
        .init("Cable Fly",                  .chest,  30, 12, .cable,     .isolation,  nil,    ["Cable Crossover"]),
        .init("Pec Deck",                   .chest,  60, 12, .machine,   .isolation,  nil,    ["Machine Fly"]),
        .init("Push-Up",                    .chest,   0, 15, .bodyweight,.compound,   .push,  ["Pushup"]),
        .init("Dip",                        .chest,   0, 8, .bodyweight, .compound,   .push,  ["Chest Dip", "Tricep Dip"]),

        // MARK: Back
        .init("Deadlift",                   .back, 225, 5, .barbell,     .compound,   .hinge, ["Conventional Deadlift", "DL"]),
        .init("Sumo Deadlift",              .back, 225, 5, .barbell,     .compound,   .hinge, ["Sumo DL"]),
        .init("Trap Bar Deadlift",          .back, 225, 5, .barbell,     .compound,   .hinge, ["Hex Bar", "Trap Bar"]),
        .init("Block Pull",                 .back, 245, 5, .barbell,     .compound,   .hinge, ["Block Deadlift"]),
        .init("Rack Pull",                  .back, 275, 5, .barbell,     .compound,   .hinge, []),
        .init("Barbell Row",                .back, 115, 8, .barbell,     .compound,   .pull,  ["Bent-Over Row", "BB Row"]),
        .init("Pendlay Row",                .back, 135, 5, .barbell,     .compound,   .pull,  []),
        .init("T-Bar Row",                  .back,  90, 8, .machine,     .compound,   .pull,  []),
        .init("Chest-Supported Row",        .back,  70, 10, .machine,    .compound,   .pull,  ["Seal Row"]),
        .init("Pull-Up",                    .back,   0, 8, .bodyweight,  .compound,   .pull,  ["Pullup"]),
        .init("Chin-Up",                    .back,   0, 8, .bodyweight,  .compound,   .pull,  ["Chinup"]),
        .init("Neutral-Grip Pull-Up",       .back,   0, 8, .bodyweight,  .compound,   .pull,  ["Neutral Pull-Up"]),
        .init("Weighted Pull-Up",           .back,  25, 6, .bodyweight,  .compound,   .pull,  []),
        .init("Lat Pulldown",               .back, 100, 10, .cable,      .compound,   .pull,  ["Pulldown"]),
        .init("Wide-Grip Lat Pulldown",     .back, 100, 10, .cable,      .compound,   .pull,  []),
        .init("Seated Cable Row",           .back, 100, 10, .cable,      .compound,   .pull,  ["Cable Row"]),
        .init("Single-Arm Dumbbell Row",    .back,  60, 10, .dumbbell,   .compound,   .pull,  ["DB Row", "One-Arm Row"]),
        .init("Straight-Arm Pulldown",      .back,  40, 12, .cable,      .isolation,  nil,    []),
        .init("Shrug",                      .back, 135, 10, .barbell,    .isolation,  nil,    ["Barbell Shrug"]),

        // MARK: Shoulders
        .init("Overhead Press",             .shoulders,  95, 8, .barbell,   .compound, .push, ["OHP", "Standing Press", "Strict Press"]),
        .init("Seated Barbell Press",       .shoulders, 105, 8, .barbell,   .compound, .push, []),
        .init("Push Press",                 .shoulders, 115, 5, .barbell,   .compound, .push, []),
        .init("Dumbbell Shoulder Press",    .shoulders,  30, 8, .dumbbell,  .compound, .push, ["DB Shoulder Press", "DB OHP"]),
        .init("Arnold Press",               .shoulders,  25, 10, .dumbbell, .compound, .push, []),
        .init("Landmine Press",             .shoulders,  45, 10, .barbell,  .compound, .push, []),
        .init("Lateral Raise",              .shoulders,  15, 12, .dumbbell, .isolation, nil, ["Side Raise"]),
        .init("Cable Lateral Raise",        .shoulders,  10, 15, .cable,    .isolation, nil, []),
        .init("Front Raise",                .shoulders,  15, 12, .dumbbell, .isolation, nil, []),
        .init("Rear Delt Fly",              .shoulders,  15, 15, .dumbbell, .isolation, nil, ["Reverse Fly"]),
        .init("Face Pull",                  .shoulders,  40, 15, .cable,    .isolation, nil, []),
        .init("Upright Row",                .shoulders,  65, 10, .barbell,  .compound, .pull, []),

        // MARK: Legs
        .init("Back Squat",                 .legs, 185, 8, .barbell,     .compound,   .squat, ["Squat", "High-Bar Squat", "Low-Bar Squat"]),
        .init("Front Squat",                .legs, 135, 8, .barbell,     .compound,   .squat, []),
        .init("Pause Squat",                .legs, 135, 5, .barbell,     .compound,   .squat, []),
        .init("Box Squat",                  .legs, 155, 5, .barbell,     .compound,   .squat, []),
        .init("Goblet Squat",               .legs,  50, 10, .dumbbell,   .compound,   .squat, []),
        .init("Bulgarian Split Squat",      .legs,  35, 10, .dumbbell,   .compound,   .lunge, ["BSS", "Split Squat"]),
        .init("Walking Lunge",              .legs,  30, 12, .dumbbell,   .compound,   .lunge, ["Lunge"]),
        .init("Reverse Lunge",              .legs,  30, 10, .dumbbell,   .compound,   .lunge, []),
        .init("Step-Up",                    .legs,  25, 10, .dumbbell,   .compound,   .lunge, []),
        .init("Leg Press",                  .legs, 270, 10, .machine,    .compound,   .squat, []),
        .init("Hack Squat",                 .legs, 180, 10, .machine,    .compound,   .squat, []),
        .init("Romanian Deadlift",          .legs, 155, 8, .barbell,     .compound,   .hinge, ["RDL"]),
        .init("Stiff-Leg Deadlift",         .legs, 135, 8, .barbell,     .compound,   .hinge, ["SLDL"]),
        .init("Good Morning",               .legs,  95, 10, .barbell,    .compound,   .hinge, []),
        .init("Hip Thrust",                 .legs, 185, 10, .barbell,    .compound,   .hinge, ["Barbell Hip Thrust"]),
        .init("Glute Bridge",               .legs, 135, 12, .barbell,    .compound,   .hinge, []),
        .init("Leg Curl",                   .legs,  80, 12, .machine,    .isolation,  nil,    ["Hamstring Curl"]),
        .init("Leg Extension",              .legs,  80, 12, .machine,    .isolation,  nil,    ["Quad Extension"]),
        .init("Standing Calf Raise",        .legs, 135, 12, .machine,    .isolation,  nil,    ["Calf Raise"]),
        .init("Seated Calf Raise",          .legs,  90, 15, .machine,    .isolation,  nil,    []),
        .init("Hip Adduction",               .legs,  80, 15, .machine,    .isolation,  nil,    []),
        .init("Hip Abduction",              .legs,  80, 15, .machine,    .isolation,  nil,    []),

        // MARK: Arms
        .init("Barbell Curl",               .arms,  65, 10, .barbell,    .isolation,  nil,    ["BB Curl", "Bicep Curl"]),
        .init("EZ-Bar Curl",                .arms,  55, 10, .barbell,    .isolation,  nil,    []),
        .init("Dumbbell Curl",              .arms,  25, 10, .dumbbell,   .isolation,  nil,    ["DB Curl"]),
        .init("Hammer Curl",                .arms,  25, 10, .dumbbell,   .isolation,  nil,    []),
        .init("Incline Dumbbell Curl",      .arms,  20, 10, .dumbbell,   .isolation,  nil,    []),
        .init("Preacher Curl",              .arms,  40, 10, .barbell,    .isolation,  nil,    []),
        .init("Cable Curl",                 .arms,  40, 12, .cable,      .isolation,  nil,    []),
        .init("Concentration Curl",         .arms,  20, 12, .dumbbell,   .isolation,  nil,    []),
        .init("Tricep Pushdown",            .arms,  50, 12, .cable,      .isolation,  nil,    ["Pushdown"]),
        .init("Rope Pushdown",              .arms,  40, 12, .cable,      .isolation,  nil,    []),
        .init("Skullcrusher",               .arms,  60, 10, .barbell,    .isolation,  nil,    ["Lying Tricep Extension"]),
        .init("Overhead Tricep Extension",  .arms,  40, 12, .dumbbell,   .isolation,  nil,    ["French Press"]),
        .init("Dumbbell Tricep Kickback",   .arms,  15, 12, .dumbbell,   .isolation,  nil,    ["Kickback"]),
        .init("Close-Grip Push-Up",         .arms,   0, 12, .bodyweight, .compound,   .push,  []),
        .init("Wrist Curl",                 .arms,  25, 15, .barbell,    .isolation,  nil,    ["Forearm Curl"]),
        .init("Reverse Wrist Curl",         .arms,  15, 15, .barbell,    .isolation,  nil,    []),

        // MARK: Core
        .init("Plank",                      .core,   0, 60, .bodyweight, .isolation,  .core,  []),
        .init("Side Plank",                 .core,   0, 45, .bodyweight, .isolation,  .core,  []),
        .init("Hanging Leg Raise",          .core,   0, 12, .bodyweight, .isolation,  .core,  ["Leg Raise"]),
        .init("Hanging Knee Raise",         .core,   0, 15, .bodyweight, .isolation,  .core,  ["Knee Raise"]),
        .init("Cable Crunch",               .core,  50, 15, .cable,      .isolation,  .core,  []),
        .init("Ab Wheel Rollout",           .core,   0, 10, .other,      .isolation,  .core,  ["Ab Roller"]),
        .init("Russian Twist",              .core,  20, 20, .dumbbell,   .isolation,  .core,  []),
        .init("Pallof Press",               .core,  20, 12, .cable,      .isolation,  .core,  []),
        .init("Dead Bug",                   .core,   0, 12, .bodyweight, .isolation,  .core,  []),
        .init("Bird Dog",                   .core,   0, 12, .bodyweight, .isolation,  .core,  []),
        .init("Farmer's Carry",             .core,  70, 1, .dumbbell,    .compound,   .carry, ["Farmer Walk", "Suitcase Carry"]),
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
                equipment: seed.equipment,
                mechanic: seed.mechanic,
                pattern: seed.pattern,
                aliases: seed.aliases,
                isUserCreated: false,
                createdAt: base.addingTimeInterval(Double(i) * 0.001)
            )
            context.insert(item)
        }
        try? context.save()
    }

    /// Wipe the entire catalog and re-seed from the curated list.
    /// User-created entries are removed alongside any edits to seeded
    /// items — the mental model is "factory reset." Templates and
    /// workout history are unaffected because they copy values at
    /// pick-time and never reference catalog items directly.
    ///
    /// Triggered from Me → Preferences → Reset Exercise Catalog,
    /// behind a destructive-styled confirmation alert.
    static func resetToDefaults(in context: ModelContext) {
        let descriptor = FetchDescriptor<ExerciseCatalogItem>()
        if let existing = try? context.fetch(descriptor) {
            for item in existing {
                context.delete(item)
            }
        }
        try? context.save()
        seedIfEmpty(in: context)
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
