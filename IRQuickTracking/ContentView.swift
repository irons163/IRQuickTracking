//
//  ContentView.swift
//  IRQuickTracking
//
//  Created by Phil on 2025/8/25.
//

// SwiftUI Shelf Assets Demo (TCA 版，改回 BindingState/@Bindable)

import ComposableArchitecture
import MapKit
import SwiftUI

// MARK: - Existing Counter Demo (kept for tests)

@Reducer
struct Feature {
    @Dependency(\.numberFact) var numberFact

    @ObservableState
    struct State: Equatable {
        var count = 0
        var numberFact: String?
    }

    enum Action {
        case decrementButtonTapped
        case incrementButtonTapped
        case numberFactButtonTapped
        case numberFactResponse(String)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .decrementButtonTapped:
                state.count -= 1
                return .none

            case .incrementButtonTapped:
                state.count += 1
                return .none

            case .numberFactButtonTapped:
                return .run { [count = state.count] send in
                    let fact = try await self.numberFact.fetch(count)
                    await send(.numberFactResponse(fact))
                }

            case .numberFactResponse(let fact):
                state.numberFact = fact
                return .none
            }
        }
    }
}

struct FeatureView: View {
    let store: StoreOf<Feature>

    var body: some View {
        Form {
            Section {
                Text("\(store.count)")
                Button("Decrement") { store.send(.decrementButtonTapped) }
                Button("Increment") { store.send(.incrementButtonTapped) }
            }

            Section {
                Button("Number fact") { store.send(.numberFactButtonTapped) }
            }

            if let fact = store.numberFact {
                Text(fact)
            }
        }
    }
}

struct NumberFactClient {
  var fetch: (Int) async throws -> String
}

extension NumberFactClient: DependencyKey {
  static let liveValue = Self(
    fetch: { number in
      let (data, _) = try await URLSession.shared
        .data(from: URL(string: "http://numbersapi.com/\(number)")!
      )
      return String(decoding: data, as: UTF8.self)
    }
  )
}

extension DependencyValues {
  var numberFact: NumberFactClient {
    get { self[NumberFactClient.self] }
    set { self[NumberFactClient.self] = newValue }
  }
}

// MARK: - Models

extension CLLocationCoordinate2D: @retroactive Equatable {}
extension CLLocationCoordinate2D: @retroactive Hashable {

    public static func == (
        lhs: CLLocationCoordinate2D,
        rhs: CLLocationCoordinate2D
    ) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}

struct Asset: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var status: AssetStatus
    var category: String
    var tags: [String]
    var custodian: String
    var locationName: String
    var coordinate: CLLocationCoordinate2D?
    var value: Double
    var thumbnailSystemImage: String
}

enum AssetStatus: String, CaseIterable, Identifiable {
    case available = "Available"
    case checkedOut = "Checked out"
    case inCustody = "In custody"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .available: return .green
        case .checkedOut: return .purple
        case .inCustody: return .blue
        }
    }
    var icon: String { "circle.fill" }
}

// MARK: - Demo Data

enum DemoData {
    static let baseCoordinate = CLLocationCoordinate2D(
        latitude: 52.093,
        longitude: 5.119
    )  // random EU-ish center

    static let assets: [Asset] = [
        Asset(
            name: "MacBook Pro M1 14\" (2021)",
            status: .available,
            category: "Office Equipment",
            tags: ["Apple", "Workstation"],
            custodian: "Shelf",
            locationName: "Office B.05",
            coordinate: CLLocationCoordinate2D(
                latitude: 52.08,
                longitude: 5.12
            ),
            value: 2000,
            thumbnailSystemImage: "laptopcomputer"
        ),
        Asset(
            name: "LG 5K Monitor",
            status: .checkedOut,
            category: "Office Equipment",
            tags: ["Workstation", "Peripherals"],
            custodian: "Phoenix Baker",
            locationName: "—",
            coordinate: CLLocationCoordinate2D(
                latitude: 52.10,
                longitude: 5.08
            ),
            value: 900,
            thumbnailSystemImage: "display"
        ),
        Asset(
            name: "Standing Desk – Fitnest Pro",
            status: .available,
            category: "Office Equipment",
            tags: ["Workstation", "Desks"],
            custodian: "Shelf",
            locationName: "Office A.12",
            coordinate: CLLocationCoordinate2D(
                latitude: 52.07,
                longitude: 5.10
            ),
            value: 600,
            thumbnailSystemImage: "table"
        ),
        Asset(
            name: "USB-C Adapter",
            status: .checkedOut,
            category: "Cables",
            tags: ["Peripherals"],
            custodian: "Phoenix Baker",
            locationName: "—",
            coordinate: CLLocationCoordinate2D(
                latitude: 52.09,
                longitude: 5.09
            ),
            value: 29,
            thumbnailSystemImage: "cable.connector"
        ),
        Asset(
            name: "MacBook Air M2 13\" (2022)",
            status: .inCustody,
            category: "Office Equipment",
            tags: ["Apple", "Workstation"],
            custodian: "Lana Steiner",
            locationName: "Office C.03",
            coordinate: CLLocationCoordinate2D(
                latitude: 52.095,
                longitude: 5.11
            ),
            value: 1499,
            thumbnailSystemImage: "laptopcomputer"
        ),
        Asset(
            name: "Magic Whiteboard",
            status: .available,
            category: "Education",
            tags: ["Workshop"],
            custodian: "Shelf",
            locationName: "Meeting 2F",
            coordinate: CLLocationCoordinate2D(
                latitude: 52.11,
                longitude: 5.12
            ),
            value: 120,
            thumbnailSystemImage: "rectangle.and.pencil.and.ellipsis"
        ),
        Asset(
            name: "First Aid Kit",
            status: .available,
            category: "Inventory",
            tags: ["Medical"],
            custodian: "Shelf",
            locationName: "Lobby",
            coordinate: CLLocationCoordinate2D(
                latitude: 52.085,
                longitude: 5.105
            ),
            value: 75,
            thumbnailSystemImage: "cross.case"
        ),
        Asset(
            name: "Dell Projector",
            status: .available,
            category: "Office Equipment",
            tags: ["Meeting", "Peripherals"],
            custodian: "Shelf",
            locationName: "Gear Room I",
            coordinate: CLLocationCoordinate2D(
                latitude: 52.082,
                longitude: 5.115
            ),
            value: 480,
            thumbnailSystemImage: "video.projector"
        ),
    ]
}

// MARK: - TCA: FilterFeature (use @BindingState)

@Reducer
struct FilterFeature {
    @ObservableState
    struct State: Equatable {
        var search: String = ""
        var selectedCategory: String? = nil
        var selectedTag: String? = nil
        var selectedStatus: AssetStatus? = nil

        func apply(to assets: [Asset]) -> [Asset] {
            var result = assets
            if let s = selectedStatus { result = result.filter { $0.status == s } }
            if let c = selectedCategory {
                result = result.filter { $0.category == c }
            }
            if let t = selectedTag {
                result = result.filter { $0.tags.contains(t) }
            }
            if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                let q = search.lowercased()
                result = result.filter { asset in
                    [
                        asset.name, asset.category, asset.custodian,
                        asset.locationName, asset.tags.joined(separator: ", "),
                    ]
                    .joined(separator: " ")
                    .lowercased()
                    .contains(q)
                }
            }
            return result
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        // Explicit setters to satisfy tests
        case setSearch(String)
        case setSelectedCategory(String?)
        case setSelectedTag(String?)
        case setSelectedStatus(AssetStatus?)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .setSearch(let text):
                state.search = text
                return .none
            case .setSelectedCategory(let category):
                state.selectedCategory = category
                return .none
            case .setSelectedTag(let tag):
                state.selectedTag = tag
                return .none
            case .setSelectedStatus(let status):
                state.selectedStatus = status
                return .none
            }
        }
    }
}

// MARK: - TCA: AppFeature (use @BindingState)

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var assets: [Asset] = DemoData.assets
        var selection: Asset.ID? = nil
        var filter = FilterFeature.State()
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case filter(FilterFeature.Action)
        // Explicit setter to satisfy tests
        case setSelection(Asset.ID?)
        // Quick add
        case newAssetButtonTapped
    }

    var body: some Reducer<State, Action> {
        BindingReducer()

        Scope(state: \.filter, action: \.filter) {
            FilterFeature()
        }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .filter:
                return .none
            case .setSelection(let id):
                state.selection = id
                return .none
            case .newAssetButtonTapped:
                let new = Asset(
                    name: "New Asset",
                    status: .available,
                    category: "Uncategorized",
                    tags: [],
                    custodian: "Unassigned",
                    locationName: "—",
                    coordinate: nil,
                    value: 0,
                    thumbnailSystemImage: "cube.box"
                )
                state.assets.insert(new, at: 0)
                state.selection = new.id
                return .none
            }
        }
    }
}

// MARK: - App Views (TCA)

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            AssetListView(store: store)
        } detail: {
            if let selected = store.assets.first(where: { $0.id == store.selection }) {
                AssetDetailView(asset: selected)
            } else {
                PlaceholderDetailView()
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    var body: some View {
        List {
            Section {
                Label("Dashboard", systemImage: "house")
                Label("Assets", systemImage: "cube.box")
                Label("Categories", systemImage: "square.grid.2x2")
                Label("Tags", systemImage: "tag")
                Label("Locations", systemImage: "mappin.and.ellipse")
                Label("Bookings", systemImage: "calendar")
            }
        }
        #if os(macOS)
            .listStyle(.sidebar)
        #endif
        .navigationTitle("Shelf")
    }
}

// MARK: - Top Toolbar (Search + Filters + Actions)

struct TopToolbarView: View {
    @Bindable var store: StoreOf<FilterFeature>
    let categories: [String]
    let tags: [String]
    let onNew: () -> Void

    init(
        store: StoreOf<FilterFeature>,
        categories: [String],
        tags: [String],
        onNew: @escaping () -> Void
    ) {
        self.store = store
        self.categories = categories
        self.tags = tags
        self.onNew = onNew
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                TextField("Search assets", text: $store.search)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(
                .thinMaterial,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .frame(minWidth: 240)

            Divider().frame(height: 24)

            Menu {
                Picker("Status", selection: $store.selectedStatus) {
                    Text("All").tag(AssetStatus?.none)
                    ForEach(AssetStatus.allCases) { s in
                        Text(s.rawValue).tag(AssetStatus?.some(s))
                    }
                }
            } label: {
                FilterChip(title: store.selectedStatus?.rawValue ?? "Status")
            }

            Menu {
                Picker("Category", selection: $store.selectedCategory) {
                    Text("All").tag(String?.none)
                    ForEach(categories, id: \.self) { c in
                        Text(c).tag(String?.some(c))
                    }
                }
            } label: {
                FilterChip(title: store.selectedCategory ?? "Category")
            }

            Menu {
                Picker("Tag", selection: $store.selectedTag) {
                    Text("All").tag(String?.none)
                    ForEach(tags, id: \.self) { t in
                        Text(t).tag(String?.some(t))
                    }
                }
            } label: {
                FilterChip(title: store.selectedTag ?? "Tag")
            }

            Spacer()

            Button("Import") {}
            Button("Export") {}
            Button {
                onNew()
            } label: {
                Label("New Asset", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct FilterChip: View {
    var title: String
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(.footnote)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }
}

// MARK: - Asset List

struct AssetListView: View {
    @Bindable var store: StoreOf<AppFeature>

    init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    private var categories: [String] {
        Array(Set(store.assets.map { $0.category })).sorted()
    }
    private var tags: [String] {
        Array(Set(store.assets.flatMap { $0.tags })).sorted()
    }
    private var filtered: [Asset] {
        store.filter.apply(to: store.assets)
    }

    var body: some View {
        VStack(spacing: 0) {
            TopToolbarView(
                store: store.scope(state: \.filter, action: \.filter),
                categories: categories,
                tags: tags,
                onNew: { store.send(.newAssetButtonTapped) }
            )

            HeaderRow()
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            List(selection: $store.selection) {
                ForEach(filtered) { asset in
                    AssetRow(asset: asset)
                        .tag(asset.id)
                }
            }
            .listStyle(.plain)
        }
    }
}

struct HeaderRow: View {
    var body: some View {
        HStack {
            Spacer().frame(width: 28)  // checkbox space
            Text("Name").font(.caption).foregroundStyle(.secondary).frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            Text("Category").font(.caption).foregroundStyle(.secondary).frame(
                width: 160,
                alignment: .leading
            )
            Text("Tags").font(.caption).foregroundStyle(.secondary).frame(
                width: 220,
                alignment: .leading
            )
            Text("Custodian").font(.caption).foregroundStyle(.secondary).frame(
                width: 130,
                alignment: .leading
            )
            Text("Location").font(.caption).foregroundStyle(.secondary).frame(
                width: 150,
                alignment: .leading
            )
        }
    }
}

struct AssetRow: View {
    let asset: Asset
    @State private var isChecked: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Toggle("", isOn: $isChecked).labelsHidden().frame(width: 28)

            // Name + status
            HStack(spacing: 10) {
                Image(systemName: asset.thumbnailSystemImage).imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.name).fontWeight(.semibold)
                    HStack(spacing: 6) {
                        Image(systemName: asset.status.icon)
                            .foregroundStyle(asset.status.color)
                        Text(asset.status.rawValue)
                            .foregroundStyle(asset.status.color)
                            .font(.footnote)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Category
            Text(asset.category).frame(width: 160, alignment: .leading)

            // Tags
            HStack(spacing: 6) {
                ForEach(asset.tags, id: \.self) { tag in TagChip(tag: tag) }
            }
            .frame(width: 220, alignment: .leading)

            // Custodian
            Text(asset.custodian).frame(width: 130, alignment: .leading)

            // Location
            Text(asset.locationName).frame(width: 150, alignment: .leading)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct TagChip: View {
    var tag: String
    var body: some View {
        Text(tag)
            .font(.footnote)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(.systemGray5), in: Capsule())
    }
}

// MARK: - Detail View

struct AssetDetailView: View {
    let asset: Asset

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Custody card
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "person.crop.circle.fill").font(
                        .largeTitle
                    )
                    VStack(alignment: .leading) {
                        Text("Asset in custody of")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(asset.custodian).font(.title3).fontWeight(
                            .semibold
                        )
                    }
                    Spacer()
                }
                .padding()
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16)
                )

                InfoGrid(asset: asset)

                if let coordinate = asset.coordinate {
                    MapCardView(
                        coordinate: coordinate,
                        label: asset.locationName
                    )
                }

                Spacer(minLength: 24)
            }
            .padding()
            .navigationTitle(asset.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct InfoGrid: View {
    let asset: Asset
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(
                alignment: .leading,
                horizontalSpacing: 16,
                verticalSpacing: 10
            ) {
                GridRow {
                    KeyValueRow(
                        key: "ID",
                        value: asset.id.uuidString.prefix(8) + "…"
                    )
                    KeyValueRow(key: "Category", value: asset.category)
                }
                GridRow {
                    KeyValueRow(
                        key: "Tags",
                        value: asset.tags.joined(separator: ", ")
                    )
                    KeyValueRow(key: "Location", value: asset.locationName)
                }
                GridRow {
                    KeyValueRow(
                        key: "Status",
                        value: asset.status.rawValue,
                        color: asset.status.color
                    )
                    KeyValueRow(
                        key: "Current value",
                        value: "$" + String(format: "%.2f", asset.value)
                    )
                }
            }
        }
        .padding()
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

struct KeyValueRow: View {
    var key: String
    var value: String
    var color: Color? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body).foregroundStyle(color ?? .primary)
        }
    }
}

struct MapCardView: View {
    let coordinate: CLLocationCoordinate2D
    let label: String
    @State private var region: MKCoordinateRegion

    init(coordinate: CLLocationCoordinate2D, label: String) {
        self.coordinate = coordinate
        self.label = label
        _region = State(
            initialValue: MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: 0.02,
                    longitudeDelta: 0.02
                )
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current location").font(.subheadline).foregroundStyle(
                .secondary
            )
            Text(label).font(.headline)
            Map(
                coordinateRegion: $region,
                annotationItems: [MapPinItem(coordinate: coordinate)]
            ) { item in
                MapMarker(coordinate: item.coordinate)
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct MapPinItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct PlaceholderDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.box").font(.system(size: 48))
            Text("Select an asset")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Previews

struct ShelfDemo_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AppView(
                store: Store(initialState: AppFeature.State()) {
                    AppFeature()
                }
            )
            .previewDisplayName("App (TCA)")
        }
    }
}
