# Plan: Create `.kilocode/rules/restricted_files.md`

Task is fully specified by the user — no design decisions open. Target directory
`.kilocode/rules/` already exists (created earlier today); no other files may be
modified.

## Steps

1. Create `/Users/arpitparekh/Documents/GitHub/AI_Journel_Repo/.kilocode/rules/restricted_files.md`
   with EXACTLY this content (verbatim, including headings and backticks):

```markdown
# Restricted Files

The following files are verified working and must NOT be modified unless a task
explicitly instructs changes to them by name:

- `Services/AIEligibility.swift` — eligibility checking and structured-generation
  tagging logic (generateSuggestions())
- `Services/EmbeddingService.swift` — embedding generation, cosine similarity,
  and retrieveTopMatches()

If a task seems to require changing one of these files but doesn't explicitly
say so, stop and ask for confirmation before editing them, rather than assuming
it's fine because the feature "requires" it.
```

2. Verify it exists at the correct path (e.g. `ls -la .kilocode/rules/` and
   confirm `restricted_files.md` is present, non-empty).

## Constraints

- Do NOT modify any other file (including `Services/AIEligibility.swift`,
  `Services/EmbeddingService.swift`, the existing `project-context.md`).
- Do not reformat or "improve" the content — it is verbatim by request.

## Validation

- File exists at `.kilocode/rules/restricted_files.md`.
- Content matches the block above byte-for-byte (modulo trailing newline).
- `git status` shows only the one new untracked file.
