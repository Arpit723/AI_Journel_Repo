//
//  EntryEditorView.swift
//  AI_Journel
//
//  Created by Arpit Parekh on 06/07/26.
//

import SwiftUI
import SwiftData

/// Editor for both creating a new entry (`entry == nil`) and editing an
/// existing one (`entry` passed in, text pre-filled with its current body).
struct EntryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var bodyText: String
    let entry: JournalEntry?
    let checker: AIEligibilityChecker

    init(entry: JournalEntry? = nil, checker: AIEligibilityChecker) {
        self.entry = entry
        self.checker = checker
        _bodyText = State(initialValue: entry?.body ?? "")
    }

    private var isEditing: Bool {
        entry != nil
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $bodyText)
                .padding()
                .navigationTitle(isEditing ? "Edit Entry" : "New Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            saveEntry()
                        }
                        .disabled(bodyText.trimmed.isEmpty)
                    }
                }
        }
    }

    private func saveEntry() {
        if let entry {
            updateEntry(entry)
        } else {
            createEntry()
        }
    }

    private func createEntry() {
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

    private func updateEntry(_ entry: JournalEntry) {
        // Skip everything if the text didn't actually change — tags are
        // already in sync with the stored body, so regeneration would be
        // wasted model work. Compared BEFORE mutating entry.body.
        guard entry.body.trimmed != bodyText.trimmed else {
            print("[Journal] edit saved with unchanged text — skipping tag regeneration")
            dismiss()
            return
        }

        // Mutate the existing model — it's already registered in the context,
        // so no insert; SwiftData persists the change. Original timestamp is
        // kept so edits don't reorder the journal.
        entry.body = bodyText
        dismiss()

        print("[Journal] updated entry: \(bodyText)")

        // Tags must track edited content: regenerate on the new text and
        // replace only on success. Unavailable AI or a failed generation
        // leaves the existing tags untouched.
        guard checker.tier.isUsable else {
            print("[Journal] AI skipped — keeping existing tags, tier: \(checker.tier)")
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
                print("[Journal] AI tags regenerated: \(suggestions.suggestedTags)")
                entry.tags = suggestions.suggestedTags
            } catch {
                print("[Journal] AI tag regeneration failed — keeping existing tags: \(error)")
            }
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
