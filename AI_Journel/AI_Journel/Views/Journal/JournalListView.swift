//
//  JournalListView.swift
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
    @State private var showingSearchDebug = false
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingSearchDebug = true
                        } label: {
                            Label("Semantic Search Test…", systemImage: "magnifyingglass")
                        }
                    } label: {
                        Label("Debug", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEntryView(checker: checker)
            }
            .sheet(isPresented: $showingSearchDebug) {
                DebugSearchView()
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

#Preview {
    ContentView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
