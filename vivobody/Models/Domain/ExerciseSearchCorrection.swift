//
//  ExerciseSearchCorrection.swift
//  vivobody
//
//  Typo correction for exercise search. A query word is corrected only
//  when no catalog word, word pair, or synonym contains it, and only to
//  a catalog word within a small edit distance. Callers show the
//  corrected query, so a correction never silently changes the results.
//

nonisolated struct ExerciseSearchCorrector {
    /// Words, word pairs, stems, and joined names that need no correction.
    private let knownTerms: Set<String>
    /// Correction targets with the number of exercises that use each one.
    private let candidates: [String: Int]

    init(fields: [[ExerciseSearchField]]) {
        var known = ExerciseSearchVocabulary.knownWords
        var candidates: [String: Int] = [:]
        for itemFields in fields {
            let terms = itemFields.reduce(into: Set<String>()) { $0.formUnion($1.terms) }
            for term in terms {
                candidates[term, default: 0] += 1
            }
            known.formUnion(terms)
            known.formUnion(itemFields.flatMap(\.stems))
            known.formUnion(itemFields.map(\.joined))
        }
        for word in ExerciseSearchVocabulary.knownWords where candidates[word] == nil {
            candidates[word] = 0
        }
        knownTerms = known
        self.candidates = candidates
    }

    /// The closest catalog word for an unknown token, or nil to keep it.
    func correction(for token: ExerciseSearchToken) -> String? {
        let limit = Self.editLimit(for: token.text)
        guard limit > 0, !isKnown(token) else { return nil }
        var best: Candidate?
        for (word, frequency) in candidates {
            guard let distance = ExerciseSearchText.editDistance(token.text, word, limit: limit) else {
                continue
            }
            let candidate = Candidate(word: word, distance: distance, frequency: frequency)
            if best.map(candidate.ranks(before:)) ?? true {
                best = candidate
            }
        }
        return best?.word
    }

    /// Words of three letters or fewer get no edits: one edit already
    /// reaches too many unrelated words. Words with digits are kept as typed.
    static func editLimit(for word: String) -> Int {
        guard word.allSatisfy(\.isLetter) else { return 0 }
        switch word.count {
        case ...3: return 0
        case ...7: return 1
        default: return 2
        }
    }

    private func isKnown(_ token: ExerciseSearchToken) -> Bool {
        knownTerms.contains(token.text)
            || knownTerms.contains(token.stem)
            || knownTerms.contains { $0.contains(token.text) }
    }

    /// Fewest edits first, then the word more exercises use, then
    /// alphabetical order, so the choice never depends on hash order.
    private struct Candidate {
        let word: String
        let distance: Int
        let frequency: Int

        func ranks(before other: Candidate) -> Bool {
            if distance != other.distance { return distance < other.distance }
            if frequency != other.frequency { return frequency > other.frequency }
            return word < other.word
        }
    }
}
