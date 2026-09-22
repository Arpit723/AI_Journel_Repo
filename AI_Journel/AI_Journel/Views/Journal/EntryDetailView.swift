//
//  EntryDetailView.swift
//  AI_Journel
//
//  Created by Arpit Parekh on 06/07/26.
//

import SwiftUI
import SwiftData

struct EntryDetailView: View {
    let entry: JournalEntry
    let checker: AIEligibilityChecker

    @State private var showingEditSheet = false

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EntryEditorView(entry: entry, checker: checker)
        }
    }
}
