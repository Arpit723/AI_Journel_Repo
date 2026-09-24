//
//  TagFrequencyView.swift
//  AI_Journel
//

import SwiftUI
import SwiftData

struct TagFrequencyView: View {
    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var entries: [JournalEntry]

    private var tagCounts: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for entry in entries {
            for tag in Set(entry.tags) {
                counts[tag, default: 0] += 1
            }
        }
        return counts
            .map { (tag: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }
                return $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("No Entries Yet", systemImage: "book.closed")
                    } description: {
                        Text("Write journal entries and the topics AI tags them with will show up here as counts.")
                    }
                } else if tagCounts.isEmpty {
                    ContentUnavailableView {
                        Label("No Tags Yet", systemImage: "tag")
                    } description: {
                        Text("Your entries don't have tags yet — Apple Intelligence adds them when you save an entry.")
                    }
                } else {
                    List(tagCounts, id: \.tag) { item in
                        HStack {
                            Text(item.tag)
                            Spacer()
                            Text("\(item.count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("Patterns")
        }
    }
}

#Preview {
    TagFrequencyView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
