//
//  MainTabView.swift
//  AI_Journel
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Journal", systemImage: "book")
                }
            AskView()
                .tabItem {
                    Label("Ask", systemImage: "sparkles")
                }
            TagFrequencyView()
                .tabItem {
                    Label("Patterns", systemImage: "tag")
                }
        }
    }
}
