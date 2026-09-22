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
