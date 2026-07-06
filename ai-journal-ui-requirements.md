# AI Journal / Second Brain — UI Requirements

*Local-first journaling app with on-device AI (Apple's Foundation Models framework) for tagging, summarization, and semantic search. This version adds implementation-level detail — exact component specs, state machines, design tokens — and reflects the Foundation Models / SwiftData updates announced at WWDC 2026.*

**Scope note:** Backlinking (`[[entry references]]`) and a Graph View screen were discussed as an "Obsidian-style" differentiator but are explicitly **out of scope**. This spec stays focused on AI-native journaling — auto-tagging, summarization, semantic search — not manual note-linking.

---

## 0. Technical Grounding

A few framework changes shipped since the original draft of this spec, and they change what's realistic to build:

- **Foundation Models framework** (introduced iOS 26, significantly expanded at WWDC 2026 / iOS 27): the on-device model now accepts **multimodal image input** alongside text. This changes what your "AI suggest" flow can do with photo attachments — but image input requires a higher-tier on-device model, so device eligibility now has three tiers instead of two (see §5).
- **Built-in semantic search**: the framework ships a semantic search primitive you index your own content into, rather than hand-rolling an embeddings pipeline on Core ML. This makes the Search screen (§1.4) and Related Entries (§1.3) considerably more feasible to actually ship solo.
- **Context/token inspection APIs** (added in iOS 26.4, with related tooling expanded at WWDC 2026): you can check how much of the model's context window a prompt will consume before sending it — relevant for long journal entries (§1.2).
- **Free Private Cloud Compute (PCC) access** for developers with under 2M first-time downloads — a realistic, cost-free fallback for entries too long for the on-device context window, if you choose to offer it. It's a genuine privacy trade-off, not a free upgrade (see §1.6).
- **SwiftData (iOS 27)**: sectioned `@Query` fetches, `ResultsObserver` / `HistoryObserver` for observing store changes outside SwiftUI views, and compound/enum predicates. CloudKit sync remains **private-database-only** (no shared/multi-user sync) — which is exactly the right fit here, since a journal is inherently single-user.

---

## 1. Core Screens

### 1.1 Entry List (Home)

**Structure**
- `NavigationStack` → `List` backed by a sectioned `@Query` (iOS 27's `sectionBy` parameter), grouped into `Today / Yesterday / This Week / Earlier` with sticky section headers — no manual date-bucketing code needed.
- Large-title nav title "Journal," collapsing to inline on scroll.
- Search bar via `.searchable(text:)`, placed below the nav title.
- Filter chip row (`All / Starred / Tagged / This Week`) implemented as compound `#Predicate` filters passed into the `@Query` — filtering happens at the store level, not by fetching everything and filtering in memory.

**Entry Card — exact spec**

| Element | Spec |
|---|---|
| Outer padding | 16pt horizontal, 12pt vertical |
| Date/time | `.caption` (12pt), `.secondary`; relative ("2h ago") by default, absolute on long-press via a toggled `@State` bool |
| Content preview | `.body` (17pt), `.lineLimit(3)`, `.foregroundStyle(.primary)` |
| AI summary line | `.footnote` (13pt), italic, `.secondary`, prefixed with a small `sparkles` SF Symbol at 11pt to flag AI origin inline |
| Tag pills | `Capsule` shape, 10pt horizontal padding, 4pt vertical, `.caption` text, background `Color.accentColor.opacity(0.15)`, foreground `Color.accentColor`; max 3 visible, then a `+N` pill |
| Tag pill spacing | 8pt between pills, wrapped via a flow layout (SwiftUI `Layout` protocol — a good custom-layout exercise) |
| Mood/sentiment dot | 8pt circle, trailing-aligned next to the date |

**States**

| State | UI Treatment |
|---|---|
| Empty (no entries) | `ContentUnavailableView`: `book.closed` icon, "Start Your Journal" headline, one-line subtext, "Write First Entry" button |
| Initial load / CloudKit sync | 3–4 skeleton cards matching real card height (prevents layout jump), shimmer via `.redacted(reason: .placeholder)` |
| Background sync in progress | Small `arrow.triangle.2.circlepath` in the nav bar trailing slot, rotating; never blocks interaction |
| Sync error | Icon swaps to `exclamationmark.icloud`; tap reveals a sheet with the error and a manual retry button |
| Offline | Thin dismissible banner under the nav bar: "Offline — changes will sync when you're back online" |
| Search in progress | Inline `ProgressView`, small, trailing in the search bar — distinct from full-screen sync loading |

**Interactions**
- Tap → Entry Detail (`.navigationDestination`)
- Swipe leading → star (`star.fill`, yellow), non-destructive, no confirmation
- Swipe trailing → delete (`trash.fill`, red); `allowsFullSwipe: false` so an accidental full swipe can't delete without the explicit confirm `.alert`
- Long-press → `.contextMenu`: Delete (destructive, below a `Divider()`), Star, Share, Copy, Regenerate AI Tags
- Pull-to-refresh → manual CloudKit sync (`.refreshable`)
- "+" in nav bar trailing → New Entry, presented as `.sheet` (not push), so Cancel/Done reads naturally

---

### 1.2 New/Edit Entry

**Structure**
- `TextEditor` bound directly to the model's content property, `.scrollContentBackground(.hidden)` so it inherits the app background instead of the system default.
- Top bar via `.toolbar`: `.cancellationAction` (Cancel), `.confirmationAction` (Done), `.principal` for the centered timestamp (`.caption`, `.secondary`).
- Bottom keyboard-accessory toolbar: photo picker, mic (dictation), manual tag, and AI-suggest (`sparkles`) icons — each a minimum 44×44pt tap target, 24pt spacing between icons.

**AI Integration — three-tier behavior (full matrix in §5)**

1. **Full multimodal tier** (newer/high-end hardware, `SystemLanguageModel` reports image input available): tapping "suggest" analyzes both entry text *and* attached photos. Tags derived from photo content get a subtly different tint/icon (a small `photo` glyph on the pill) than text-derived tags, so provenance is visible at a glance.
2. **Text-only tier** (Foundation Models available, image input not): "suggest" works normally for text tagging/summarization; photos still attach and display fine, they just don't generate their own tags. No error shown — that path silently doesn't fire.
3. **Unavailable tier** (Apple Intelligence off, unsupported region/device): the `sparkles` icon stays visible but de-emphasized (reduced opacity); tapping it opens a short explanation sheet instead of attempting a call. **Saving an entry is never blocked by AI unavailability.**

**Generation states**
- Idle → only the suggest icon visible
- Generating → shimmer placeholder pills below the text, non-blocking (user can keep typing)
- Generated → pills animate in (`.spring(response: 0.35, dampingFraction: 0.8)`), each dismissible via a small `xmark` on tap
- Failed → one small inline retry affordance, no modal — a failed suggestion is low-stakes and shouldn't interrupt writing

**Long-entry handling**
- Before calling the model, estimate token count against the on-device context window using the framework's context inspection APIs.
- If an entry will likely exceed it: show an inline notice — *"Long entry — summary will focus on the beginning"* — with an optional *"Use enhanced processing for this entry"* action if Private Cloud Compute fallback is enabled in Settings, instead of silently truncating.

**Autosave**
- No explicit save button for edits — SwiftData's `ModelContext` autosave handles persistence; a small "Saved" checkmark fades in for ~1.5s after each autosave tick.
- Debounce AI re-suggestion ~600ms after the last keystroke so the model isn't called on every character.
- New entries: if the app backgrounds mid-draft, the draft persists (it's already a `@Model` instance in the context, just not yet committed via Done).

---

### 1.3 Entry Detail

Read-only view; the pencil icon moves to edit mode (New/Edit Entry, pre-populated) — detail and edit are deliberately separate states, not one always-editable view.

**Layout**
- Header: absolute date/time, optional word count
- Body: rendered content (if supporting a markdown-lite subset — bold/lists — use `AttributedString(markdown:)`)
- Tag pills (same spec as §1.1), tappable → filtered Entry List for that tag
- **AI Summary card**: background `Color.accentColor.opacity(0.08)`, 1pt stroke `Color.accentColor.opacity(0.2)`, 12pt corner radius, 16pt internal padding; small `Capsule` badge top-trailing with `sparkles` + "AI" text at `.caption2`; collapsed by default past ~2 lines, chevron toggle with a spring rotation
- **Related Entries**: horizontal `ScrollView`, up to 3 cards (~140pt wide), each with a one-line "why this matched" caption (`.caption2`, `.secondary`, capped ~12 words — avoid a raw numeric relevance score, it overstates precision the user can't act on). *This stays automatic and read-only — no manual linking, no graph, per the scope note above.*
- Attachments: grid layout, tap → full-screen viewer with swipe-to-dismiss

**Accessibility**
- VoiceOver announces the AI badge *before* the summary text ("AI generated summary: ...") so screen-reader users get the same provenance cue sighted users get from the badge.

---

### 1.4 Search

**Structure**
- Auto-focused search field on entry
- Mode toggle: `Keyword / Smart`, defaulting to Smart — backed by the framework's built-in semantic search primitive rather than a custom vector index. This is the single biggest scope reduction since the original draft — no separate embeddings-pipeline milestone needed.
- Results reuse the Entry Card component (§1.1), with the matching snippet highlighted in keyword mode

**States**

| State | Treatment |
|---|---|
| Empty query | Recent searches + tag shortcuts |
| First-time semantic indexing | Non-blocking banner: "Indexing entries for smart search — 42 of 130." Keyword search still works immediately, since it doesn't depend on the index |
| Searching | Skeleton results (reuse §1.1's skeleton), search field stays interactive |
| No keyword matches | *"No entries contain that phrase"* |
| No semantic matches | *"Nothing seems related to that yet"* — deliberately different copy, since the two cases mean different things to the user |

---

### 1.5 Tags/Browse

- List or grid of tags with entry counts, sortable by frequency or alphabetically (straightforward with iOS 27's sectioned queries)
- Tap → filtered Entry List
- Manage: rename, merge, delete — merge and delete both show a confirmation sheet stating the exact affected count ("12 entries will move from 'travel' to 'trips'") before committing

---

### 1.6 Settings

**iCloud Sync section**
- Account status, last synced timestamp, manual "Sync Now," storage usage
- Footnote clarifying sync is to the user's own private iCloud database (not shared) — the correct fit for a personal journal, and simpler than solving multi-user sync

**AI Features section** — needs more than a single on/off toggle:

| Row | Behavior |
|---|---|
| On-device AI (master toggle) | Enables/disables auto-tagging + summarization entirely |
| Model status (read-only) | Reflects `SystemLanguageModel` availability in plain language: "Text tagging: Available" / "Photo analysis: Not available on this device" / "Apple Intelligence: Off — enable in Settings" |
| Use Private Cloud Compute for long entries (opt-in, default **off**) | Footnote explaining this routes only oversized entries to Apple's Private Cloud Compute — stateless, independently verifiable, not stored — instead of truncating on-device. **A genuine privacy trade-off, not a free upgrade** — worth a deliberate default-off rather than defaulting on, since "fully on-device" is a real selling point of the app as spec'd |

**Other sections** (unchanged): Appearance (theme, font size), Export/Backup (JSON/Markdown/PDF), Security (Face ID lock, auto-lock timer), About

---

## 2. Design System

### 2.1 Typography (Dynamic Type — non-negotiable)

| Role | Style | Used for |
|---|---|---|
| Screen titles | `.largeTitle` / `.title` (collapsed) | Nav bar |
| Entry content | `.body` | Editor + detail body text |
| Metadata | `.caption` | Timestamps, word counts |
| AI-generated text | `.footnote`, italic | Summaries, "why this matched" |
| Tag pills | `.caption` | All tag chips |

Test every screen at the largest accessibility text sizes early — tag-pill wrapping and the Entry Card layout are the two things most likely to break first.

### 2.2 Color Roles (named colors in the Asset Catalog, not raw hex in views)

| Token | Purpose |
|---|---|
| `entryBackground` | Card / editor background |
| `aiAccent` | AI badge, AI summary card tint, AI-sourced tag pills |
| `tagBackground` / `tagForeground` | Manual (non-AI) tag pills |
| `syncPending` / `syncError` | Sync status icon tinting |

Keeping AI-sourced content on a visually distinct token — rather than reusing your general accent color — is what makes the "this came from AI" language legible at a glance. Decide this before building screens, not after.

### 2.3 Spacing (8pt grid)
`4 / 8 / 12 / 16 / 24 / 32` — pick from this set for all padding/spacing; avoid arbitrary values like 10pt or 14pt creeping in screen by screen.

### 2.4 Micro-interactions & Haptics
- AI tags finish generating → light `.notification(.success)` haptic
- Swipe action reveal → `.impact(.light)`
- Filter chip selection → `.selection`
- Delete confirmation → `.impact(.medium)` on the destructive button only, not on every tap

---

## 3. State Machines

Writing these as explicit enums before touching SwiftUI views is the highest-leverage step here — it also gives a Claude Code session a concrete source of truth to reference for any single feature.

```swift
// Entry List
enum EntryListState {
    case loading
    case loaded([Entry])
    case empty
    case syncing([Entry])            // has data, sync backed in background
    case syncError([Entry], Error)   // has data, sync failed
}

// AI generation (New/Edit Entry)
enum AITaggingState {
    case idle
    case ineligible(reason: String)  // tier 3 from §5
    case generating
    case generated(tags: [Tag], summary: String?)
    case failed(Error)
}

// Search
enum SearchState {
    case emptyQuery(recents: [String])
    case indexing(progress: Double)
    case searching
    case results([Entry])
    case noKeywordMatches
    case noSemanticMatches
}
```

---

## 4. Accessibility Requirements

- VoiceOver labels for every AI-generated element announce its AI origin before the content itself
- Full Dynamic Type support, tested at the largest accessibility sizes — not just the largest standard size
- Minimum 44×44pt tap targets everywhere, including the keyboard accessory toolbar icons
- Reduce Motion: swap the tag-generation spring animation and skeleton shimmer for a simple cross-fade
- Contrast-check the `aiAccent` token in both light and dark mode — accent colors tuned for light mode frequently fail contrast in dark mode when reused as text-on-tint

---

## 5. Device & Model Eligibility Matrix

Check eligibility at runtime via `SystemLanguageModel`'s availability API — don't hardcode device-model lists, since eligibility depends on more than the phone model (storage headroom, region, whether Apple Intelligence is enabled at all).

| Tier | What's available | UI behavior |
|---|---|---|
| **Unavailable** | Apple Intelligence off, unsupported region, or device below the minimum bar | `sparkles` icon shown de-emphasized; tap explains why instead of attempting a call; saving is never blocked |
| **Text-only** | On-device model runs; image multimodal path isn't available on this hardware tier | Full text tagging/summarization/semantic search; photo attachments display but don't generate their own tags |
| **Full multimodal** | Higher-tier on-device model available | Text *and* photo-derived tags, visually distinguished by source |
| **Enhanced (opt-in)** | Private Cloud Compute fallback enabled in Settings | Used only for entries exceeding the on-device context window; explicit opt-in, off by default |

---

## 6. Suggested Build Order

1. Entry List + New/Edit Entry on plain SwiftData — no AI yet, get the CRUD loop and sectioned-query grouping solid first
2. Model-eligibility plumbing + the Settings "AI status" row (§1.6, §5) — build the degradation path *before* the AI features that depend on it
3. Entry Detail + static tag pills
4. Wire in Foundation Models text tagging/summarization (New/Edit Entry AI states)
5. AI Summary card in Entry Detail
6. Search — keyword mode, then semantic (faster than originally scoped, thanks to the built-in primitive — no separate embeddings-pipeline milestone needed)
7. Related Entries in Entry Detail — can now be built alongside Search rather than strictly after it, since both lean on the same semantic primitive
8. Tags/Browse screen
9. Multimodal photo tagging (tier-gated, §5)
10. Private Cloud Compute opt-in fallback for long entries
11. iPad layout pass (`NavigationSplitView`), if wanted
