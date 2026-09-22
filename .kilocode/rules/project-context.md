# AI_Journel — Project Context (rules)

Ground truth for the current state of this repo, verified against the actual code.
When code changes in ways that alter architecture or conventions, update this file
in the same task.

## Product

AI_Journel — local-first, single-user, plain-text journal for iOS with on-device
Apple Intelligence (Foundation Models): auto-tagging on save, semantic retrieval,
and a grounded Ask/Q&A screen.

## Scope constraints (hard rules)

- **On-device only** — no network calls, no external LLM APIs, no server components.
- **Plain-text entries only** — no photos, no voice-to-text, no rich text.
- **No CloudKit sync, no authentication, no multi-user support.**
- **Pattern surfacing: NOT BUILT.** When added, it must be simple tag-frequency
  counting only — no trend analysis, no sentiment analysis.
- No undo/version history for entries — simple overwrite-on-save.
- Ask screen: single question in, single grounded answer out — no chat history,
  no streaming responses.

## Architecture (verified 2026-09-22)

```
AI_Journel/AI_Journel/
├── AI_JournelApp.swift          # @main; ModelContainer with Schema([JournalEntry.self]);
│                                #   no VersionedSchema/migration plan → schema change = fresh install
├── Models/
│   └── JournalEntry.swift       # @Model final class: timestamp: Date, body: String, tags: [String]
├── Services/
│   ├── AIEligibility.swift      # AIEligibilityChecker (tier .unavailable/.textOnly/.fullMultimodal,
│   │                            #   taggingModel = SystemLanguageModel(useCase: .contentTagging))
│   │                            #   + generateSuggestions(for:checker:useEnhancedProcessing:)
│   │                            #   → @Generable EntryAISuggestions (oneLineSummary, suggestedTags)
│   ├── EmbeddingService.swift   # enum SemanticSearch: NLEmbedding sentence embeddings, cosineSimilarity,
│   │                            #   rankedMatches/retrieveTopMatches (k default 5), embedding cache
│   └── RAGService.swift         # relevantMatches (k=5, relevanceThreshold = 0.30), generateAnswer,
│                                #   buildPrompt (grounded Q&A prompt)
└── Views/
    ├── MainTabView.swift        # TabView: "Journal" tab (ContentView) + "Ask" tab (AskView)
    ├── DebugSearchView.swift    # TEMPORARY console debug harness for SemanticSearch
    │                            #   (Journal toolbar → Debug menu)
    ├── Journal/
    │   ├── JournalListView.swift  # struct ContentView (type name ≠ file name): reverse-sorted
    │   │                          #   @Query list, add sheet, swipe delete; EntryRowView also here
    │   ├── EntryEditorView.swift  # EntryEditorView: create (entry == nil) + edit (entry passed,
    │   │                          #   body pre-filled); saveEntry branches to createEntry/updateEntry
    │   └── EntryDetailView.swift  # read-only display + Edit toolbar item → editor sheet;
    │                              #   takes checker as a parameter
    ├── Ask/
    │   └── AskView.swift          # grounded Q&A UI: question field, loading, answer,
    │                              #   Sources (date + excerpt + score), AI-unavailable message
    └── Components/
        └── TagFlowLayout.swift    # TagFlowLayout (Layout), TagPillData, TagPill, TagPillRow
                                   #   (max 3 visible + "+N" overflow)
```

Build facts: iOS deployment target **27.0** (all configurations), Swift 5 mode,
bundle id `com.bk.AI-Journel`, pbxproj uses fileSystemSynchronizedGroups (adding,
moving, or renaming source files requires **no** .xcodeproj edits).

## Conventions (follow in new code)

### AI availability
- Any view using AI owns `@State private var checker = AIEligibilityChecker()`
  and calls `checker.refresh()` in `.task { … }`.
- Gate on `checker.tier.isUsable`. If unusable: disable/de-emphasize the action and
  show the checker's plain-language reason — never crash, never hang.

### Saving entries (critical rule)
- **Saving an entry must never be blocked by AI availability or failure.**
- Create: insert `JournalEntry(timestamp: .now, body: text, tags: [])` into the
  context and dismiss FIRST; then `guard checker.tier.isUsable`; then
  `Task { @MainActor in … }` calls
  `generateSuggestions(for: text, checker: checker, useEnhancedProcessing: false)`;
  on success set `entry.tags = suggestions.suggestedTags`; on failure log and
  leave tags empty. The sheet never waits for generation.
- Edit: mutate `entry.body` in place — do **not** call `modelContext.insert` on an
  existing entry (insert is the create-only path; mutation persists automatically).
  Regenerate tags from the new text and replace ONLY on success; if AI is
  unavailable or generation throws, KEEP the existing tags.
- Preserve the original `timestamp` on edit so edits don't reorder the journal.
- `useEnhancedProcessing` is always `false` (Private Cloud Compute is opt-in and
  not wired into any UI).
- `oneLineSummary` is generated but not persisted — the model has no field for it.

### RAG / Ask
- Retrieval: `RAGService.relevantMatches(for:from:)` (k=5, cosine threshold 0.30).
  Empty result → show the honest "couldn't find relevant entries" message; never
  answer from irrelevant entries.
- Answer: `RAGService.generateAnswer`. The prompt forbids outside knowledge and
  forces the exact fallback sentence "I don't have enough journal entries to
  answer that."
- The Sources list shown in the UI must be the exact matches passed to the prompt.

### Misc
- Tag pills: `TagPillRow(tags: entry.tags.map { TagPillData(label: $0, isAISourced: true) })`
  — AI-sourced styling is correct for all current tags.
- Console logs use `[Journal] …` / `[SemanticSearch] …` prefixes.
- Xcode previews use `.modelContainer(for: JournalEntry.self, inMemory: true)`.

## Known inconsistencies / drift (flagged, not fixed)

1. **Deployment target is 27.0**, not "iOS 26.0" as often stated in task prompts.
   Foundation Models requires the raised target.
2. **Type names ≠ file names** (legacy template names): `ContentView` is defined
   in `JournalListView.swift` and referenced by `MainTabView`; the `SemanticSearch`
   enum lives in `EmbeddingService.swift`; `DebugSearchView` sits directly under
   `Views/` (not in a subfolder).
3. **No `Views/Patterns/` folder exists** — pattern surfacing is future work
   (tag-frequency only when built).
4. **README.md at the repo root is stale**: documents the pre-reorganization flat
   layout, `AddEntryView`, and `ContentView.swift` paths that no longer exist.
5. `DebugSearchView` is a temporary harness wired into the Journal toolbar Debug
   menu — remove before any release build.
