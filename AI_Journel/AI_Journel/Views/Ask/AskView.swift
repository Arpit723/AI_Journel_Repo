//
//  AskView.swift
//  AI_Journel
//

import SwiftUI
import SwiftData

struct SourceSnippet: Identifiable {
    let id = UUID()
    let date: Date
    let excerpt: String
    let score: Double
}

struct AskView: View {
    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var entries: [JournalEntry]
    @State private var checker = AIEligibilityChecker()
    @State private var question = ""
    @State private var answer: String?
    @State private var sources: [SourceSnippet] = []
    @State private var isLoading = false
    @State private var noRelevantMatches = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ask your journal a question…", text: $question, axis: .vertical)
                        .lineLimit(2...5)
                        .onSubmit(ask)
                    Button {
                        ask()
                    } label: {
                        Label("Ask", systemImage: "sparkles")
                    }
                    .disabled(trimmedQuestion.isEmpty || isLoading || !checker.tier.isUsable)
                }

                if let unavailableReason {
                    Section {
                        Label(unavailableReason, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                }

                if isLoading {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Thinking…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if noRelevantMatches {
                    Section {
                        Label(
                            "I don't have enough journal entries to answer that.",
                            systemImage: "magnifyingglass"
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                if let answer {
                    Section("Answer") {
                        Text(answer)
                    }

                    if !sources.isEmpty {
                        Section("Sources") {
                            ForEach(sources) { source in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.date, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(source.excerpt)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                    Text("relevance \(String(format: "%.2f", source.score))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ask")
            .task {
                checker.refresh()
            }
        }
    }

    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var unavailableReason: String? {
        if case .unavailable(let reason) = checker.tier {
            return reason
        }
        return nil
    }

    private func ask() {
        let text = trimmedQuestion
        guard !text.isEmpty, checker.tier.isUsable, !isLoading else { return }

        answer = nil
        sources = []
        noRelevantMatches = false
        errorMessage = nil
        isLoading = true

        print("[Ask] question: \"\(text)\" — searching \(entries.count) entr\(entries.count == 1 ? "y" : "ies")")

        Task { @MainActor in
            let relevant = RAGService.relevantMatches(for: text, from: entries)

            print("[Ask] retrieval: \(relevant.count) match(es) at or above threshold \(String(format: "%.2f", RAGService.relevanceThreshold))")
            for (index, match) in relevant.enumerated() {
                print("[Ask]   #\(index + 1) score=\(String(format: "%.4f", match.score))  \(match.entry.timestamp.formatted(date: .abbreviated, time: .shortened))")
            }

            guard !relevant.isEmpty else {
                print("[Ask] no relevant matches — refusing to answer")
                isLoading = false
                noRelevantMatches = true
                return
            }

            do {
                let generated = try await RAGService.generateAnswer(for: text, matches: relevant)
                print("[Ask] answer: \"\(generated)\"")
                answer = generated
                sources = relevant.map { match in
                    SourceSnippet(
                        date: match.entry.timestamp,
                        excerpt: excerpt(of: match.entry.body),
                        score: match.score
                    )
                }
                print("[Ask] showing \(sources.count) source(s) in the UI")
            } catch {
                print("[Ask] answer generation failed: \(error)")
                errorMessage = "Couldn't generate an answer. Please try again."
            }
            isLoading = false
        }
    }

    private func excerpt(of body: String, limit: Int = 120) -> String {
        guard body.count > limit else { return body }
        return body.prefix(limit).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

#Preview {
    AskView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
