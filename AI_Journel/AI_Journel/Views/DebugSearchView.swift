//
//  DebugSearchView.swift
//  AI_Journel
//

import SwiftUI
import SwiftData

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
