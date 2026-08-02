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
//  Ranking tiers (best -> worst), evaluated per query token.
//  An item matches only if EVERY token matches at least at the
//  substring tier; the item's score is the worst (highest) token
//  score, so "lat pull" ranks "Lat Pulldown" above single-token
//  noise. Conservative singular/plural stemming makes "squats" match
//  "Squat" without fuzzy typo matching. Within a tier: favorites,
//  the bundled editorial prior, tracked exercises, shorter names,
//  then alphabetical order.
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
        let tokens = words(of: normalized(query))

        guard !tokens.isEmpty else { return items }

        let scored: [Scored] = items.compactMap { item in
            guard let score = combinedScore(item: item, tokens: tokens) else { return nil }
            let tracked = trackedKeys.contains(item.historyKey)
                || trackedKeys.contains(item.legacyHistoryKey)
            return Scored(
                item: item,
                score: score,
                isFavorite: item.isFavorite,
                searchPriority: item.searchPriority,
                isTracked: tracked
            )
        }

        return scored.sorted().map(\.item)
    }

    // MARK: - Scoring

    /// Worst (highest) per-token score across all tokens. `nil` means
    /// at least one token didn't match name or any alias -> exclude.
    private static func combinedScore(item: ExerciseCatalogItem, tokens: [String]) -> Int? {
        var worst = 0
        for token in tokens {
            guard let s = tokenScore(item: item, token: token) else { return nil }
            worst = max(worst, s)
        }
        return worst
    }

    /// Best (lowest) score for a single token vs the item's name and
    /// aliases. Name matches beat alias matches at the same tier
    /// (source weight 0 vs 1). Returns `nil` if the token matches
    /// neither name nor any alias.
    private static func tokenScore(item: ExerciseCatalogItem, token: String) -> Int? {
        let nameScore = stringTier(item.name, token: token).map { $0 * 2 + 0 }
        let aliasScore = item.aliases
            .compactMap { stringTier($0, token: token).map { $0 * 2 + 1 } }
            .min()
        return [nameScore, aliasScore].compactMap({ $0 }).min()
    }

    /// Tier (0-3) for one candidate string vs a normalized token.
    /// 0 exact · 1 phrase-prefix/word-exact · 2 word-prefix · 3 substring.
    /// Prefix and word-exact intentionally share a tier: for a broad
    /// movement query, "Squat Jump" isn't inherently a better answer
    /// than "Barbell Back Squat" just because its name starts with the
    /// token. The editorial and personal signals resolve that ambiguity.
    /// `nil` when the token doesn't appear at all.
    private static func stringTier(_ value: String, token: String) -> Int? {
        let s = normalized(value)
        if s == token { return 0 }
        let words = words(of: s)
        if s.hasPrefix(token) || words.contains(token) { return 1 }
        if words.contains(where: { $0.hasPrefix(token) }) { return 2 }

        // Match only ordinary English inflections, not arbitrary edit
        // distance. This covers squat/squats, lunge/lunges,
        // press/presses, curl/curls, and fly/flies without letting a
        // typo silently select an unrelated exercise.
        let stemmedToken = singularStem(token)
        let stemmedWords = words.map(singularStem)
        if stemmedWords.contains(stemmedToken) { return 1 }

        if s.contains(token) { return 3 }
        return nil
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(
                options: [.diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Small, deterministic English inflector for exercise vocabulary.
    /// Search only needs singular equivalence; it doesn't attempt full
    /// natural-language stemming (which would turn "press" into "pres").
    private static func singularStem(_ word: String) -> String {
        guard word.count > 2 else { return word }

        if word.hasSuffix("ies"), word.count > 3 {
            return String(word.dropLast(3)) + "y"
        }

        let esSuffixes = ["sses", "shes", "ches", "xes", "zes"]
        if esSuffixes.contains(where: word.hasSuffix) {
            return String(word.dropLast(2))
        }

        if word.hasSuffix("s"), !word.hasSuffix("ss") {
            return String(word.dropLast())
        }

        return word
    }

    /// Split on any non-alphanumeric boundary so "Pull-Up" and
    /// "Lat Pulldown" both tokenize to clean words.
    private static func words(of s: String) -> [String] {
        s.split(omittingEmptySubsequences: true, whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    // MARK: - Sort wrapper

    /// Comparable envelope so `sorted()` applies the full tiebreak
    /// chain. Exact/stronger text still always wins; explicit favorites
    /// then beat the default catalog prior, followed by workout history.
    private struct Scored: Comparable {
        let item: ExerciseCatalogItem
        let score: Int
        let isFavorite: Bool
        let searchPriority: Int
        let isTracked: Bool

        static func < (lhs: Scored, rhs: Scored) -> Bool {
            if lhs.score != rhs.score { return lhs.score < rhs.score }
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
