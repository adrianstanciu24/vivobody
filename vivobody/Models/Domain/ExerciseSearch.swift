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
//  Ranking tiers (best -> worst), evaluated per whitespace token.
//  An item matches only if EVERY token matches at least at the
//  substring tier; the item's score is the worst (highest) token
//  score, so "lat pull" ranks "Lat Pulldown" above single-token
//  noise. Within a tier, exercises the user has actually logged
//  sort first (tracked boost), then shorter names, then alphabetical.
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
        let tokens = query
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard !tokens.isEmpty else { return items }

        let scored: [Scored] = items.compactMap { item in
            guard let score = combinedScore(item: item, tokens: tokens) else { return nil }
            let tracked = trackedKeys.contains(item.historyKey)
                || trackedKeys.contains(item.legacyHistoryKey)
            return Scored(item: item, score: score, isTracked: tracked)
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
        let nameScore = stringTier(item.name.lowercased(), token: token).map { $0 * 2 + 0 }
        let aliasScore = item.aliases
            .compactMap { stringTier($0.lowercased(), token: token).map { $0 * 2 + 1 } }
            .min()
        return [nameScore, aliasScore].compactMap({ $0 }).min()
    }

    /// Tier (0-4) for one lowercased candidate string vs a token.
    /// 0 exact · 1 prefix · 2 word-exact · 3 word-prefix · 4 substring.
    /// `nil` when the token doesn't appear at all.
    private static func stringTier(_ s: String, token: String) -> Int? {
        if s == token { return 0 }
        if s.hasPrefix(token) { return 1 }
        let words = words(of: s)
        if words.contains(token) { return 2 }
        if words.contains(where: { $0.hasPrefix(token) }) { return 3 }
        if s.contains(token) { return 4 }
        return nil
    }

    /// Split on any non-alphanumeric boundary so "Pull-Up" and
    /// "Lat Pulldown" both tokenize to clean words.
    private static func words(of s: String) -> [String] {
        s.split(omittingEmptySubsequences: true, whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    // MARK: - Sort wrapper

    /// Comparable envelope so `sorted()` applies the full tiebreak
    /// chain: relevance score, tracked boost, shorter name, alpha.
    private struct Scored: Comparable {
        let item: ExerciseCatalogItem
        let score: Int
        let isTracked: Bool

        static func < (lhs: Scored, rhs: Scored) -> Bool {
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            if lhs.isTracked != rhs.isTracked { return lhs.isTracked }
            if lhs.item.name.count != rhs.item.name.count {
                return lhs.item.name.count < rhs.item.name.count
            }
            return lhs.item.name.lowercased() < rhs.item.name.lowercased()
        }
    }
}
