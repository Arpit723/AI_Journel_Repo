//
//  EmbeddingService.swift
//  AI_Journel
//

import Foundation
import NaturalLanguage
import SwiftData

enum SemanticSearch {
    private static let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    private static var embeddingCache: [ObjectIdentifier: [Double]] = [:]

    static func embedding(for text: String) -> [Double]? {
        guard let sentenceEmbedding else { return nil }
        return sentenceEmbedding.vector(for: text)
    }

    static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return 0 }

        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for i in a.indices {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        guard normA > 0, normB > 0 else { return 0 }

        return dot / (normA * normB).squareRoot()
    }

    static func retrieveTopMatches(
        for query: String,
        from entries: [JournalEntry],
        k: Int = 5
    ) -> [JournalEntry] {
        rankedMatches(for: query, from: entries, k: k).map(\.entry)
    }

    static func rankedMatches(
        for query: String,
        from entries: [JournalEntry],
        k: Int = 5
    ) -> [(entry: JournalEntry, score: Double)] {
        guard k > 0, let queryVector = embedding(for: query) else { return [] }

        return entries
            .compactMap { entry -> (entry: JournalEntry, score: Double)? in
                let key = ObjectIdentifier(entry)
                let vector: [Double]
                if let cached = embeddingCache[key] {
                    vector = cached
                } else if let fresh = embedding(for: entry.body) {
                    embeddingCache[key] = fresh
                    vector = fresh
                } else {
                    return nil
                }
                return (entry, cosineSimilarity(queryVector, vector))
            }
            .sorted { $0.score > $1.score }
            .prefix(k)
            .map { $0 }
    }
}
