//
//  ContentView.swift
//  AI_Journel
//
//  Created by Arpit Parekh on 06/07/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var entries: [JournalEntry]
    @State private var showingAddSheet = false
    @State private var checker = AIEligibilityChecker()

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("Start Your Journal", systemImage: "book.closed")
                    } description: {
                        Text("Write your first entry and let Apple Intelligence suggest tags.")
                    } actions: {
                        Button("Write First Entry") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink {
                                EntryDetailView(entry: entry)
                            } label: {
                                EntryRowView(entry: entry)
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEntryView(checker: checker)
            }
            .task {
                checker.refresh()
            }
        }
    }

    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(entries[index])
            }
        }
    }
}

private struct EntryRowView: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.body)
                .font(.body)
                .lineLimit(2)
            if !entry.tags.isEmpty {
                TagPillRow(tags: entry.tags.map { TagPillData(label: $0, isAISourced: true) })
            }
        }
    }
}

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

struct EntryDetailView: View {
    let entry: JournalEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.timestamp, format: Date.FormatStyle(date: .long, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.body)
                    .font(.body)
                if !entry.tags.isEmpty {
                    TagPillRow(tags: entry.tags.map { TagPillData(label: $0, isAISourced: true) })
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
