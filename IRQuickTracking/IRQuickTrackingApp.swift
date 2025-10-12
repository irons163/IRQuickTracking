//
//  IRQuickTrackingApp.swift
//  IRQuickTracking
//
//  Created by Phil on 2025/8/25.
//

import SwiftUI

@main
struct IRQuickTrackingApp: App {
    @StateObject private var filter = FilterState()
    @State private var selection: Asset.ID? = nil
    private let allAssets = DemoData.assets

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(filter)
        }
    }

    @ViewBuilder
    private func ContentView() -> some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            AssetListView(allAssets: allAssets, selection: $selection)
        } detail: {
            if let selected = allAssets.first(where: { $0.id == selection }) {
                AssetDetailView(asset: selected)
            } else {
                PlaceholderDetailView()
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
    }
}
