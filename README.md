# AI Journal

A local-first journaling app for iOS built with SwiftUI + SwiftData. Entries are plain text, and Apple Intelligence (the Foundation Models framework, on-device) provides automatic tag suggestions and a grounded "Ask your journal" Q&A experience.

- On-device only — no network calls, no external LLM APIs
- No CloudKit sync, no accounts, single user
- iOS 26+ (Foundation Models requires it)
## Data model

`JournalEntry.swift`:

```swift
@Model
final class JournalEntry {
    var timestamp: Date
    var body: String
    var tags: [String]

    init(timestamp: Date = .now, body: String = "", tags: [String] = []) {
        self.timestamp = timestamp
        self.body = body
        self.tags = tags
    }
}
```

## How an entry gets AI tags

Flow: **Journal view → "+" → New Entry sheet → type → Done button → `saveEntry()` → tags appear on the entry** (`ContentView.swift:133`).

`saveEntry()` inserts the entry first, then generates tags asynchronously — saving is never blocked by AI availability:

```swift
private func saveEntry() {
    let entry = JournalEntry(timestamp: .now, body: bodyText, tags: [])
    modelContext.insert(entry)
    dismiss()

    print("[Journal] saved entry: \(bodyText)")

    guard checker.tier.isUsable else {
        print("[Journal] AI skipped — tier: \(checker.tier)")
        return
    }

    let text = bodyText
    Task { @MainActor in
        do {
            let suggestions = try await generateSuggestions(
                for: text,
                checker: checker,
                useEnhancedProcessing: false
            )
            print("[Journal] AI tags: \(suggestions.suggestedTags)")
            entry.tags = suggestions.suggestedTags
        } catch {
            print("[Journal] AI tag generation failed: \(error)")
        }
    }
}
```

- The entry is persisted immediately with `tags: []`; the sheet dismisses without waiting.
- If the AI tier is not usable, generation is skipped and the entry simply keeps its empty tags.
- If generation fails, the error is logged and tags stay empty — the saved entry is unaffected.

### Where the tags come from

`generateSuggestions(for:checker:useEnhancedProcessing:)` in `AI_Helpers/AIEligibility.swift:104` runs a `LanguageModelSession` over the tagging-optimized model (`SystemLanguageModel(useCase: .contentTagging)`) with this prompt, which returns real, schema-constrained tags:

```swift
return try await session.respond(
    to: "Summarize this journal entry in one sentence and suggest 2-4 topic tags: \(entryText)",
    generating: EntryAISuggestions.self
)
```

The response is structured via `@Generable`, so the model is constrained to this shape rather than free text:

```swift
@Generable
struct EntryAISuggestions {
    let oneLineSummary: String
    let suggestedTags: [String]
}
```

The save flow currently stores only `suggestedTags` on the entry; `oneLineSummary` is generated but not persisted yet.

## AI features

### Availability checking — `AIEligibilityChecker` (`AI_Helpers/AIEligibility.swift`)

- Runtime tiers: `.unavailable(reason)`, `.textOnly`, `.fullMultimodal`, mapped from `SystemLanguageModel.availability` with plain-language reasons (Apple Intelligence off, model still downloading, device not eligible).
- `refresh()` re-checks availability; views call it in `.task { … }` on appear.
- Also probes `PrivateCloudComputeLanguageModel` availability and estimates token counts (`estimatedTokenCount(for:)`, `shouldOfferEnhancedProcessing(for:)`) for long entries. PCC is opt-in and currently unused by the save flow (`useEnhancedProcessing: false`).

### Ask screen — grounded Q&A (`View/AskView.swift`)

Single question in, single grounded answer out (no chat history, no streaming):

1. On submit, `SemanticSearch.rankedMatches(for:from:k:5)` ranks all entries against the question.
2. Matches below a **0.30 cosine-similarity threshold** are discarded. If nothing passes, the UI says so honestly ("I couldn't find journal entries relevant to this question, so I won't guess an answer.") instead of forcing an answer.
3. Surviving entries become numbered, dated context blocks in a prompt for `LanguageModelSession(model: SystemLanguageModel(useCase: .general))`. The grounding instruction (verbatim from `AskView.buildPrompt`):

   ```
   You are a helpful assistant answering a question about the user's personal journal.

   Rules:
   - Answer using ONLY the journal entries provided below. They are your entire source of truth.
   - If the entries do not contain the answer, reply exactly: "I don't have enough journal entries to answer that."
   - Do not use outside or general knowledge. Do not invent events, dates, people, or feelings.
   - Keep the answer brief and grounded, citing entry dates like (18 Sep 2026) where it helps.
   ```

4. A **Sources** section below the answer lists the entries actually used as context — date, ~120-character excerpt, and relevance score.
5. If Foundation Models is unavailable, the Ask button is disabled and the checker's plain-language reason is shown inline instead of a frozen UI.

### Semantic search — `Search/SemanticSearch.swift`

- `NLEmbedding.sentenceEmbedding(for: .english)` vectors for the query and each entry body.
- Cosine similarity ranking, top-k (`k = 5` default), with a per-entry embedding cache.
- Public API: `retrieveTopMatches(for:from:k:)` (entries only) and `rankedMatches(for:from:k:)` (entries + scores — used by Ask for threshold filtering).

### Debug harness — `DebugSearchView`

Journal toolbar → Debug menu → "Semantic Search Test…" runs a query and prints ranked matches with 4-decimal scores to the Xcode console.

## Running it

1. Open `AI_Journel/AI_Journel.xcodeproj` in Xcode; build for an **iOS 26 simulator**.
2. Apple Intelligence must be available/enabled for AI features; without it, saving still works — entries just get no tags and Ask shows the unavailable reason.
3. The schema changed from the Xcode template's `Item` to `JournalEntry` with no migration plan — **delete any previously installed build from the simulator** before launching, or `ModelContainer` init will fail.
