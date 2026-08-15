//
//  ExerciseSearchTests.swift
//  vivobodyTests
//
//  Guards the ExerciseSearch ranker: lexical tiers, singular/plural
//  equivalence, multi-token AND semantics, favorite/history signals,
//  and the bundled editorial prior. Canonical cases are "pull"
//  surfacing Pull-Up and both "squat" / "squats" surfacing Barbell
//  Back Squat ahead of long-tail variations.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseSearchTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// Lightweight in-memory catalog item — only name + aliases
    /// affect ranking, so the rest stays at defaults.
    private func item(
        _ name: String,
        group: MuscleGroup = .back,
        aliases: [String] = [],
        createdAtOffset: TimeInterval = 0
    ) -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            name: name,
            group: group,
            defaultWeight: 135,
            equipment: .barbell,
            aliases: aliases,
            createdAt: now.addingTimeInterval(createdAtOffset)
        )
    }

    private func names(_ items: [ExerciseCatalogItem]) -> [String] {
        items.map(\.name)
    }

    private func bundledCatalog() -> [ExerciseCatalogItem] {
        CatalogData.records.enumerated().map { index, record in
            ExerciseCatalogItem(
                record: record,
                createdAt: now.addingTimeInterval(Double(index))
            )
        }
    }

    // MARK: - The canonical case

    @Test func pullSurfacesPullUpsFirst() {
        let catalog = [
            item("Lat Pulldown", aliases: ["Lat Pulldown"]),
            item("Pull-Up", aliases: ["Pull-up", "Pullup", "Pull Ups"]),
            item("Cable Pull-Through"),
            item("Band Pull-Apart", aliases: ["Band Pull-Apart"]),
            item("Face pulls", aliases: ["Face Pull"]),
            item("Single-Arm Cross-Body Lat Pulldown"),
            item("Pull Ups on Machine", aliases: ["Machine Assisted Pull-up"]),
            item("Isometric Pull-Up Hold", aliases: ["Pull-up Hold"]),
        ]
        let ranked = ExerciseSearch.rank(items: catalog, query: "pull")
        #expect(ranked.first?.name == "Pull-Up")
    }

    @Test func singularSquatSurfacesCanonicalBackSquatFirst() {
        let ranked = ExerciseSearch.rank(items: bundledCatalog(), query: "squat")
        #expect(ranked.first?.name == "Barbell Back Squat")
    }

    @Test func pluralSquatsMatchesAndSurfacesCanonicalBackSquatFirst() {
        let ranked = ExerciseSearch.rank(items: bundledCatalog(), query: "squats")
        #expect(ranked.first?.name == "Barbell Back Squat")
    }

    @Test func trainingRoleFiltersSpanCompoundAndIsolationWork() {
        let catalog = bundledCatalog()
        let push = catalog.filter { LibraryExerciseFilter.trainingRole(.push).matches($0) }
        let pull = catalog.filter { LibraryExerciseFilter.trainingRole(.pull).matches($0) }

        #expect(push.contains { $0.name == "Barbell Bench Press" && $0.mechanic == .compound })
        #expect(push.contains { $0.name == "Flat Dumbbell Fly" && $0.mechanic == .isolation })
        #expect(!push.contains { $0.name == "Supinated Straight-Bar Cable Curl" })

        #expect(pull.contains { $0.name == "Barbell Bent-Over Row" && $0.mechanic == .compound })
        #expect(pull.contains { $0.name == "Supinated Straight-Bar Cable Curl" && $0.mechanic == .isolation })
        #expect(!pull.contains { $0.name == "Single-Arm Pronated Cable Triceps Pushdown" })
    }

    @Test func exactCustomNameStillBeatsEditorialPriority() throws {
        let canonicalRecord = try #require(CatalogData.record(forCatalogID: "barbell-back-squat"))
        let canonical = ExerciseCatalogItem(record: canonicalRecord, createdAt: now)
        let custom = item("Squat", group: .legs)

        let ranked = ExerciseSearch.rank(items: [canonical, custom], query: "squat")
        #expect(ranked.first?.name == "Squat")
    }

    // MARK: - Tier ordering

    @Test func strongPrefixUsesDeterministicTiebreakAgainstWordExact() {
        let catalog = [
            item("Lat Pulldown"), // word-prefix "pull"
            item("Pull-Up"), // phrase-prefix / word-exact "pull"
        ]
        let ranked = ExerciseSearch.rank(items: catalog, query: "pull")
        #expect(ranked.first?.name == "Pull-Up")
    }

    @Test func wordExactBeatsSubstring() {
        // "Cable Pull-Through": "pull" is a whole word -> word-exact tier.
        // "Overpull": "pull" sits mid-word, not a prefix, not a word ->
        // substring tier. Word-exact must rank higher.
        let catalog = [
            item("Overpull"), // substring-only "pull"
            item("Cable Pull-Through"), // word-exact "pull"
        ]
        let ranked = ExerciseSearch.rank(items: catalog, query: "pull")
        #expect(ranked.first?.name == "Cable Pull-Through")
    }

    @Test func nameBeatsAliasAtSameTier() {
        // "Pull-Up" matches by name prefix; an alias-only prefix match
        // on another item should rank lower even if it's shorter.
        let catalog = [
            item("Scapular Pull-Up", aliases: ["Scapular Pull-up"]), // alias prefix "pull"
            item("Pull-Up"), // name prefix "pull"
        ]
        let ranked = ExerciseSearch.rank(items: catalog, query: "pull")
        #expect(ranked.first?.name == "Pull-Up")
    }

    @Test func aliasExactFindsExercise() {
        let catalog = [
            item("Barbell Bench Press", aliases: ["BP"]),
            item("Pull-Up"),
        ]
        let ranked = ExerciseSearch.rank(items: catalog, query: "bp")
        #expect(ranked.first?.name == "Barbell Bench Press")
    }

    // MARK: - Multi-token (AND semantics)

    @Test func multiTokenKeepsOnlyItemsMatchingEveryToken() {
        let catalog = [
            item("Lat Pulldown", aliases: ["Lat Pulldown"]),
            item("Lat Pushdown", aliases: ["Lat Pushdown"]), // "lat" yes, "pull" no
            item("Wide Pull Up"), // "pull" yes, "lat" no
        ]
        let ranked = ExerciseSearch.rank(items: catalog, query: "lat pull")
        #expect(names(ranked) == ["Lat Pulldown"])
    }

    @Test func multiTokenRanksByWorstTokenScore() {
        // "Lat Pull Down" has two strong token matches; "Lat Pulldown"
        // only has a weaker word-prefix match for "pull".
        let catalog = [
            item("Lat Pulldown"),
            item("Lat Pull Down"),
        ]
        let ranked = ExerciseSearch.rank(items: catalog, query: "lat pull")
        #expect(ranked.first?.name == "Lat Pull Down")
    }

    // MARK: - Tracked boost + relevance priority

    @Test func trackedBoostBreaksTie() {
        // Same prefix tier, same length -> without the boost alpha
        // would put "Pull-foo" first (f < u). Tracked flips it.
        let a = item("Pull-Up")
        let b = item("Pull-foo")
        let catalog = [b, a]
        let tracked: Set<String> = [a.historyKey]
        let ranked = ExerciseSearch.rank(items: catalog, query: "pull", trackedKeys: tracked)
        #expect(ranked.first?.name == "Pull-Up")
    }

    @Test func relevanceBeatsTracked() {
        // Tracked substring match must NOT outrank an untracked prefix.
        let pullUps = item("Pull-Up")
        let facePulls = item("Face pulls", aliases: ["Face Pull"])
        let catalog = [facePulls, pullUps]
        let tracked: Set<String> = [facePulls.historyKey]
        let ranked = ExerciseSearch.rank(items: catalog, query: "pull", trackedKeys: tracked)
        #expect(ranked.first?.name == "Pull-Up")
    }

    // MARK: - Edge cases

    @Test func emptyQueryReturnsAllUnchanged() {
        let catalog = [item("Pull-Up"), item("Barbell Bench Press")]
        let ranked = ExerciseSearch.rank(items: catalog, query: "   ")
        #expect(ranked.count == 2)
    }

    @Test func caseInsensitive() {
        let catalog = [item("Pull-Up")]
        let ranked = ExerciseSearch.rank(items: catalog, query: "PULL")
        #expect(ranked.first?.name == "Pull-Up")
    }

    @Test func noMatchesReturnsEmpty() {
        let catalog = [item("Pull-Up"), item("Barbell Bench Press")]
        let ranked = ExerciseSearch.rank(items: catalog, query: "zzz")
        #expect(ranked.isEmpty)
    }

    @Test func hyphenatedWordsTokenize() {
        // "Pull-Up" should expose the word "ups" for token matching.
        let catalog = [item("Pull-Up"), item("Pull-downs", aliases: ["Pulldown"])]
        let ranked = ExerciseSearch.rank(items: catalog, query: "ups")
        #expect(ranked.first?.name == "Pull-Up")
    }

    @Test func shortPluralStemDoesNotBroadenIntoAnotherWord() {
        let catalog = [
            item("Abs Crunch", group: .core),
            item("Machine Hip Abduction", group: .legs),
        ]
        let ranked = ExerciseSearch.rank(items: catalog, query: "abs")
        #expect(names(ranked) == ["Abs Crunch"])
    }
}
