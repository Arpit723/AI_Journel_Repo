//
//  SemanticSearch.swift
//  AI_Journel
//

import Foundation
import NaturalLanguage
import SwiftData
import SwiftUI

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

// MARK: - Debug harness (temporary)

struct DebugSearchView: View {
    @Query private var entries: [JournalEntry]
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Query, e.g. stressful week at work", text: $query)
                Button {
                    runSearch()
                } label: {
                    Label("Run Search", systemImage: "wand.and.stars")
                }
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Results print to the Xcode console.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Semantic Search Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func runSearch() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let ranked = SemanticSearch.rankedMatches(for: trimmedQuery, from: entries, k: 5)

        print("[SemanticSearch] query: \"\(trimmedQuery)\"")
        print("[SemanticSearch] \(entries.count) entries searched, \(ranked.count) returned (k=5)")

        for (index, match) in ranked.enumerated() {
            let flatBody = match.entry.body.replacingOccurrences(of: "\n", with: " / ")
            print("[SemanticSearch] #\(index + 1)  score=\(String(format: "%.4f", match.score))  \(match.entry.timestamp.formatted(date: .abbreviated, time: .shortened))")
            print("[SemanticSearch]     \"\(flatBody)\"")
        }
    }
}
