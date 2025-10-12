//
//  ContentView.swift
//  IRQuickTracking
//
//  Created by Phil on 2025/8/25.
//

// SwiftUI Shelf Assets Demo
// Single-file demo that mimics a B2B asset manager UI (sidebar + list + detail)
// Works on iOS/iPadOS/macOS (SwiftUI + MapKit). No location permissions required.
// - Create a new SwiftUI App project and replace the template code with this file.
// - Minimum iOS 16/macOS 13 recommended.

import SwiftUI
import MapKit

// MARK: - Models

extension CLLocationCoordinate2D: @retroactive Equatable {}
extension CLLocationCoordinate2D: @retroactive Hashable {

    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude &&
               lhs.longitude == rhs.longitude
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

// MARK: - Filtering / App State

final class FilterState: ObservableObject {
    @Published var search: String = ""
    @Published var selectedCategory: String? = nil
    @Published var selectedTag: String? = nil
    @Published var selectedStatus: AssetStatus? = nil

    func apply(to assets: [Asset]) -> [Asset] {
        var result = assets
        if let s = selectedStatus { result = result.filter { $0.status == s } }
        if let c = selectedCategory { result = result.filter { $0.category == c } }
        if let t = selectedTag { result = result.filter { $0.tags.contains(t) } }
        if !search.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = search.lowercased()
            result = result.filter { asset in
                [asset.name, asset.category, asset.custodian, asset.locationName, asset.tags.joined(separator: ", ")]
                    .joined(separator: " ")
                    .lowercased()
                    .contains(q)
            }
        }
        return result
    }
}

// MARK: - Demo Data

enum DemoData {
    static let baseCoordinate = CLLocationCoordinate2D(latitude: 52.093, longitude: 5.119) // random EU-ish center

    static let assets: [Asset] = [
        Asset(name: "MacBook Pro M1 14\" (2021)", status: .available, category: "Office Equipment", tags: ["Apple", "Workstation"], custodian: "Shelf", locationName: "Office B.05", coordinate: CLLocationCoordinate2D(latitude: 52.08, longitude: 5.12), value: 2000, thumbnailSystemImage: "laptopcomputer"),
        Asset(name: "LG 5K Monitor", status: .checkedOut, category: "Office Equipment", tags: ["Workstation", "Peripherals"], custodian: "Phoenix Baker", locationName: "—", coordinate: CLLocationCoordinate2D(latitude: 52.10, longitude: 5.08), value: 900, thumbnailSystemImage: "display"),
        Asset(name: "Standing Desk – Fitnest Pro", status: .available, category: "Office Equipment", tags: ["Workstation", "Desks"], custodian: "Shelf", locationName: "Office A.12", coordinate: CLLocationCoordinate2D(latitude: 52.07, longitude: 5.10), value: 600, thumbnailSystemImage: "table"),
        Asset(name: "USB-C Adapter", status: .checkedOut, category: "Cables", tags: ["Peripherals"], custodian: "Phoenix Baker", locationName: "—", coordinate: CLLocationCoordinate2D(latitude: 52.09, longitude: 5.09), value: 29, thumbnailSystemImage: "cable.connector"),
        Asset(name: "MacBook Air M2 13\" (2022)", status: .inCustody, category: "Office Equipment", tags: ["Apple", "Workstation"], custodian: "Lana Steiner", locationName: "Office C.03", coordinate: CLLocationCoordinate2D(latitude: 52.095, longitude: 5.11), value: 1499, thumbnailSystemImage: "laptopcomputer"),
        Asset(name: "Magic Whiteboard", status: .available, category: "Education", tags: ["Workshop"], custodian: "Shelf", locationName: "Meeting 2F", coordinate: CLLocationCoordinate2D(latitude: 52.11, longitude: 5.12), value: 120, thumbnailSystemImage: "rectangle.and.pencil.and.ellipsis"),
        Asset(name: "First Aid Kit", status: .available, category: "Inventory", tags: ["Medical"], custodian: "Shelf", locationName: "Lobby", coordinate: CLLocationCoordinate2D(latitude: 52.085, longitude: 5.105), value: 75, thumbnailSystemImage: "cross.case"),
        Asset(name: "Dell Projector", status: .available, category: "Office Equipment", tags: ["Meeting", "Peripherals"], custodian: "Shelf", locationName: "Gear Room I", coordinate: CLLocationCoordinate2D(latitude: 52.082, longitude: 5.115), value: 480, thumbnailSystemImage: "video.projector"),
    ]
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
    @EnvironmentObject private var filter: FilterState

    let categories: [String]
    let tags: [String]

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                TextField("Search assets", text: $filter.search)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(minWidth: 240)

            Divider().frame(height: 24)

            Menu {
                Picker("Status", selection: $filter.selectedStatus) {
                    Text("All").tag(AssetStatus?.none)
                    ForEach(AssetStatus.allCases) { s in
                        Text(s.rawValue).tag(AssetStatus?.some(s))
                    }
                }
            } label: {
                FilterChip(title: filter.selectedStatus?.rawValue ?? "Status")
            }

            Menu {
                Picker("Category", selection: $filter.selectedCategory) {
                    Text("All").tag(String?.none)
                    ForEach(categories, id: \.self) { c in Text(c).tag(String?.some(c)) }
                }
            } label: {
                FilterChip(title: filter.selectedCategory ?? "Category")
            }

            Menu {
                Picker("Tag", selection: $filter.selectedTag) {
                    Text("All").tag(String?.none)
                    ForEach(tags, id: \.self) { t in Text(t).tag(String?.some(t)) }
                }
            } label: {
                FilterChip(title: filter.selectedTag ?? "Tag")
            }

            Spacer()

            Button("Import") {}
            Button("Export") {}
            Button {
                // Simulate new asset creation in demo
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
    @EnvironmentObject private var filter: FilterState

    let allAssets: [Asset]
    @Binding var selection: Asset.ID?

    private var filtered: [Asset] {
        filter.apply(to: allAssets)
    }

    var body: some View {
        VStack(spacing: 0) {
            TopToolbarView(categories: Array(Set(allAssets.map { $0.category })).sorted(),
                           tags: Array(Set(allAssets.flatMap { $0.tags })).sorted())

            HeaderRow()
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            List(selection: $selection) {
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
            Spacer().frame(width: 28) // checkbox space
            Text("Name").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Text("Category").font(.caption).foregroundStyle(.secondary).frame(width: 160, alignment: .leading)
            Text("Tags").font(.caption).foregroundStyle(.secondary).frame(width: 220, alignment: .leading)
            Text("Custodian").font(.caption).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
            Text("Location").font(.caption).foregroundStyle(.secondary).frame(width: 150, alignment: .leading)
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
                    Image(systemName: "person.crop.circle.fill").font(.largeTitle)
                    VStack(alignment: .leading) {
                        Text("Asset in custody of")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(asset.custodian).font(.title3).fontWeight(.semibold)
                    }
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                InfoGrid(asset: asset)

                if let coordinate = asset.coordinate {
                    MapCardView(coordinate: coordinate, label: asset.locationName)
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
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    KeyValueRow(key: "ID", value: asset.id.uuidString.prefix(8) + "…")
                    KeyValueRow(key: "Category", value: asset.category)
                }
                GridRow {
                    KeyValueRow(key: "Tags", value: asset.tags.joined(separator: ", "))
                    KeyValueRow(key: "Location", value: asset.locationName)
                }
                GridRow {
                    KeyValueRow(key: "Status", value: asset.status.rawValue, color: asset.status.color)
                    KeyValueRow(key: "Current value", value: "$" + String(format: "%.2f", asset.value))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
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
        _region = State(initialValue: MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current location").font(.subheadline).foregroundStyle(.secondary)
            Text(label).font(.headline)
            Map(coordinateRegion: $region, annotationItems: [MapPinItem(coordinate: coordinate)]) { item in
                MapMarker(coordinate: item.coordinate)
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct MapPinItem: Identifiable { let id = UUID(); let coordinate: CLLocationCoordinate2D }

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
            NavigationSplitView {
                SidebarView()
            } content: {
                AssetListView(allAssets: DemoData.assets, selection: .constant(nil))
                    .environmentObject(FilterState())
            } detail: {
                PlaceholderDetailView()
            }
            .previewDisplayName("List + Placeholder")

            AssetDetailView(asset: DemoData.assets[0])
                .previewDisplayName("Detail")
        }
    }
}
