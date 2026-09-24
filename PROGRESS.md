# AI_Journel — Progress

*Grounded in a verification pass against the actual code + a clean build on
2026-09-23. Maintained per `.kilocode/rules/progress-tracking.md`.*

## Status

**Confirmed fully working** (code exists, builds clean — `** BUILD SUCCEEDED **`
on 2026-09-23 — and/or runtime-confirmed by the developer):
- Plain-text CRUD: create (New Entry sheet), edit (Edit toolbar in detail →
  pre-filled `EntryEditorView`), delete (swipe), reverse-sorted list
  (`Views/Journal/JournalListView.swift`).
- On-device auto-tagging on save — create and edit paths, via
  `generateSuggestions()` (`Services/AIEligibility.swift:104`); saving never
  blocked by AI availability; failed/unavailable generation keeps existing tags.
- Semantic retrieval: NLEmbedding + cosine similarity with caching
  (`Services/EmbeddingService.swift`) — developer-verified via console harness.
- Ask/RAG screen (`Views/Ask/AskView.swift` + `Services/RAGService.swift`):
  k=5 retrieval, 0.30 relevance threshold, grounded prompt with forced fallback
  sentence, Sources list, AI-unavailable messaging.
- Kilo rules: `project-context.md`, `restricted_files.md`,
  `progress-tracking.md` all present in `.kilocode/rules/`.

**Implemented but not runtime-verified by the developer** (compiles; behavior
verified only by code inspection):
- Tag-frequency pattern view (`Views/Patterns/TagFrequencyView.swift`, third
  "Patterns" tab): per-tag entry counts sorted highest-first, with empty-state
  messages for zero entries and zero tags.
- Edit-save skip optimization: tags are NOT regenerated when edited text is
  unchanged (`EntryEditorView.swift:93` guard, trimmed compare before mutation).
- Edit flow details after the re-apply: no duplicate rows on edit, original
  timestamp preserved, detail screen refresh after edit save.

**Not started:**
- End-user Search screen (semantic engine exists but is reachable only through
  the temporary Debug harness).
- Tags/Browse management, Related Entries, Settings (AI status row, PCC opt-in),
  multimodal, iPad layout.

## Known Issues

1. **README.md is stale** — documents the pre-reorganization flat layout,
   `AddEntryView`, and `ContentView.swift` paths that no longer exist.
2. **Deployment target is 27.0** (all 6 pbxproj configs), while task prompts
   usually say "iOS 26.0" — harmless drift, but confusing.
3. **Type names ≠ file names**: `ContentView` lives in `JournalListView.swift`;
   the `SemanticSearch` enum lives in `EmbeddingService.swift`.
4. **`DebugSearchView` is a temporary harness** (Journal toolbar → Debug menu) —
   must be removed before any release build.
5. **`oneLineSummary` is generated but never persisted** — `JournalEntry` has no
   field for it.
6. **No SwiftData migration plan** — any schema change requires deleting the app
   (fresh install).
7. Edit-entry, skip-regeneration, and pattern-view behaviors still need their
   manual simulator checks (see "Implemented but not runtime-verified").

## Next Task

**End-user Search screen** — keyword mode first, then semantic using the existing
`SemanticSearch` engine (currently reachable only through the temporary Debug
harness). Spec build-order step 6; the retrieval pipeline is already done and
verified.

## Completed Log

*(Dates inferred from file headers and task history; one line per feature.)*

- **2026-09-17** — SwiftData model `Item` → `JournalEntry` (timestamp/body/tags)
  + journal list/add-sheet/detail screens + AI tag wiring on save.
- **2026-09-17/18** — Semantic search/retrieval (`SemanticSearch`, NLEmbedding +
  cosine, k=5) with `DebugSearchView` console harness; retrieval verified.
- **2026-09-18/22** — Ask/RAG screen: grounded Q&A, 0.30 threshold, Sources UI,
  `MainTabView` Journal/Ask tabs; later refactored into `RAGService`.
- **2026-09-22** — Repo-root `README.md` created (now stale post-reorg).
- **2026-09-22** — Entry editing: dual-mode `EntryEditorView`, Edit entry point in
  detail view, in-place mutation, tag regeneration with keep-on-failure.
- **2026-09-22** — File reorganization into `Models/ Views/ Services/`
  (Journal/Ask/Components subfolders); search split into `EmbeddingService` +
  `RAGService`; deployment target raised to 27.0.
- **2026-09-22** — `.kilocode/rules/`: `project-context.md` (architecture ground
  truth) and `restricted_files.md` (AIEligibility + EmbeddingService locked).
- **2026-09-23** — Optimization: edit-save skips tag regeneration when text
  unchanged; build verified.
- **2026-09-23** — Added `progress-tracking.md` rule; created and seeded
  `PROGRESS.md`; restructured it after full code-verification pass + clean build.
- **2026-09-23** — Tag-frequency pattern view: `Views/Patterns/TagFrequencyView.swift`
  (per-tag entry counts, sorted highest-first, empty states) + third "Patterns"
  tab in `MainTabView`; `.kilocode/` added to `.gitignore`; build verified.
- **2026-09-24** — Added `[Ask]` console logging to the Ask flow: question,
  retrieval match count + per-match scores, no-match refusals, answers, and
  generation errors. Build verified.
- **2026-09-24** — Reworked `RAGService.buildPrompt()` to stop the model echoing
  input blocks: plain-prose entry format ("Entry from <date>: <body>", no
  brackets/quotes/numbering), explicit 1-3-sentence paraphrase rule, and a
  one-shot good-answer example; grounding rules and fallback sentence unchanged.
- **2026-09-24** — Moved the refusal decision from prompt to code: empty
  `relevantMatches()` → UI shows the exact fallback sentence and the model is
  never called; non-empty → prompt now assumes relevance and forbids refusing
  (answers with partial coverage + one-sentence limitation instead).
