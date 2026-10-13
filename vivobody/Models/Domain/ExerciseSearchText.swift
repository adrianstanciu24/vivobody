//
//  ExerciseSearchText.swift
//  vivobody
//
//  Text primitives shared by the exercise search ranker, its synonym
//  rewrites, and typo correction: normalization, word splitting,
//  joined word pairs, singular stems, the per-string match tiers, and
//  the edit distance that bounds a correction. One definition of a
//  "word" keeps the three stages consistent.
//

import Foundation

nonisolated enum ExerciseSearchText {
    static func normalized(_ value: String) -> String {
        value
            .folding(
                options: [.diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Split on any non-alphanumeric boundary so "Pull-Up" and
    /// "Lat Pulldown" both tokenize to clean words.
    static func words(of value: String) -> [String] {
        value.split(omittingEmptySubsequences: true, whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    /// Adjacent words written together, so "Single-Leg" also answers
    /// "singleleg" and "Push-Up" answers "pushup".
    static func joinedPairs(of words: [String]) -> [String] {
        guard words.count > 1 else { return [] }
        return zip(words, words.dropFirst()).map { $0 + $1 }
    }

    /// Small, deterministic English inflector for exercise vocabulary.
    /// Search only needs singular equivalence; it doesn't attempt full
    /// natural-language stemming (which would turn "press" into "pres").
    static func singularStem(_ word: String) -> String {
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

    /// Optimal-string-alignment distance: an insertion, deletion,
    /// substitution, or swap of two adjacent letters each costs one.
    /// Returns nil as soon as the distance must exceed `limit`.
    static func editDistance(_ lhs: String, _ rhs: String, limit: Int) -> Int? {
        let a = Array(lhs)
        let b = Array(rhs)
        guard abs(a.count - b.count) <= limit else { return nil }
        guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }

        var beforePrevious = [Int](repeating: 0, count: b.count + 1)
        var previous = Array(0 ... b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1 ... a.count {
            current[0] = i
            for j in 1 ... b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    current[j] = min(current[j], beforePrevious[j - 2] + 1)
                }
            }
            // A row minimum never decreases in later rows, so once every
            // cell exceeds the limit the final distance must too.
            guard (current.min() ?? 0) <= limit else { return nil }
            (beforePrevious, previous, current) = (previous, current, beforePrevious)
        }
        return previous[b.count] <= limit ? previous[b.count] : nil
    }
}

/// One query word, prepared once per search.
nonisolated struct ExerciseSearchToken: Hashable {
    let text: String
    let stem: String
    /// Synonym rewrites must match a whole word: an abbreviation such as
    /// "sl" must not pick up "Slam" through a prefix.
    let requiresWholeWord: Bool

    init(_ text: String, requiresWholeWord: Bool = false) {
        self.text = text
        stem = ExerciseSearchText.singularStem(text)
        self.requiresWholeWord = requiresWholeWord
    }
}

/// One exercise name or alias, normalized once per search.
nonisolated struct ExerciseSearchField {
    /// 0 for the exercise name, 1 for an alias. Name beats alias at the same tier.
    let source: Int
    let text: String
    /// Every word written together, so "Pull-Up" also equals "pullup".
    let joined: String
    /// Single words plus adjacent word pairs written together.
    let terms: Set<String>
    let stems: Set<String>

    init(_ value: String, source: Int) {
        let text = ExerciseSearchText.normalized(value)
        let words = ExerciseSearchText.words(of: text)
        let terms = Set(words + ExerciseSearchText.joinedPairs(of: words))
        self.source = source
        self.text = text
        joined = words.joined()
        self.terms = terms
        stems = Set(terms.map(ExerciseSearchText.singularStem))
    }

    /// Tier (0-3) for one token: 0 exact · 1 phrase-prefix/word-exact
    /// · 2 word-prefix · 3 substring. Prefix and word-exact share a
    /// tier: for a broad movement query, "Squat Jump" isn't inherently
    /// a better answer than "Barbell Back Squat" just because its name
    /// starts with the token. `nil` when the token doesn't match.
    func tier(for token: ExerciseSearchToken) -> Int? {
        if token.requiresWholeWord {
            return terms.contains(token.text) || stems.contains(token.stem) ? 1 : nil
        }
        if text == token.text || joined == token.text { return 0 }
        if text.hasPrefix(token.text) || terms.contains(token.text) { return 1 }
        if terms.contains(where: { $0.hasPrefix(token.text) }) { return 2 }

        // Match only ordinary English inflections here, such as
        // squat/squats, press/presses, and fly/flies. Typos are handled
        // separately by visible query correction.
        if stems.contains(token.stem) { return 1 }

        if text.contains(token.text) { return 3 }
        return nil
    }

    /// Best score for one token: tier first, then name before alias.
    func score(for token: ExerciseSearchToken) -> Int? {
        tier(for: token).map { $0 * 2 + source }
    }
}
