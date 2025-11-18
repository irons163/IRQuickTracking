import SwiftUI
import ComposableArchitecture

// MARK: - Models

public struct Habit: Equatable, Identifiable, Hashable, Codable {
    public let id: UUID
    public var title: String
    public var icon: String
    public var color: ColorData
    public var tags: [String]
    public var targetPerDay: Int
    public var notes: String
    public var reminderEnabled: Bool
    public var reminderTime: Date
    public var logs: [HabitLog]

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
        logs: [HabitLog] = []
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
    }
}

public struct HabitLog: Equatable, Identifiable, Hashable, Codable {
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

extension Habit {
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

// MARK: - Feature: NewHabit

@Reducer
struct NewHabitFeature {
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
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case cancelTapped
        case addTapped
        case iconPickerPresented(Bool)
        case iconPicked(String)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case added(Habit)
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
                let new = Habit(
                    title: state.title,
                    icon: state.icon,
                    color: state.color,
                    tags: tags,
                    targetPerDay: state.targetPerDay,
                    notes: state.notes,
                    reminderEnabled: state.reminderEnabled,
                    reminderTime: state.reminderTime,
                    logs: []
                )
                return .send(.delegate(.added(new)))

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Feature: Habits (Root)

@Reducer
struct HabitsFeature {
    @ObservableState
    struct State: Equatable {
        var habits: IdentifiedArrayOf<Habit> = []
        var sort: Sort = .newest
        @Presents var newHabit: NewHabitFeature.State? = nil

        enum Sort: String, CaseIterable, Equatable, Identifiable { case newest, streak, weekly; var id: String { rawValue } }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case plusTapped
        case newHabit(PresentationAction<NewHabitFeature.Action>)
        case toggleCheck(id: Habit.ID)
        case removeTodayLog(id: Habit.ID)
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
                state.newHabit = .init()
                return .none

            case .newHabit(.presented(.delegate(.cancel))):
                state.newHabit = nil
                return .none

            case .newHabit(.presented(.delegate(.added(let habit)))):
                state.habits.insert(habit, at: 0)
                state.newHabit = nil
                return .none

            case .newHabit:
                return .none

            case let .toggleCheck(id):
                guard var h = state.habits[id: id] else { return .none }
                let today = calendar.startOfDay(for: date.now)
                let count = h.logs.filter { calendar.isDate($0.date, inSameDayAs: today) }.count
                if count >= h.targetPerDay {
                    if let idx = h.logs.lastIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) { h.logs.remove(at: idx) }
                } else {
                    h.logs.append(.init(date: date.now))
                }
                state.habits[id: id] = h
                return .none

            case let .removeTodayLog(id):
                guard var h = state.habits[id: id] else { return .none }
                let today = calendar.startOfDay(for: date.now)
                if let idx = h.logs.lastIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) { h.logs.remove(at: idx) }
                state.habits[id: id] = h
                return .none
            }
        }
        .ifLet(\.$newHabit, action: \.newHabit) { NewHabitFeature() }
    }
}

// MARK: - Views

struct HabitsView: View {
    @Bindable var store: StoreOf<HabitsFeature>

    var body: some View {
        NavigationStack {
            WithPerceptionTracking {
                Group {
                    if store.habits.isEmpty {
                        EmptyStateView(onNew: { store.send(.plusTapped) })
                    } else {
                        HabitsListView(store: store)
                    }
                }
                .navigationTitle("Habits")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { store.send(.plusTapped) } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                    }
                }
            }
        }
        .sheet(store: store.scope(state: \.$newHabit, action: \.newHabit)) { newStore in
            NewHabitView(store: newStore)
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
            Text("Build better days").font(.largeTitle).bold()
            Text("Create your first habit and track your streaks.")
                .foregroundStyle(.secondary)
            Button(action: onNew) { Label("New Habit", systemImage: "plus").fontWeight(.semibold) }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// New Habit sheet (Screen 2)
struct NewHabitView: View {
    @Bindable var store: StoreOf<NewHabitFeature>

    var body: some View {
        NavigationStack {
            WithPerceptionTracking {
                Form {
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
                .navigationTitle("New Habit")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { store.send(.cancelTapped) } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add") { store.send(.addTapped) }.disabled(store.title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
                // icon picker presented via TCA sheet in parent, so we don't need another sheet here.
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
struct HabitsListView: View {
    @Bindable var store: StoreOf<HabitsFeature>
    @Dependency(\.date) private var date
    @Dependency(\.calendar) private var calendar

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                if let top = store.habits.sorted(by: { $0.streak(today: date.now, calendar: calendar) > $1.streak(today: date.now, calendar: calendar) }).first {
                    LeaderboardRow(habit: top, calendar: calendar, now: date.now)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                Picker("Sort", selection: $store.sort) {
                    Text("Newest").tag(HabitsFeature.State.Sort.newest)
                    Text("Streak").tag(HabitsFeature.State.Sort.streak)
                    Text("Weekly %").tag(HabitsFeature.State.Sort.weekly)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 6)

                List {
                    ForEach(sortedHabits()) { habit in
                        HabitRow(habit: habit, calendar: calendar, now: date.now) {
                            store.send(.toggleCheck(id: habit.id))
                        }
                    }
                }
                .listStyle(.plain)
            }
            .safeAreaInset(edge: .bottom) { SearchBar() }
        }
    }

    private func weeklyPercent(_ h: Habit) -> Double {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: date.now))!
        let days = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! }
        let hits = days.filter { h.didSatisfy(on: $0, calendar: calendar) }.count
        return Double(hits) / 7.0
    }

    private func sortedHabits() -> [Habit] {
        switch store.sort {
        case .newest:
            return Array(store.habits)
        case .streak:
            return store.habits.sorted { $0.streak(today: date.now, calendar: calendar) > $1.streak(today: date.now, calendar: calendar) }
        case .weekly:
            return store.habits.sorted { weeklyPercent($0) > weeklyPercent($1) }
        }
    }
}

struct LeaderboardRow: View {
    let habit: Habit
    let calendar: Calendar
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: habit.icon).foregroundStyle(habit.color.color)
            Text(habit.title).font(.headline)
            Spacer()
            Image(systemName: "flame.fill").foregroundStyle(.orange)
            Text("\(habit.streak(today: now, calendar: calendar))").fontWeight(.semibold)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct HabitRow: View {
    let habit: Habit
    let calendar: Calendar
    let now: Date
    var onTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onTap) {
                Image(systemName: habit.didSatisfy(on: now, calendar: calendar) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(habit.color.color)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(habit.title).font(.headline)
                ProgressDots(habit: habit, calendar: calendar, now: now)
            }
            Spacer()
            Text("\(habit.todayCount(now, calendar: calendar))/\(habit.targetPerDay)")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct ProgressDots: View {
    let habit: Habit
    let calendar: Calendar
    let now: Date

    var body: some View {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let d = calendar.date(byAdding: .day, value: i, to: start)!
                Circle()
                    .fill(habit.didSatisfy(on: d, calendar: calendar) ? habit.color.color : Color(.systemGray5))
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

struct HabitsAppView: View {
    let store: StoreOf<HabitsFeature>
    var body: some View { HabitsView(store: store) }
}

// MARK: - Previews

#Preview("TCA – Empty") {
    HabitsAppView(
        store: Store(initialState: HabitsFeature.State()) { HabitsFeature() }
    )
}

#Preview("TCA – List") {
    var state = HabitsFeature.State()
    state.habits = [
        Habit(id: UUID(), title: "Aaa", logs: [HabitLog(date: .now)]),
        Habit(title: "Read 20 min", icon: "book.fill", color: .green, targetPerDay: 1, logs: []),
        Habit(title: "Drink Water", icon: "drop.fill", color: .teal, targetPerDay: 8, logs: [])
    ].identifiedArray

    return HabitsAppView(
        store: Store(initialState: state) { HabitsFeature() }
    )
}

private extension Array where Element == Habit {
    var identifiedArray: IdentifiedArrayOf<Habit> { .init(uniqueElements: self) }
}
