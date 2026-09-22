//
//  EntryEditorView.swift
//  AI_Journel
//
//  Created by Arpit Parekh on 06/07/26.
//

import SwiftUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var bodyText = ""
    let checker: AIEligibilityChecker

    var body: some View {
        NavigationStack {
            TextEditor(text: $bodyText)
                .padding()
                .navigationTitle("New Entry")
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
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
