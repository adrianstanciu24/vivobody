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

    @Test func approvedAugustFixturesAreDiscoverableByRequestedNames() {
        let catalog = bundledCatalog()
        let expected: [(String, String)] = [
            ("Nordic Curl", "nordic-curl"),
            ("Preacher Curl", "machine-preacher-curl"),
            ("Incline Dumbbell Curl", "bilateral-incline-dumbbell-curl"),
            ("Mid-Thigh Clean Pull", "barbell-mid-thigh-clean-pull"),
            ("Full Clean", "barbell-squat-clean"),
            ("Full Snatch", "barbell-squat-snatch"),
            ("Kneeling Cable Crunch", "kneeling-cable-crunch"),
            ("Hollow Hold", "hollow-hold"),
            ("Hollow Body Hold", "hollow-hold"),
            ("Passive Dead Hang", "passive-dead-hang"),
            ("Active Dead Hang", "active-dead-hang"),
        ]

        for (query, catalogID) in expected {
            let ranked = ExerciseSearch.rank(items: catalog, query: query)
            #expect(ranked.first?.catalogID == catalogID)
        }
    }

    @Test func defaultCatalogGapFixturesAreDiscoverableByLifterNames() {
        let catalog = bundledCatalog()
        let expected: [(String, String)] = [
            ("Bodyweight Squat", "bodyweight-floor-squat-100-degrees"),
            ("Bodyweight Glute Bridge", "bodyweight-supine-glute-bridge-90-degrees"),
            ("Hands-Elevated Push-Up", "hands-elevated-push-up-30-48-cm"),
            ("Feet-Elevated Push-Up", "feet-elevated-push-up-30-48-cm"),
            ("Reverse Crunch", "supine-reverse-crunch"),
            ("Bodyweight Lateral Lunge", "bodyweight-lateral-lunge-60-percent-height"),
            ("Hang Power Clean", "barbell-hang-power-clean"),
            ("Power Snatch", "barbell-power-snatch-from-floor"),
            ("Push Jerk", "barbell-push-jerk"),
            ("Thruster", "barbell-thruster"),
            ("Dumbbell Pullover", "two-hand-single-dumbbell-pullover"),
        ]

        for (query, catalogID) in expected {
            let ranked = ExerciseSearch.rank(items: catalog, query: query)
            #expect(ranked.first?.catalogID == catalogID)
        }
    }

    @Test func commercialMachineFirstWaveIsDiscoverableAndKeepsNeighborQueriesDistinct() {
        let catalog = bundledCatalog()
        let expected: [(String, String)] = [
            ("Assisted Dip Machine", "life-fitness-pro2-assisted-dip-machine"),
            ("Seated Machine Triceps Extension", "life-fitness-pro2-seated-triceps-extension"),
            ("Glute Kickback Machine", "technogym-selection-machine-glute-kickback"),
            ("Cable Glute Kickback", "supported-cable-ankle-cuff-hip-extension"),
            ("Machine Chest Fly", "seated-handled-lever-machine-chest-fly"),
        ]

        for (query, catalogID) in expected {
            let ranked = ExerciseSearch.rank(items: catalog, query: query)
            #expect(ranked.first?.catalogID == catalogID)
        }
    }

    @Test func genericDeadHangKeepsPassiveThenActiveVariantsTogether() {
        let ranked = ExerciseSearch.rank(items: bundledCatalog(), query: "dead hang")
        #expect(ranked.prefix(2).compactMap(\.catalogID) == [
            "passive-dead-hang",
            "active-dead-hang",
        ])
    }

    @Test func comprehensiveExpansionIsDiscoverableByLifterFacingNames() {
        let catalog = bundledCatalog()
        let expected: [(String, String)] = [
            ("Romanian Deadlift", "continuous-top-start-barbell-romanian-deadlift"),
            ("Goblet Squat", "single-dumbbell-goblet-squat"),
            ("Vertical Smith Upper-Back Squat", "smith-machine-upper-back-squat"),
            ("Dumbbell Bulgarian Split Squat", "two-dumbbell-rear-foot-elevated-split-squat"),
            ("Dumbbell RFESS", "two-dumbbell-rear-foot-elevated-split-squat"),
            ("Dumbbell Walking Lunge", "two-dumbbell-continuous-walking-lunge"),
            ("Machine Leg Extension", "upright-bilateral-lever-machine-leg-extension"),
            ("Standing Machine Calf Raise", "bilateral-standing-shoulder-pad-machine-calf-raise"),
            ("Seated Machine Calf Raise", "bilateral-seated-thigh-pad-machine-calf-raise"),
            ("Bilateral Dumbbell Lateral Raise", "simultaneous-bilateral-dumbbell-lateral-raise"),
            ("Standing Dumbbell Biceps Curl", "standing-bilateral-supinated-dumbbell-curl"),
            ("Dumbbell Hammer Curl", "bilateral-dumbbell-hammer-curl"),
            ("Rope Triceps Pushdown", "bilateral-rope-cable-triceps-pushdown"),
            ("Barbell Shrug", "standing-bilateral-barbell-shrug"),
            ("Seated Handled Machine Chest Fly", "seated-handled-lever-machine-chest-fly"),
            ("Cable Glute Kickback", "supported-cable-ankle-cuff-hip-extension"),
            ("38 cm Dumbbell Forward Step-Up", "two-dumbbell-forward-step-up"),
            ("Ab Wheel Rollout", "kneeling-ab-wheel-rollout"),
        ]

        for (query, catalogID) in expected {
            let ranked = ExerciseSearch.rank(items: catalog, query: query)
            #expect(ranked.first?.catalogID == catalogID)
        }
    }

    @Test func consolidatedMovementsHaveOneStandardCatalogEntry() {
        let catalog = bundledCatalog()
        let expected: [(String, String)] = [
            ("Machine Reverse Fly", "neutral-grip-machine-reverse-fly"),
            ("Front Raise", "simultaneous-bilateral-dumbbell-front-raise"),
            ("Split Squat", "two-dumbbell-stationary-split-squat"),
            ("Bulgarian Split Squat", "two-dumbbell-rear-foot-elevated-split-squat"),
            ("Romanian Deadlift", "continuous-top-start-barbell-romanian-deadlift"),
            ("Pull-Up", "pull-up"),
        ]

        for (name, catalogID) in expected {
            #expect(catalog.count(where: { $0.name == name }) == 1)
            #expect(ExerciseSearch.rank(items: catalog, query: name).first?.catalogID == catalogID)
        }

        let retiredIDs: Set = [
            "pronated-grip-machine-reverse-fly",
            "kettlebell-high-plank-drag",
            "single-arm-dumbbell-front-raise",
            "barbell-split-squat",
            "barbell-rear-foot-elevated-split-squat",
            "bodyweight-split-squat",
            "bodyweight-bulgarian-split-squat",
            "goblet-split-squat",
            "barbell-romanian-deadlift",
            "barbell-romanian-deadlift-15-cm-step",
            "two-dumbbell-continuous-romanian-deadlift",
            "single-kettlebell-romanian-deadlift",
            "neutral-grip-pull-up",
            "wide-grip-pull-up",
        ]
        #expect(Set(catalog.compactMap(\.catalogID)).isDisjoint(with: retiredIDs))
    }

    @Test func conciseNamesFindTheRemainingOrdinaryMovements() {
        let catalog = bundledCatalog()
        let expected: [(String, String)] = [
            ("Dumbbell Curl", "standing-bilateral-supinated-dumbbell-curl"),
            ("Farmer Carry", "two-dumbbell-farmer-carry"),
            ("Shrug", "bilateral-dumbbell-shrug"),
            ("Lateral Raise", "simultaneous-bilateral-dumbbell-lateral-raise"),
            ("Forward Step-Up", "two-dumbbell-forward-step-up"),
            ("Goblet Squat", "single-dumbbell-goblet-squat"),
            ("Goblet Squat to Press", "two-hand-single-dumbbell-goblet-squat-to-press"),
            ("Lat Pulldown", "cable-lat-pulldown"),
            ("Straight-Arm Pulldown", "shoulder-width-straight-arm-cable-pulldown"),
        ]

        for (name, catalogID) in expected {
            #expect(catalog.count(where: { $0.name == name }) == 1)
            #expect(ExerciseSearch.rank(items: catalog, query: name).first?.catalogID == catalogID)
        }

        let retiredIDs: Set = [
            "kettlebell-goblet-squat",
            "close-grip-neutral-lat-pulldown",
            "underhand-lat-pulldown",
            "wide-grip-lat-pulldown",
            "wide-grip-straight-arm-cable-pulldown",
        ]
        #expect(Set(catalog.compactMap(\.catalogID)).isDisjoint(with: retiredIDs))
    }

    @Test func genericCleanAndSnatchKeepPowerNeighborsAheadOfSquatFixtures() throws {
        let catalog = bundledCatalog()
        let cleanIDs = ExerciseSearch.rank(items: catalog, query: "clean").compactMap(\.catalogID)
        let snatchIDs = ExerciseSearch.rank(items: catalog, query: "snatch").compactMap(\.catalogID)
        let powerCleanIndex = try #require(cleanIDs.firstIndex(of: "barbell-power-clean"))
        let squatCleanIndex = try #require(cleanIDs.firstIndex(of: "barbell-squat-clean"))
        let hangPowerSnatchIndex = try #require(
            snatchIDs.firstIndex(of: "barbell-hang-power-snatch")
        )
        let squatSnatchIndex = try #require(
            snatchIDs.firstIndex(of: "barbell-squat-snatch")
        )

        #expect(powerCleanIndex < squatCleanIndex)
        #expect(hangPowerSnatchIndex < squatSnatchIndex)
    }

    @Test func trainingRoleFiltersSpanCompoundAndIsolationWork() {
        let catalog = bundledCatalog()
        let push = catalog.filter { ExerciseCatalogFilter.trainingRole(.push).matches($0) }
        let pull = catalog.filter { ExerciseCatalogFilter.trainingRole(.pull).matches($0) }

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

    // MARK: - Joined words

    @Test func singleLegMatchesSpacedHyphenatedAndJoinedForms() {
        let catalog = bundledCatalog()
        let spaced = names(ExerciseSearch.rank(items: catalog, query: "single leg"))
        #expect(!spaced.isEmpty)
        #expect(spaced.allSatisfy { $0.contains("Single-Leg") })
        #expect(names(ExerciseSearch.rank(items: catalog, query: "single-leg")) == spaced)
        #expect(names(ExerciseSearch.rank(items: catalog, query: "singleleg")) == spaced)
    }

    @Test func joinedQueryMatchesHyphenatedName() {
        let catalog = [item("Push-Up"), item("Push Press")]
        let ranked = ExerciseSearch.rank(items: catalog, query: "pushup")
        #expect(names(ranked) == ["Push-Up"])
    }

    @Test func exactAliasBeatsLooserWordPairMatch() {
        let catalog = [
            item("Band-Assisted Pull-Up"),
            item("Machine-Assisted Pull-Up", aliases: ["Assisted Pullup"]),
        ]
        let ranked = ExerciseSearch.rank(items: catalog, query: "assisted pullup")
        #expect(ranked.first?.name == "Machine-Assisted Pull-Up")
    }

    // MARK: - Synonyms

    @Test func equivalentPhrasesFindTheSameExercises() {
        let catalog = bundledCatalog()
        let singleLeg = Set(names(ExerciseSearch.rank(items: catalog, query: "single leg")))
        for query in ["one leg", "single legged", "1 leg"] {
            let ranked = Set(names(ExerciseSearch.rank(items: catalog, query: query)))
            #expect(singleLeg.isSubset(of: ranked), "\(query)")
        }
        #expect(names(ExerciseSearch.rank(items: catalog, query: "sl rdl")).contains("Kettlebell Single-Leg RDL"))
        #expect(names(ExerciseSearch.rank(items: catalog, query: "db press")).contains("Dumbbell Bench Press"))
    }

    @Test func synonymAbbreviationMustMatchAWholeWord() {
        let catalog = [item("Medicine Ball Slam"), item("Single-Leg Hip Thrust")]
        let ranked = ExerciseSearch.rank(items: catalog, query: "single leg")
        #expect(names(ranked) == ["Single-Leg Hip Thrust"])
    }

    @Test func broadTermIsOneWay() {
        let catalog = [
            item("Single-Arm Cable Row"),
            item("Single-Leg Curl", group: .legs),
            item("Unilateral Band Row"),
        ]
        let unilateral = Set(names(ExerciseSearch.rank(items: catalog, query: "unilateral")))
        #expect(unilateral == ["Single-Arm Cable Row", "Single-Leg Curl", "Unilateral Band Row"])
        #expect(names(ExerciseSearch.rank(items: catalog, query: "single leg")) == ["Single-Leg Curl"])
    }

    @Test func literalPhraseBeatsSynonymAtTheSameTier() {
        let catalog = [item("Single-Leg Bridge"), item("One-Leg Bridge")]
        let ranked = ExerciseSearch.rank(items: catalog, query: "one leg")
        #expect(ranked.first?.name == "One-Leg Bridge")
    }

    // MARK: - Typo correction

    @Test func unknownWordIsCorrectedAndReported() {
        let index = ExerciseSearchIndex(items: bundledCatalog())
        for typo in ["sinle leg", "singel leg", "signle leg"] {
            let plan = index.plan(for: typo)
            #expect(plan.correctedQuery == "single leg", "\(typo)")
            #expect(names(index.rank(plan)).allSatisfy { $0.contains("Single-Leg") }, "\(typo)")
        }
        #expect(index.plan(for: "dumbell press").correctedQuery == "dumbbell press")
    }

    @Test func knownWordsAndPrefixesAreNeverCorrected() {
        let index = ExerciseSearchIndex(items: bundledCatalog())
        for query in ["press", "squats", "single le", "kettlebel", "ohp", "45 leg press"] {
            #expect(index.plan(for: query).correctedQuery == nil, "\(query)")
        }
    }

    @Test func shortWordsAreNotCorrected() {
        let index = ExerciseSearchIndex(items: [item("Single-Leg Curl", group: .legs)])
        let plan = index.plan(for: "single lge")
        #expect(plan.correctedQuery == nil)
        #expect(plan.isClosestMatch)
    }

    // MARK: - Closest matches

    @Test func extraWordStillFindsTheExercise() {
        let index = ExerciseSearchIndex(items: bundledCatalog())
        let plan = index.plan(for: "split leg squat")
        #expect(plan.isClosestMatch)
        let ranked = names(index.rank(plan))
        #expect(ranked.first?.contains("Split Squat") == true)
    }

    @Test func wordOrderDoesNotMatter() {
        let catalog = bundledCatalog()
        let inOrder = Set(names(ExerciseSearch.rank(items: catalog, query: "split squat")))
        #expect(!inOrder.isEmpty)
        #expect(Set(names(ExerciseSearch.rank(items: catalog, query: "squat split"))) == inOrder)
    }

    @Test func closestMatchPrefersMissingTheCommonWord() {
        let catalog = [
            item("Single-Leg Squat", group: .legs),
            item("Split Squat", group: .legs),
            item("Leg Press", group: .legs),
            item("Leg Curl", group: .legs),
        ]
        let ranked = ExerciseSearch.rank(items: catalog, query: "split leg squat")
        #expect(names(ranked) == ["Split Squat", "Single-Leg Squat"])
    }

    @Test func closestMatchOnlyWhenNoItemMatchesEveryWord() {
        let catalog = [item("Split Squat", group: .legs), item("Single-Leg Squat", group: .legs)]
        let index = ExerciseSearchIndex(items: catalog)
        let plan = index.plan(for: "leg squat")
        #expect(!plan.isClosestMatch)
        #expect(names(index.rank(plan)) == ["Single-Leg Squat"])
        #expect(!index.plan(for: "zzz").isClosestMatch)
        #expect(index.rank(index.plan(for: "zzz")).isEmpty)
    }

    @Test func closestMatchMissesAtMostOneWord() {
        let catalog = [item("Split Squat", group: .legs)]
        #expect(ExerciseSearch.rank(items: catalog, query: "split zzz qqq").isEmpty)
    }

    @Test func editDistanceCountsAdjacentSwapAsOneEdit() {
        #expect(ExerciseSearchText.editDistance("singel", "single", limit: 1) == 1)
        #expect(ExerciseSearchText.editDistance("sinle", "single", limit: 1) == 1)
        #expect(ExerciseSearchText.editDistance("deadlfit", "deadlift", limit: 2) == 1)
        #expect(ExerciseSearchText.editDistance("bench", "lunge", limit: 2) == nil)
    }
}
