# Plan: Create README.md documenting the app + its real AI flows

Docs-only task — no source changes. No README currently exists in the repo.

## Target file
`/Users/arpitparekh/Documents/GitHub/AI_Journel_Repo/README.md` (repo root)

## Section outline (content sources in parentheses)

1. **Title + summary** — "AI Journal" — local-first journaling app: SwiftUI + SwiftData, iOS 26, on-device Apple Intelligence (Foundation Models) for auto-tagging and grounded Q&A. No network calls, no CloudKit, no accounts.
2. **Project structure** — brief tree of `AI_Journel/AI_Journel/`: `JournalEntry.swift` (model), `ContentView.swift` (list/add/detail), `View/AskView.swift` (Ask tab + MainTabView), `View/TagFlowLayout.swift` (tag pills), `Search/SemanticSearch.swift`, `AI_Helpers/AIEligibility.swift`.
3. **Data model** — `JournalEntry` (`timestamp: Date`, `body: String`, `tags: [String]`), SwiftData `@Model`, schema in `AI_JournelApp.swift`.
4. **Flow: how an entry gets AI tags** (the flow the user asked to document, from `ContentView.swift:133-159` + `AIEligibility.swift`):
   - Journal view → "+" → New Entry sheet → type → **Done** → `saveEntry()` fires.
   - Insert-first: `JournalEntry(tags: [])` is inserted and the sheet dismisses immediately — **saving is never blocked by AI**.
   - Tier guard: if `checker.tier` is not usable, AI is skipped (console log `[Journal] AI skipped — tier:`).
   - Async generation: `Task { @MainActor in … }` calls `generateSuggestions(for:checker:useEnhancedProcessing: false)`; on success prints `[Journal] AI tags: …` and sets `entry.tags`; on failure prints the error and leaves tags empty. Include the real code snippet (matches user's paste).
   - Under the hood (`AIEligibility.swift:104-120`): `LanguageModelSession(model: checker.taggingModel)` where `taggingModel = SystemLanguageModel(useCase: .contentTagging)`; include the **real** snippet — `return try await session.respond(to: "Summarize this journal entry in one sentence and suggest 2-4 topic tags: \(entryText)", generating: EntryAISuggestions.self)` — note: **no `.content`** in actual code (user's paste had it; document what's real).
   - Structured output: `@Generable struct EntryAISuggestions { oneLineSummary, suggestedTags }` — the model is schema-constrained to that shape. (Current flow stores only `suggestedTags`; summary is generated but unused.)
5. **AI feature inventory** (the "real AI stuff", with file references):
   - `AIEligibilityChecker` — runtime tiers `.unavailable(reason) / .textOnly / .fullMultimodal`, mapped from `SystemLanguageModel.availability` (Apple Intelligence off, model downloading, device not eligible); `PrivateCloudComputeLanguageModel` availability probe; token-budget estimate (`estimatedTokenCount`) + `shouldOfferEnhancedProcessing` (opt-in PCC for over-context entries).
   - **Ask screen (grounded Q&A, mini-RAG)** — `AskView.ask()`: `SemanticSearch.rankedMatches(for:from:k:5)` → filter `score >= 0.30` → honest "couldn't find relevant entries" message when empty → `LanguageModelSession(model: SystemLanguageModel(useCase: .general))` with a grounding prompt whose rules verbatim: answer ONLY from provided entries; if absent reply exactly "I don't have enough journal entries to answer that."; no outside knowledge/invention; cite entry dates like (18 Sep 2026). Sources section lists date + ~120-char excerpt + relevance score.
   - **Semantic search engine** — `SemanticSearch.swift`: `NLEmbedding.sentenceEmbedding(for: .english)` vectors, cosine similarity, top-k with per-entry embedding cache; public `retrieveTopMatches`/`rankedMatches`.
   - **Debug harness** — `DebugSearchView` (toolbar Debug menu) prints ranked matches + scores to the Xcode console.
6. **Running it** — iOS 26 simulator (deployment target raised from 18.5), Apple Intelligence–eligible; schema changed from template `Item` → `JournalEntry`, so a **fresh install** (delete old app from simulator) is required.

## Rules for the writer
- Snippets must be copy-pasted from the actual files (listed above), not paraphrased or "improved".
- Cite each feature with `file:line`-style references so the README stays verifiable.
- Keep sections 4-5 the meat; no roadmap/spec transcription beyond what's implemented.

## Validation
- All referenced files exist at cited paths.
- Snippets match source byte-for-byte (modulo markdown fencing).
- Markdown renders (headers, fences, list nesting).
