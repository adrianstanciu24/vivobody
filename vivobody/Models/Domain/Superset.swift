//
//  Superset.swift
//  vivobody
//
//  Superset grouping + choreography. A superset is adjacent exercises
//  sharing a `supersetID`; sets zip into rounds (round i = set i of
//  each member). Two layers live here:
//
//    • SupersetGrouping — pure structural edits shared by Exercise and
//      TemplateExercise via the SupersetMember protocol: link/unlink
//      the seam between neighbors, dissolve singletons, derive the
//      lifter-standard "A1"/"A2" tags and the contiguous index runs
//      the page dots render as one capsule.
//
//    • WorkoutSession choreography — after a set lands on a grouped
//      exercise, decide the next step: hand off to the partner (the
//      walk between stations replaces rest), rest between rounds, or
//      declare the group finished. Greedy on completed-set counts so
//      it stays honest even when the user completes sets out of order.
//

import Foundation

// MARK: - Membership

/// Shared surface for the two model types that can join a superset.
/// Grouping edits only need the ID slot and stable order.
nonisolated protocol SupersetMember: AnyObject {
    var supersetID: UUID? { get set }
    var sortOrder: Int { get }
}

extension Exercise: nonisolated SupersetMember {}
extension TemplateExercise: nonisolated SupersetMember {}

// MARK: - Grouping edits

nonisolated enum SupersetGrouping {
    // MARK: ID-array core
    //
    // The algorithms operate on plain `[UUID?]` so both the @Model
    // types (via the SupersetMember wrappers below) and value-type
    // editing buffers (ExerciseDraft) share one implementation.

    /// Contiguous runs of positions sharing a superset ID, as index
    /// ranges. Only genuine groups (two or more).
    static func linkedRuns(inIDs ids: [UUID?]) -> [ClosedRange<Int>] {
        var runs: [ClosedRange<Int>] = []
        var i = 0
        while i < ids.count {
            guard let id = ids[i] else {
                i += 1
                continue
            }
            var j = i
            while j + 1 < ids.count, ids[j + 1] == id {
                j += 1
            }
            if j > i { runs.append(i...j) }
            i = j + 1
        }
        return runs
    }

    /// Lifter-standard "A1"-style tag for one position: group letter
    /// by order of appearance, member position within the group. Nil
    /// outside any genuine group.
    static func tag(at index: Int, inIDs ids: [UUID?]) -> String? {
        for (groupIndex, run) in linkedRuns(inIDs: ids).enumerated() {
            for (memberIndex, i) in run.enumerated() where i == index {
                return "\(letter(for: groupIndex))\(memberIndex + 1)"
            }
        }
        return nil
    }

    /// The group letter ("A", "B", …) of the linked run containing
    /// `index`. Nil when the position sits outside every group.
    static func groupLetter(at index: Int, inIDs ids: [UUID?]) -> String? {
        for (groupIndex, run) in linkedRuns(inIDs: ids).enumerated()
        where run.contains(index) {
            return letter(for: groupIndex)
        }
        return nil
    }

    private static func letter(for index: Int) -> String {
        // A…Z, then AA/BB… for the pathological 27th group.
        let scalar = UnicodeScalar(UInt8(65 + index % 26))
        return String(repeating: String(scalar), count: index / 26 + 1)
    }

    /// True when positions `index` and `index + 1` belong to the same
    /// group — i.e. the seam between them is linked.
    static func isSeamLinked(at index: Int, inIDs ids: [UUID?]) -> Bool {
        guard ids.indices.contains(index),
              ids.indices.contains(index + 1),
              let id = ids[index]
        else { return false }
        return ids[index + 1] == id
    }

    /// Link the seam between positions `index` and `index + 1`.
    /// Joining an existing group extends it; linking two groups merges
    /// them. No-op when already linked.
    static func linkingSeam(at index: Int, inIDs ids: [UUID?]) -> [UUID?] {
        guard ids.indices.contains(index),
              ids.indices.contains(index + 1)
        else { return ids }
        var ids = ids
        switch (ids[index], ids[index + 1]) {
        case (nil, nil):
            let id = UUID()
            ids[index] = id
            ids[index + 1] = id
        case (let id?, nil):
            ids[index + 1] = id
        case (nil, let id?):
            ids[index] = id
        case (let aID?, let bID?) where aID != bID:
            for k in ids.indices where ids[k] == bID {
                ids[k] = aID
            }
        default:
            break
        }
        return normalizing(ids)
    }

    /// Break the seam between positions `index` and `index + 1`,
    /// splitting their group in two. Halves that end up with a single
    /// member dissolve back to straight sets.
    static func unlinkingSeam(at index: Int, inIDs ids: [UUID?]) -> [UUID?] {
        guard isSeamLinked(at: index, inIDs: ids), let id = ids[index] else {
            return ids
        }
        var ids = ids
        let split = UUID()
        for k in (index + 1)..<ids.count where ids[k] == id {
            ids[k] = split
        }
        return normalizing(ids)
    }

    /// Re-establish the invariants — groups are contiguous runs of two
    /// or more. Non-contiguous reuses of an ID (after a delete or
    /// reorder) split into fresh groups; singleton runs dissolve.
    static func normalizing(_ ids: [UUID?]) -> [UUID?] {
        var ids = ids
        var usedIDs: Set<UUID> = []
        var i = 0
        while i < ids.count {
            guard let id = ids[i] else {
                i += 1
                continue
            }
            var j = i
            while j + 1 < ids.count, ids[j + 1] == id {
                j += 1
            }
            if j == i {
                ids[i] = nil
            } else if usedIDs.contains(id) {
                let fresh = UUID()
                for k in i...j { ids[k] = fresh }
                usedIDs.insert(fresh)
            } else {
                usedIDs.insert(id)
            }
            i = j + 1
        }
        return ids
    }

    // MARK: Model-object wrappers

    /// Contiguous runs of members sharing a superset ID, as index
    /// ranges into `ordered`. Only genuine groups (two or more).
    static func linkedRuns(in ordered: [any SupersetMember]) -> [ClosedRange<Int>] {
        linkedRuns(inIDs: ordered.map(\.supersetID))
    }

    /// "A1"-style tag for one member. Nil for members outside any
    /// genuine group.
    static func tag(
        for member: any SupersetMember,
        in ordered: [any SupersetMember]
    ) -> String? {
        guard let index = ordered.firstIndex(where: { $0 === member }) else {
            return nil
        }
        return tag(at: index, inIDs: ordered.map(\.supersetID))
    }

    /// True when `ordered[index]` and `ordered[index + 1]` belong to
    /// the same group.
    static func isSeamLinked(at index: Int, in ordered: [any SupersetMember]) -> Bool {
        isSeamLinked(at: index, inIDs: ordered.map(\.supersetID))
    }

    /// Link the seam between `ordered[index]` and `ordered[index + 1]`.
    static func linkSeam(at index: Int, in ordered: [any SupersetMember]) {
        apply(linkingSeam(at: index, inIDs: ordered.map(\.supersetID)), to: ordered)
    }

    /// Break the seam between `ordered[index]` and `ordered[index + 1]`.
    static func unlinkSeam(at index: Int, in ordered: [any SupersetMember]) {
        apply(unlinkingSeam(at: index, inIDs: ordered.map(\.supersetID)), to: ordered)
    }

    /// Pull one member out of its group; a group left with a single
    /// member dissolves.
    static func unlink(_ member: any SupersetMember, in ordered: [any SupersetMember]) {
        member.supersetID = nil
        normalize(ordered)
    }

    /// Re-establish the invariants over live model objects.
    static func normalize(_ ordered: [any SupersetMember]) {
        apply(normalizing(ordered.map(\.supersetID)), to: ordered)
    }

    private static func apply(_ ids: [UUID?], to ordered: [any SupersetMember]) {
        for (member, id) in zip(ordered, ids) where member.supersetID != id {
            member.supersetID = id
        }
    }
}

// MARK: - Choreography

/// The next step after a set lands on a superset member.
nonisolated enum SupersetStep {
    /// Hand off to this partner for the same round — no rest; the walk
    /// between stations is the transition.
    case partner(Exercise)
    /// Every member has logged this round — rest, then resume here.
    case roundComplete(resume: Exercise)
    /// Nothing left to do anywhere in the group.
    case groupComplete
}

/// What `completeActiveSet` decided, so the view layer can move the
/// pager to match without re-deriving (and possibly disagreeing with)
/// the model's rest decision.
nonisolated enum SetCompletionOutcome {
    /// No pending set existed; nothing changed.
    case none
    /// Straight sets with more to do — a rest interval started.
    case rest
    /// The exercise (or its whole superset group) is finished — no
    /// rest; the view advances to the next card.
    case exerciseComplete
    /// Superset mid-round — no rest; the view carries the user to the
    /// partner's card.
    case supersetPartner(Exercise)
    /// Superset round finished — a rest interval started; the view
    /// repositions the pager onto `resume` behind the overlay.
    case supersetRoundRest(resume: Exercise)
}

extension WorkoutSession {
    /// Ordered members of the exercise's superset group. Empty when
    /// the exercise is ungrouped or its group has no partner (a
    /// singleton behaves as straight sets).
    func supersetMembers(of exercise: Exercise) -> [Exercise] {
        guard let id = exercise.supersetID else { return [] }
        let members = orderedExercises.filter { $0.supersetID == id }
        return members.count >= 2 ? members : []
    }

    func isInSuperset(_ exercise: Exercise) -> Bool {
        !supersetMembers(of: exercise).isEmpty
    }

    /// "A1"-style tag for on-card ribbons and row badges. Nil for
    /// ungrouped exercises.
    func supersetTag(for exercise: Exercise) -> String? {
        guard isInSuperset(exercise) else { return nil }
        return SupersetGrouping.tag(for: exercise, in: orderedExercises)
    }

    /// Total rounds in the exercise's group — the longest member's
    /// set count (short members simply sit out the last rounds).
    func supersetRoundCount(of exercise: Exercise) -> Int {
        supersetMembers(of: exercise).map { $0.orderedSets.count }.max() ?? 0
    }

    /// Decide the choreography after a set just landed on `exercise`.
    /// Nil when the exercise is not in a genuine group. Greedy rule:
    /// the next member in cycle order that is *behind* the finisher's
    /// completed-set count takes over; when nobody is behind, the
    /// round is complete and work resumes at the next member (in cycle
    /// order) that still has pending sets.
    func supersetStep(after exercise: Exercise) -> SupersetStep? {
        let members = supersetMembers(of: exercise)
        guard members.count >= 2,
              let myIndex = members.firstIndex(where: { $0.id == exercise.id })
        else { return nil }

        let myCompleted = completedSetCount(of: exercise)
        let cycle = (1..<members.count).map { members[(myIndex + $0) % members.count] }

        if let partner = cycle.first(where: { member in
            hasIncompleteSets(member) && completedSetCount(of: member) < myCompleted
        }) {
            return .partner(partner)
        }
        if let resume = (cycle + [exercise]).first(where: hasIncompleteSets(_:)) {
            return .roundComplete(resume: resume)
        }
        return .groupComplete
    }

    private func completedSetCount(of exercise: Exercise) -> Int {
        exercise.sets.count(where: \.isCompleted)
    }

    private func hasIncompleteSets(_ exercise: Exercise) -> Bool {
        exercise.sets.contains { !$0.isCompleted }
    }
}
