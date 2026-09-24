//
//  RAGService.swift
//  AI_Journel
//

import Foundation
import FoundationModels

enum RAGService {
    static let relevanceThreshold = 0.30

    static func relevantMatches(
        for question: String,
        from entries: [JournalEntry]
    ) -> [(entry: JournalEntry, score: Double)] {
        SemanticSearch.rankedMatches(for: question, from: entries, k: 5)
            .filter { $0.score >= relevanceThreshold }
    }

    static func generateAnswer(
        for question: String,
        matches: [(entry: JournalEntry, score: Double)]
    ) async throws -> String {
        let session = LanguageModelSession(model: SystemLanguageModel(useCase: .general))
        let response = try await session.respond(to: buildPrompt(question: question, matches: matches))
        return response.content
    }

    static func buildPrompt(question: String, matches: [(entry: JournalEntry, score: Double)]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let entryBlocks = matches.map { match in
            let body = String(match.entry.body.prefix(400))
            return "Entry from \(dateFormatter.string(from: match.entry.timestamp)): \(body)"
        }.joined(separator: "\n\n")

        return """
        You are a helpful assistant answering a question about the user's personal journal.

        Rules:
        - Answer using ONLY the journal entries provided below. They are your entire source of truth.
        - The journal entries below have already been identified as relevant to this question. Synthesize a brief, honest answer from them, even if the connection is thematic rather than a literal keyword match. Do not refuse to answer — if the entries only partially address the question, answer with what they do show and note the limitation in one sentence.
        - Do not use outside or general knowledge. Do not invent events, dates, people, or feelings.
        - Write your answer as 1-3 sentences of natural prose in your own words. Never copy an entry's text directly — always paraphrase and synthesize, even if only one entry is relevant.
        - Keep the answer brief and grounded, citing entry dates like (18 Sep 2026) where it helps.

        Example of a good answer: 'You've mentioned feeling motivated about starting new projects a few times this week, especially around September 22.' This is a paraphrase, not a copy of any single entry.

        Journal entries:
        \(entryBlocks)

        Question: \(question)
        """
    }
}
