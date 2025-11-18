import SwiftUI
import ComposableArchitecture

@main
struct IRQuickTrackingApp: App {
    var body: some Scene {
//        WindowGroup {
//            AppView(
//                store: Store(initialState: AppFeature.State()) {
//                    AppFeature()
//                }
//            )
//        }
        WindowGroup {
            ItemsAppView(
            store: Store(initialState: ItemsFeature.State()) { ItemsFeature() }
          )
        }
    }
}
