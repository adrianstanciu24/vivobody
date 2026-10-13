//
//  ExerciseSearchVocabulary.swift
//  vivobody
//
//  Shared lifter vocabulary for exercise search: equivalent phrases
//  ("single leg" = "one leg" = "SL"), equipment abbreviations, digits
//  written as words, and one-way broad terms ("unilateral" finds
//  single-leg and single-arm work). Terms that name one exercise belong
//  in that exercise's catalog aliases instead.
//
//  The table rewrites the query, not the catalog text. Adding the words
//  of "press up" to every push-up would make each "press" search list
//  push-ups; a query rewrite only applies when the whole phrase is typed.
//

nonisolated enum ExerciseSearchVocabulary {
    /// Each group lists phrases that mean the same thing. A query that
    /// contains one phrase also searches for each of the others.
    static let equivalentPhrases: [[String]] = [
        ["single leg", "one leg", "single legged", "one legged", "sl"],
        ["single arm", "one arm", "single armed", "one armed"],
        ["one", "1"],
        ["two", "2"],
        ["dumbbell", "db"],
        ["barbell", "bb"],
        ["kettlebell", "kb"],
        ["medicine ball", "med ball"],
        ["bodyweight", "body weight", "bw"],
        ["trx", "suspension"],
        ["romanian deadlift", "rdl"],
        ["stiff leg deadlift", "stiff legged deadlift", "sldl"],
        ["overhead press", "ohp"],
        ["leg curl", "hamstring curl"],
        ["leg extension", "quad extension"],
        ["calf raise", "heel raise"],
        ["skull crusher", "lying triceps extension"],
        ["farmer carry", "farmer walk"],
        ["close grip", "narrow grip"],
        ["rear delt", "rear deltoid"],
    ]

    /// One-way: a query with the term also searches for the phrases, but
    /// not the reverse. "Unilateral" covers arms and legs, so "single
    /// leg" must not find a single-arm exercise through it.
    static let broadTerms: [String: [String]] = [
        "unilateral": ["single leg", "one leg", "single arm", "one arm"],
    ]

    /// Synonym rewrites stop here so a query with many abbreviations
    /// cannot multiply into an unbounded number of searches.
    static let maximumAlternatives = 24

    /// Every word that the table knows, so typo correction accepts
    /// "ohp" or "sldl" even when no catalog name contains it.
    static let knownWords: Set<String> = {
        let phrases = equivalentPhrases.flatMap(\.self)
            + broadTerms.keys
            + broadTerms.values.flatMap(\.self)
        return Set(phrases.flatMap(ExerciseSearchText.words(of:)))
    }()

    /// The literal query first, then each distinct synonym rewrite. Two
    /// rounds let "1 leg" reach "single leg" through "one leg".
    static func alternatives(for tokens: [ExerciseSearchToken]) -> [[ExerciseSearchToken]] {
        var results = [tokens]
        var seen: Set<[String]> = [tokens.map(\.text)]
        var frontier = [tokens]
        for _ in 0 ..< 2 {
            var next: [[ExerciseSearchToken]] = []
            for candidate in frontier {
                for rewrite in rewrites(of: candidate) where seen.insert(rewrite.map(\.text)).inserted {
                    results.append(rewrite)
                    next.append(rewrite)
                    if results.count == maximumAlternatives { return results }
                }
            }
            frontier = next
        }
        return results
    }

    // MARK: - Rules

    private struct Rule {
        let phrase: [String]
        let replacement: [String]
    }

    /// Rules keyed by the first word of their phrase.
    private static let rules: [String: [Rule]] = {
        var rules: [String: [Rule]] = [:]
        func add(_ phrase: String, _ replacement: String) {
            let words = ExerciseSearchText.words(of: phrase)
            guard let first = words.first else { return }
            rules[first, default: []].append(
                Rule(phrase: words, replacement: ExerciseSearchText.words(of: replacement))
            )
        }
        for group in equivalentPhrases {
            for phrase in group {
                for replacement in group where replacement != phrase {
                    add(phrase, replacement)
                }
            }
        }
        for (term, phrases) in broadTerms {
            for phrase in phrases {
                add(term, phrase)
            }
        }
        return rules
    }()

    /// Every query that differs from `tokens` by one phrase replacement.
    private static func rewrites(of tokens: [ExerciseSearchToken]) -> [[ExerciseSearchToken]] {
        let texts = tokens.map(\.text)
        var rewrites: [[ExerciseSearchToken]] = []
        for start in texts.indices {
            for rule in rules[texts[start]] ?? [] where texts[start...].starts(with: rule.phrase) {
                let replacement = rule.replacement.map { ExerciseSearchToken($0, requiresWholeWord: true) }
                let end = start + rule.phrase.count
                rewrites.append(Array(tokens[..<start]) + replacement + Array(tokens[end...]))
            }
        }
        return rewrites
    }
}
