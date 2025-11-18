import SwiftUI
import ComposableArchitecture
import PhotosUI // 新增

// MARK: - Models

public struct Item: Equatable, Identifiable, Hashable, Codable {
    public let id: UUID
    public var title: String
    public var icon: String
    public var color: ColorData
    public var tags: [String]
    public var targetPerDay: Int
    public var notes: String
    public var reminderEnabled: Bool
    public var reminderTime: Date
    public var logs: [ItemLog]
    public var photoData: Data?    // 新增，用于存储照片数据

    public init(
        id: UUID = UUID(),
        title: String,
        icon: String = "checkmark.circle.fill",
        color: Color = .blue,
        tags: [String] = [],
        targetPerDay: Int = 1,
        notes: String = "",
        reminderEnabled: Bool = false,
        reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!,
        logs: [ItemLog] = [],
        photoData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.color = .from(color)
        self.tags = tags
        self.targetPerDay = max(1, targetPerDay)
        self.notes = notes
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
        self.logs = logs
        self.photoData = photoData
    }
}

public struct ItemLog: Equatable, Identifiable, Hashable, Codable {
    public var id: UUID = UUID()
    public var date: Date
}

// Persistable Color wrapper (simple Codable RGB)
public struct ColorData: Hashable, Codable, Equatable {
    public var r: Double; public var g: Double; public var b: Double; public var a: Double
    public var color: Color { Color(red: r, green: g, blue: b).opacity(a) }
    public static func from(_ c: Color) -> ColorData {
        #if canImport(UIKit)
        let ui = UIColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return .init(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
        #else
        return .init(r: 0.0, g: 0.478, b: 1.0, a: 1.0)
        #endif
    }
}

// MARK: - Dependencies

private enum CalendarKey: DependencyKey {
    static var liveValue: Calendar = .current
}
extension DependencyValues { var calendar: Calendar { get { self[CalendarKey.self] } set { self[CalendarKey.self] = newValue } } }

// MARK: - Helpers

extension Item {
    func didSatisfy(on day: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: day)
        let count = logs.filter { calendar.isDate($0.date, inSameDayAs: start) }.count
        return count >= targetPerDay
    }

    func todayCount(_ today: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: today)
        return logs.filter { calendar.isDate($0.date, inSameDayAs: start) }.count
    }

    func streak(today: Date, calendar: Calendar) -> Int {
        var d = calendar.startOfDay(for: today)
        var s = 0
        while didSatisfy(on: d, calendar: calendar) {
            s += 1
            d = calendar.date(byAdding: .day, value: -1, to: d)!
        }
        return s
    }
}

// MARK: - Feature: NewItem

@Reducer
struct NewItemFeature {
    @ObservableState
    struct State: Equatable {
        var title = ""
        var icon = "checkmark.circle.fill"
        var color: Color = .blue
        var tagsText = ""
        var targetPerDay = 1
        var notes = ""
        var reminderEnabled = false
        var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
        var isIconPickerPresented = false
        var photoData: Data? = nil
        var selectedPhotoItem: PhotosPickerItem? = nil // 新增
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case cancelTapped
        case addTapped
        case iconPickerPresented(Bool)
        case iconPicked(String)
        case delegate(Delegate)
        case photoPicked(PhotosPickerItem?) // 新增
        case loadPhotoData(TaskResult<Data?>) // 新增
    }

    enum Delegate: Equatable {
        case added(Item)
        case cancel
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .iconPickerPresented(let flag):
                state.isIconPickerPresented = flag
                return .none

            case .iconPicked(let s):
                state.icon = s
                state.isIconPickerPresented = false
                return .none

            case .cancelTapped:
                return .send(.delegate(.cancel))

            case .addTapped:
                let tags = state.tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let new = Item(
                    title: state.title,
                    icon: state.icon,
                    color: state.color,
                    tags: tags,
                    targetPerDay: state.targetPerDay,
                    notes: state.notes,
                    reminderEnabled: state.reminderEnabled,
                    reminderTime: state.reminderTime,
                    logs: [],
                    photoData: state.photoData
                )
                return .send(.delegate(.added(new)))

            case .photoPicked(let item):
                state.selectedPhotoItem = item
                guard let item else { return .none }
                return .run { send in
                    let data = try? await item.loadTransferable(type: Data.self)
                    await send(.loadPhotoData(.success(data)))
                }

            case .loadPhotoData(.success(let data)):
                state.photoData = data
                return .none

            case .loadPhotoData(.failure):
                // 可选：错误处理
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Feature: EditItem

@Reducer
struct EditItemFeature {
    @ObservableState
    struct State: Equatable {
        var id: UUID
        var logs: [ItemLog]

        var title: String
        var icon: String
        var color: Color
        var tagsText: String
        var targetPerDay: Int
        var notes: String
        var reminderEnabled: Bool
        var reminderTime: Date
        var isIconPickerPresented = false
        var photoData: Data? = nil
        var selectedPhotoItem: PhotosPickerItem? = nil

        init(item: Item) {
            self.id = item.id
            self.logs = item.logs
            self.title = item.title
            self.icon = item.icon
            self.color = item.color.color
            self.tagsText = item.tags.joined(separator: ", ")
            self.targetPerDay = item.targetPerDay
            self.notes = item.notes
            self.reminderEnabled = item.reminderEnabled
            self.reminderTime = item.reminderTime
            self.photoData = item.photoData
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case cancelTapped
        case saveTapped
        case iconPickerPresented(Bool)
        case iconPicked(String)
        case delegate(Delegate)
        case photoPicked(PhotosPickerItem?)
        case loadPhotoData(TaskResult<Data?>)
        case removePhotoTapped
    }

    enum Delegate: Equatable {
        case updated(Item)
        case cancel
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .iconPickerPresented(let flag):
                state.isIconPickerPresented = flag
                return .none

            case .iconPicked(let s):
                state.icon = s
                state.isIconPickerPresented = false
                return .none

            case .cancelTapped:
                return .send(.delegate(.cancel))

            case .saveTapped:
                let tags = state.tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let updated = Item(
                    id: state.id,
                    title: state.title,
                    icon: state.icon,
                    color: state.color,
                    tags: tags,
                    targetPerDay: state.targetPerDay,
                    notes: state.notes,
                    reminderEnabled: state.reminderEnabled,
                    reminderTime: state.reminderTime,
                    logs: state.logs,
                    photoData: state.photoData
                )
                return .send(.delegate(.updated(updated)))

            case .photoPicked(let item):
                state.selectedPhotoItem = item
                guard let item else { return .none }
                return .run { send in
                    let data = try? await item.loadTransferable(type: Data.self)
                    await send(.loadPhotoData(.success(data)))
                }

            case .loadPhotoData(.success(let data)):
                state.photoData = data
                return .none

            case .removePhotoTapped:
                state.photoData = nil
                return .none

            case .loadPhotoData(.failure):
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Feature: Items (Root)

@Reducer
struct ItemsFeature {
    @ObservableState
    struct State: Equatable {
        var items: IdentifiedArrayOf<Item> = []
        var sort: Sort = .newest
        @Presents var newItem: NewItemFeature.State? = nil
        @Presents var editItem: EditItemFeature.State? = nil

        enum Sort: String, CaseIterable, Equatable, Identifiable { case newest, streak, weekly; var id: String { rawValue } }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case plusTapped
        case newItem(PresentationAction<NewItemFeature.Action>)
        case editItem(PresentationAction<EditItemFeature.Action>)
        case editButtonTapped(id: Item.ID)
        case toggleCheck(id: Item.ID)
        case removeTodayLog(id: Item.ID)
    }

    @Dependency(\.date) var date
    @Dependency(\.calendar) var calendar

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .plusTapped:
                state.newItem = .init()
                return .none

            case .newItem(.presented(.delegate(.cancel))):
                state.newItem = nil
                return .none

            case .newItem(.presented(.delegate(.added(let item)))):
                state.items.insert(item, at: 0)
                state.newItem = nil
                return .none

            case .newItem:
                return .none

            case let .editButtonTapped(id):
                guard let item = state.items[id: id] else { return .none }
                state.editItem = .init(item: item)
                return .none

            case .editItem(.presented(.delegate(.cancel))):
                state.editItem = nil
                return .none

            case .editItem(.presented(.delegate(.updated(let updated)))):
                state.items[id: updated.id] = updated
                state.editItem = nil
                return .none

            case .editItem:
                return .none

            case let .toggleCheck(id):
                guard var i = state.items[id: id] else { return .none }
                let today = calendar.startOfDay(for: date.now)
                let count = i.logs.filter { calendar.isDate($0.date, inSameDayAs: today) }.count
                if count >= i.targetPerDay {
                    if let idx = i.logs.lastIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) { i.logs.remove(at: idx) }
                } else {
                    i.logs.append(.init(date: date.now))
                }
                state.items[id: id] = i
                return .none

            case let .removeTodayLog(id):
                guard var i = state.items[id: id] else { return .none }
                let today = calendar.startOfDay(for: date.now)
                if let idx = i.logs.lastIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) { i.logs.remove(at: idx) }
                state.items[id: id] = i
                return .none
            }
        }
        .ifLet(\.$newItem, action: \.newItem) { NewItemFeature() }
        .ifLet(\.$editItem, action: \.editItem) { EditItemFeature() }
    }
}

// MARK: - Views

struct ItemsView: View {
    @Bindable var store: StoreOf<ItemsFeature>

    var body: some View {
        NavigationStack {
            WithPerceptionTracking {
                Group {
                    if store.items.isEmpty {
                        EmptyStateView(onNew: { store.send(.plusTapped) })
                    } else {
                        ItemsListView(store: store)
                    }
                }
                .navigationTitle("Items")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { store.send(.plusTapped) } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                    }
                }
            }
        }
        .sheet(store: store.scope(state: \.$newItem, action: \.newItem)) { newStore in
            NewItemView(store: newStore)
        }
        .sheet(store: store.scope(state: \.$editItem, action: \.editItem)) { editStore in
            EditItemView(store: editStore)
        }
    }
}

// Empty state (Screen 1)
struct EmptyStateView: View {
    var onNew: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checklist").font(.system(size: 64)).foregroundStyle(.gray)
            Text("Start tracking your items").font(.largeTitle).bold()
            Text("Create your first item and monitor your usage streaks.")
                .foregroundStyle(.secondary)
            Button(action: onNew) { Label("New Item", systemImage: "plus").fontWeight(.semibold) }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// New Item sheet (Screen 2)
struct NewItemView: View {
    @Bindable var store: StoreOf<NewItemFeature>

    var body: some View {
        NavigationStack {
            WithPerceptionTracking {
                Form {
                    Section("Photo") {
                        HStack {
                            if let data = store.photoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3)))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "photo")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.gray)
                                }
                            }
                            PhotosPicker(
                                selection: $store.selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("拍照或选照片", systemImage: "camera")
                            }
                        }
                    }

                    Section("Basics") {
                        TextField("Title", text: $store.title)
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: store.icon).foregroundStyle(store.color)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { store.send(.iconPickerPresented(true)) }

                        ColorPicker("Color", selection: $store.color, supportsOpacity: false)
                        TextField("Tags (comma separated)", text: $store.tagsText)
                    }

                    Stepper(value: $store.targetPerDay, in: 1...10) { HStack { Text("Target per day: "); Text("\(store.targetPerDay)") } }

                    Section("Notes") {
                        TextField("Optional notes", text: $store.notes, axis: .vertical).lineLimit(3...6)
                    }

                    Section("Reminder") {
                        Toggle("Enable daily reminder", isOn: $store.reminderEnabled)
                        if store.reminderEnabled {
                            DatePicker("Time", selection: $store.reminderTime, displayedComponents: .hourAndMinute)
                        } else {
                            HStack { Text("Time"); Spacer(); Text(store.reminderTime.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary) }
                        }
                    }
                }
                .navigationTitle("New Item")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { store.send(.cancelTapped) } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add") { store.send(.addTapped) }.disabled(store.title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .onChange(of: store.selectedPhotoItem) { old, new in
            if old != new {
                store.send(.photoPicked(new))
            }
        }
    }
}

// Edit Item sheet
struct EditItemView: View {
    @Bindable var store: StoreOf<EditItemFeature>

    var body: some View {
        NavigationStack {
            WithPerceptionTracking {
                Form {
                    Section("Photo") {
                        HStack(spacing: 12) {
                            if let data = store.photoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3)))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "photo")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.gray)
                                }
                            }
                            PhotosPicker(
                                selection: $store.selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("更換照片", systemImage: "camera")
                            }
                            if store.photoData != nil {
                                Button(role: .destructive) {
                                    store.send(.removePhotoTapped)
                                } label: {
                                    Label("移除照片", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Section("Basics") {
                        TextField("Title", text: $store.title)
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: store.icon).foregroundStyle(store.color)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { store.send(.iconPickerPresented(true)) }

                        ColorPicker("Color", selection: $store.color, supportsOpacity: false)
                        TextField("Tags (comma separated)", text: $store.tagsText)
                    }

                    Stepper(value: $store.targetPerDay, in: 1...10) { HStack { Text("Target per day: "); Text("\(store.targetPerDay)") } }

                    Section("Notes") {
                        TextField("Optional notes", text: $store.notes, axis: .vertical).lineLimit(3...6)
                    }

                    Section("Reminder") {
                        Toggle("Enable daily reminder", isOn: $store.reminderEnabled)
                        if store.reminderEnabled {
                            DatePicker("Time", selection: $store.reminderTime, displayedComponents: .hourAndMinute)
                        } else {
                            HStack { Text("Time"); Spacer(); Text(store.reminderTime.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary) }
                        }
                    }
                }
                .navigationTitle("Edit Item")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { store.send(.cancelTapped) } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") { store.send(.saveTapped) }.disabled(store.title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .onChange(of: store.selectedPhotoItem) { old, new in
            if old != new {
                store.send(.photoPicked(new))
            }
        }
    }
}

// Minimal SF Symbol picker – quick grid (stateless)
struct SFSymbolPickerTCA: View {
    var onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let symbols = [
        "checkmark.circle.fill","flame.fill","sun.min.fill","moon.fill","book.fill","leaf.fill","dumbbell.fill","bicycle","heart.fill","cup.and.saucer.fill","bed.double.fill","brain.head.profile"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 60)), count: 4), spacing: 20) {
                    ForEach(symbols, id: \.self) { s in
                        Button { onPick(s); dismiss() } label: {
                            Image(systemName: s).font(.system(size: 28))
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }.padding()
            }
            .navigationTitle("Choose Icon")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

// List (Screen 3)
struct ItemsListView: View {
    @Bindable var store: StoreOf<ItemsFeature>
    @Dependency(\.date) private var date
    @Dependency(\.calendar) private var calendar

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                if let top = store.items.sorted(by: { $0.streak(today: date.now, calendar: calendar) > $1.streak(today: date.now, calendar: calendar) }).first {
                    LeaderboardRow(item: top, calendar: calendar, now: date.now)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                Picker("Sort", selection: $store.sort) {
                    Text("Newest").tag(ItemsFeature.State.Sort.newest)
                    Text("Streak").tag(ItemsFeature.State.Sort.streak)
                    Text("Weekly %").tag(ItemsFeature.State.Sort.weekly)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 6)

                List {
                    ForEach(sortedItems()) { item in
                        ItemRow(item: item, calendar: calendar, now: date.now) {
                            store.send(.toggleCheck(id: item.id))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                store.send(.editButtonTapped(id: item.id))
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .safeAreaInset(edge: .bottom) { SearchBar() }
        }
    }

    private func weeklyPercent(_ i: Item) -> Double {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: date.now))!
        let days = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! }
        let hits = days.filter { i.didSatisfy(on: $0, calendar: calendar) }.count
        return Double(hits) / 7.0
    }

    private func sortedItems() -> [Item] {
        switch store.sort {
        case .newest:
            return Array(store.items)
        case .streak:
            return store.items.sorted { $0.streak(today: date.now, calendar: calendar) > $1.streak(today: date.now, calendar: calendar) }
        case .weekly:
            return store.items.sorted { weeklyPercent($0) > weeklyPercent($1) }
        }
    }
}

struct LeaderboardRow: View {
    let item: Item
    let calendar: Calendar
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            // 优先显示照片
            if let data = item.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.gray.opacity(0.15)))
            } else {
                Image(systemName: item.icon).foregroundStyle(item.color.color)
                    .font(.system(size: 28))
                    .frame(width: 36, height: 36)
            }
            Text(item.title).font(.headline)
            Spacer()
            Image(systemName: "flame.fill").foregroundStyle(.orange)
            Text("\(item.streak(today: now, calendar: calendar))").fontWeight(.semibold)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ItemRow: View {
    let item: Item
    let calendar: Calendar
    let now: Date
    var onTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 左侧显示照片或icon
            if let data = item.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15)))
            } else {
                Image(systemName: item.icon)
                    .foregroundStyle(item.color.color)
                    .font(.system(size: 28))
                    .frame(width: 40, height: 40)
            }

            Button(action: onTap) {
                Image(systemName: item.didSatisfy(on: now, calendar: calendar) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.color.color)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title).font(.headline)
                ProgressDots(item: item, calendar: calendar, now: now)
            }
            Spacer()
            Text("\(item.todayCount(now, calendar: calendar))/\(item.targetPerDay)")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct ProgressDots: View {
    let item: Item
    let calendar: Calendar
    let now: Date

    var body: some View {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let d = calendar.date(byAdding: .day, value: i, to: start)!
                Circle()
                    .fill(item.didSatisfy(on: d, calendar: calendar) ? item.color.color : Color(.systemGray5))
                    .frame(width: 8, height: 8)
                    .opacity(calendar.isDateInToday(d) ? 1 : 0.9)
            }
        }
    }
}

struct SearchBar: View {
    @State private var text = ""
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search title or tags…", text: $text)
        }
        .padding(12)
        .background(Color(.systemGray6), in: Capsule())
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - App Entry

struct ItemsAppView: View {
    let store: StoreOf<ItemsFeature>
    var body: some View { ItemsView(store: store) }
}

// MARK: - Previews

#Preview("TCA – Empty") {
    ItemsAppView(
        store: Store(initialState: ItemsFeature.State()) { ItemsFeature() }
    )
}

#Preview("TCA – List") {
    var state = ItemsFeature.State()
    state.items = [
        Item(id: UUID(), title: "Aaa", logs: [ItemLog(date: .now)]),
        Item(title: "Read 20 min", icon: "book.fill", color: .green, targetPerDay: 1, logs: []),
        Item(title: "Drink Water", icon: "drop.fill", color: .teal, targetPerDay: 8, logs: [])
    ].identifiedArray

    return ItemsAppView(
        store: Store(initialState: state) { ItemsFeature() }
    )
}

private extension Array where Element == Item {
    var identifiedArray: IdentifiedArrayOf<Item> { .init(uniqueElements: self) }
}
