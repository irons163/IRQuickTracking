//
//  IRQuickTrackingTests.swift
//  IRQuickTrackingTests
//
//  Created by Phil on 2025/8/25.
//

import Testing
import ComposableArchitecture
@testable import IRQuickTracking

struct IRQuickTrackingTests {

    @Test
    func feature_basics() async {
        let store = await TestStore(initialState: Feature.State()) {
            Feature()
        } withDependencies: {
            $0.numberFact.fetch = { "\($0) is a good number Brent" }
        }

        // increment / decrement
        await store.send(.incrementButtonTapped) { state in
            state.count = 1
        }
        await store.send(.decrementButtonTapped) { state in
            state.count = 0
        }

        // number fact
        await store.send(.numberFactButtonTapped)
        await store.receive(\.numberFactResponse) { state in
            state.numberFact = "0 is a good number Brent"
        }
    }

    @Test
    func appFeature_setSelection_and_filtering() async {
        let initial = AppFeature.State()
        let store = await TestStore(initialState: initial) {
            AppFeature()
        }

        // 先選取第一個資產
        let firstID = await store.state.assets.first!.id
        await store.send(.setSelection(firstID)) { state in
            state.selection = firstID
        }

        // 設定搜尋關鍵字（改由發送子 feature 的 action）
        await store.send(.filter(.setSearch("MacBook"))) { state in
            state.filter.search = "MacBook"
        }

        // 設定分類
        await store.send(.filter(.setSelectedCategory("Office Equipment"))) { state in
            state.filter.selectedCategory = "Office Equipment"
        }

        // 設定標籤
        await store.send(.filter(.setSelectedTag("Apple"))) { state in
            state.filter.selectedTag = "Apple"
        }

        // 設定狀態
        await store.send(.filter(.setSelectedStatus(.available))) { state in
            state.filter.selectedStatus = .available
        }
    }
}
