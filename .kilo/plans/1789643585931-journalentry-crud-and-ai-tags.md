# Plan: JournalEntry model + real entry list/add/detail + AI tag wiring

Project root (nested!): `AI_Journel_Repo/AI_Journel/AI_Journel/…`
Do NOT modify: `AI_Helpers/AIEligibility.swift`, `View/TagFlowLayout.swift`.
pbxproj uses `PBXFileSystemSynchronizedRootGroup` → renaming/deleting files on disk needs **no pbxproj edits**.

## Step 0 — Build prerequisite
pbxproj currently has `IPHONEOS_DEPLOYMENT_TARGET = 18.5` (4 build configs), but `AIEligibility.swift` imports FoundationModels (iOS 26+). Bump all four to `26.0` in `AI_Journel.xcodeproj/project.pbxproj`. If the project already compiles as-is, verify and skip.

## Step 1 — Model: Item → JournalEntry
- Delete `Item.swift`; create `JournalEntry.swift`:

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

- `AI_JournelApp.swift`: Schema becomes `Schema([JournalEntry.self])`.

## Step 2 — ContentView.swift rewrite
Single `NavigationStack` (iPhone app, no split view):

- `@Query(sort: \JournalEntry.timestamp, order: .reverse)` → most recent first.
- Row: VStack(leading) — timestamp (`.caption`, `.secondary`), body preview (`.lineLimit(2)`), and if `!entry.tags.isEmpty`: `TagPillRow(tags: entry.tags.map { TagPillData(label: $0, isAISourced: true) })` — all stored tags are AI-sourced in this task, so purple pill + sparkles glyph is correct provenance.
- `.onDelete` swipe delete kept.
- Empty state: `ContentUnavailableView("Start Your Journal", systemImage: "book.closed", description: …)` with a "Write First Entry" button opening the sheet.
- Toolbar `+` → `.sheet` presenting `AddEntryView`.
- `.task { checker.refresh() }` — tier starts as `.unavailable("Checking…")`; without `refresh()` every save would skip AI.

### AddEntryView (in same file)
- `@State private var bodyText = ""`, `TextEditor(text: $bodyText)`, toolbar Cancel (dismiss) / Done (`saveEntry`, disabled when `bodyText.trimmed.isEmpty`).
- Save flow (insert-first — saving is never blocked by AI):
  1. `let entry = JournalEntry(timestamp: .now, body: bodyText, tags: [])`
  2. `modelContext.insert(entry)` then `dismiss()` — entry persists immediately.
  3. `guard checker.tier.isUsable else { return }` (entry stays saved, tags stay empty).
  4. `Task { @MainActor in` → `try await generateSuggestions(for: bodyText, checker: checker, useEnhancedProcessing: false)` → on success `entry.tags = suggestions.suggestedTags`; on any throw, leave `tags` empty. No alert — failure is silent, entry unaffected.
  - `useEnhancedProcessing: false` — PCC is opt-in default-off (spec §1.6) and no Settings screen exists yet.

### EntryDetailView (in same file)
Read-only: formatted absolute date (`.caption`, `.secondary`), full body (`.body`), `TagPillRow` same mapping. Reachable via `NavigationLink` from each row.

### Preview
`#Preview` updated to `.modelContainer(for: JournalEntry.self, inMemory: true)`.

## Out of scope (per task)
No photos/voice/rich text, no CloudKit/auth, no semantic search, no pattern surfacing, no edit-in-place, no summary storage — **`oneLineSummary` is generated but deliberately discarded** (no field for it in this task's model).

## Data migration note
Item → JournalEntry is a schema break with no `VersionedSchema`/migration plan. An existing simulator store from the template app will fail `ModelContainer` init → `fatalError`. Expected and acceptable: fresh install required (delete app from simulator).

## Validation
Build:
```
xcodebuild -project AI_Journel/AI_Journel.xcodeproj -scheme AI_Journel \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```
(adjust simulator name to an installed iOS 26 runtine device)

Manual simulator checks (5, in order):
1. **Fresh install**: delete the app icon from the simulator first, then launch → must NOT crash with "Could not create ModelContainer". Why it breaks: old Item-based store on disk is incompatible with the new JournalEntry schema.
2. **Save with AI unavailable** (Settings → Apple Intelligence off, or model still downloading): type text → Done → entry appears instantly in the list with NO tag pills, no spinner, no error dialog. Why: insert-first flow must never block on `generateSuggestions` throwing `.unavailable`.
3. **Save with AI available**: write 3–4 real sentences → Done → entry appears with no pills, then 2–4 purple pills with the sparkles glyph pop in a beat later (async generation). If >3 tags, verify the `+N` overflow pill from `TagPillRow`. Why: async mutation of an already-inserted @Model only shows up if the list re-renders.
4. **Ordering + persistence**: add a second entry → newest must be at the top; force-quit and relaunch → both entries still there with their tags. Why: reverse-sorted @Query and on-disk persistence.
5. **Detail + flow layout**: tap an entry → full body, absolute date, same pills; then Settings → Accessibility → larger text sizes → pills must wrap to a second line (TagFlowLayout) instead of truncating or overflowing the row.
