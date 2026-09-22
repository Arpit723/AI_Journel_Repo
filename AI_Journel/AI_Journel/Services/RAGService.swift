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

        let entryBlocks = matches.enumerated().map { index, match in
            let body = String(match.entry.body.prefix(400))
            return "[\(index + 1)] — \(dateFormatter.string(from: match.entry.timestamp))\n\"\(body)\""
        }.joined(separator: "\n\n")

        return """
        You are a helpful assistant answering a question about the user's personal journal.

        Rules:
        - Answer using ONLY the journal entries provided below. They are your entire source of truth.
        - If the entries do not contain the answer, reply exactly: "I don't have enough journal entries to answer that."
        - Do not use outside or general knowledge. Do not invent events, dates, people, or feelings.
        - Keep the answer brief and grounded, citing entry dates like (18 Sep 2026) where it helps.

        Journal entries:
        \(entryBlocks)

        Question: \(question)
        """
    }
}
