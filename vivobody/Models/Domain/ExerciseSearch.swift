//
//  ExerciseSearch.swift
//  vivobody
//
//  Relevance ranker for the exercise catalog. Both the Library
//  exercises tab and the ExercisePickerSheet delegate text search
//  here so the two surfaces rank identically. Pure function over
//  catalog items + query + the user's tracked-exercise keys — no
//  SwiftData, no UI — so it is unit-tested directly.
//
//  A search has three stages. Typo correction (ExerciseSearchCorrector)
//  replaces a query word that no catalog word contains with the closest
//  catalog word, and the plan reports the corrected query so the UI can
//  name it. Synonym rewrites (ExerciseSearchVocabulary) add alternative
//  queries, such as "one leg" for "single leg". Ranking scores the
//  literal query and each rewrite; a rewrite ranks just below the
//  literal query at the same tier.
//
//  Ranking tiers (best -> worst), evaluated per query token, in any
//  word order. An item matches only if EVERY token matches at least at
//  the substring tier; the item's score is the worst (highest) token
//  score, so "lat pull" ranks "Lat Pulldown" above single-token
//  noise. When no item in the index matches every token of a query of
//  two or more words, the plan becomes a closest-match plan: an item
//  may miss one word, and items that miss a common word ("leg") rank
//  above items that miss a rare word ("split"), so "split leg squat"
//  still finds Split Squat. Words written together match hyphenated or
//  spaced names ("singleleg", "pushup"), and conservative singular/plural
//  stemming makes "squats" match "Squat". Within a tier: favorites, the bundled
//  editorial prior, tracked exercises, shorter names, then
//  alphabetical order.
//

import Foundation

enum ExerciseSearch {
    /// Returns `items` filtered and sorted by relevance to `query`.
    /// An empty/whitespace query returns `items` unchanged in their
    /// original order — the caller is expected to group for browsing
    /// when no search is active.
    static func rank(
        items: [ExerciseCatalogItem],
        query: String,
        trackedKeys: Set<String> = []
    ) -> [ExerciseCatalogItem] {
        let index = ExerciseSearchIndex(items: items)
        return index.rank(index.plan(for: query), trackedKeys: trackedKeys)
    }
}

/// One query, prepared for ranking.
struct ExerciseSearchPlan {
    /// The literal query (after typo correction) first, then synonym rewrites.
    let alternatives: [[ExerciseSearchToken]]
    /// The searched query when typo correction changed a word; otherwise nil.
    let correctedQuery: String?
    /// How many indexed items each query word matches. Set only for a
    /// closest-match plan, which lets an item miss one word.
    let wordFrequency: [ExerciseSearchToken: Int]?

    var isEmpty: Bool {
        alternatives.first?.isEmpty ?? true
    }

    /// True when no indexed item matched every word, so results miss one word.
    var isClosestMatch: Bool {
        wordFrequency != nil
    }
}

/// Normalized names and aliases for every item the user may find. Rank
/// any subset of it, so typo correction uses the whole catalog even when
/// a filter chip limits the results.
struct ExerciseSearchIndex {
    private struct Entry {
        let item: ExerciseCatalogItem
        let fields: [ExerciseSearchField]
    }

    private let entries: [Entry]
    private let corrector: ExerciseSearchCorrector

    init(items: [ExerciseCatalogItem]) {
        let entries = items.map { item in
            Entry(
                item: item,
                fields: [ExerciseSearchField(item.name, source: 0)]
                    + item.aliases.map { ExerciseSearchField($0, source: 1) }
            )
        }
        self.entries = entries
        corrector = ExerciseSearchCorrector(fields: entries.map(\.fields))
    }

    func plan(for query: String) -> ExerciseSearchPlan {
        let typed = ExerciseSearchText.words(of: ExerciseSearchText.normalized(query))
        let corrected = typed.map { word in
            corrector.correction(for: ExerciseSearchToken(word)) ?? word
        }
        let alternatives = ExerciseSearchVocabulary.alternatives(
            for: corrected.map { ExerciseSearchToken($0) }
        )
        let correctedQuery = corrected == typed ? nil : corrected.joined(separator: " ")
        let exact = ExerciseSearchPlan(
            alternatives: alternatives,
            correctedQuery: correctedQuery,
            wordFrequency: nil
        )
        guard corrected.count > 1,
              !entries.contains(where: { Self.match($0.fields, plan: exact) != nil })
        else { return exact }

        let tokens = Set(alternatives.joined())
        return ExerciseSearchPlan(
            alternatives: alternatives,
            correctedQuery: correctedQuery,
            wordFrequency: Dictionary(uniqueKeysWithValues: tokens.map { token in
                (token, entries.count { entry in
                    entry.fields.contains { $0.score(for: token) != nil }
                })
            })
        )
    }

    /// Included items sorted by relevance to `plan`. An empty plan
    /// returns the included items in their original order.
    func rank(
        _ plan: ExerciseSearchPlan,
        trackedKeys: Set<String> = [],
        where includes: (ExerciseCatalogItem) -> Bool = { _ in true }
    ) -> [ExerciseCatalogItem] {
        let included = entries.filter { includes($0.item) }
        guard !plan.isEmpty else { return included.map(\.item) }

        let scored: [Scored] = included.compactMap { entry in
            guard let match = Self.match(entry.fields, plan: plan) else { return nil }
            return Scored(
                item: entry.item,
                match: match,
                isFavorite: entry.item.isFavorite,
                searchPriority: entry.item.searchPriority,
                isTracked: trackedKeys.contains(entry.item.historyKey)
            )
        }
        return scored.sorted().map(\.item)
    }

    // MARK: - Scoring

    /// How well one item answers a plan. Lower is better.
    private struct Match: Comparable {
        let score: Int
        /// How many indexed items match the word this item misses; nil
        /// when it matches every word. Missing a common word costs less
        /// than missing a rare, specific word.
        let missedWordFrequency: Int?

        static func < (lhs: Match, rhs: Match) -> Bool {
            switch (lhs.missedWordFrequency, rhs.missedWordFrequency) {
            case (nil, .some): true
            case (.some, nil): false
            case let (lhsMissed?, rhsMissed?) where lhsMissed != rhsMissed:
                lhsMissed > rhsMissed
            default: lhs.score < rhs.score
            }
        }
    }

    /// Best match across the literal query and its rewrites. A literal
    /// query that equals a whole name or alias ranks first, because word
    /// pairs can otherwise tie it with a looser match. A rewrite adds one
    /// step, so it never outranks the literal query at the same tier.
    private static func match(_ fields: [ExerciseSearchField], plan: ExerciseSearchPlan) -> Match? {
        let literal = plan.alternatives.first?.map(\.text).joined() ?? ""
        if let exact = fields.filter({ $0.joined == literal }).map(\.source).min() {
            return Match(score: exact * 2, missedWordFrequency: nil)
        }
        return plan.alternatives.enumerated().compactMap { index, tokens in
            combinedMatch(fields, tokens: tokens, wordFrequency: plan.wordFrequency).map {
                Match(score: $0.score * 2 + (index == 0 ? 0 : 1), missedWordFrequency: $0.missedWordFrequency)
            }
        }.min()
    }

    /// Worst (highest) per-token score across all tokens. `nil` means a
    /// token didn't match the name or any alias, except that a
    /// closest-match plan forgives one missed token of a multi-word query.
    private static func combinedMatch(
        _ fields: [ExerciseSearchField],
        tokens: [ExerciseSearchToken],
        wordFrequency: [ExerciseSearchToken: Int]?
    ) -> Match? {
        var worst = 0
        var missed: ExerciseSearchToken?
        for token in tokens {
            if let score = fields.compactMap({ $0.score(for: token) }).min() {
                worst = max(worst, score)
            } else if wordFrequency != nil, tokens.count > 1, missed == nil {
                missed = token
            } else {
                return nil
            }
        }
        return Match(score: worst, missedWordFrequency: missed.map { wordFrequency?[$0] ?? 0 })
    }

    // MARK: - Sort wrapper

    /// Comparable envelope so `sorted()` applies the full tiebreak
    /// chain. Exact/stronger text still always wins; explicit favorites
    /// then beat the default catalog prior, followed by workout history.
    private struct Scored: Comparable {
        let item: ExerciseCatalogItem
        let match: Match
        let isFavorite: Bool
        let searchPriority: Int
        let isTracked: Bool

        static func < (lhs: Scored, rhs: Scored) -> Bool {
            if lhs.match != rhs.match { return lhs.match < rhs.match }
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            if lhs.searchPriority != rhs.searchPriority {
                return lhs.searchPriority > rhs.searchPriority
            }
            if lhs.isTracked != rhs.isTracked { return lhs.isTracked }
            if lhs.item.name.count != rhs.item.name.count {
                return lhs.item.name.count < rhs.item.name.count
            }
            return lhs.item.name.lowercased() < rhs.item.name.lowercased()
        }
    }
}
