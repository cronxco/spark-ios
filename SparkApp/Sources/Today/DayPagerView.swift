import SparkKit
import SparkUI
import SwiftUI

struct DayPagerView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedOffset: Int = 0
    @State private var dates: [DayKey] = DayKey.defaultWindow()
    @State private var path: [EventRoute] = []

    var body: some View {
        @Bindable var appModel = appModel
        NavigationStack(path: $path) {
            TabView(selection: $selectedOffset) {
                ForEach(dates) { key in
                    TodayView(date: key.date)
                        .tag(key.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: EventRoute.self) { route in
                EventDetailView(eventId: route.id)
            }
        }
        .onChange(of: appModel.pendingRoute) { _, route in
            apply(route: route)
        }
        .onAppear {
            apply(route: appModel.pendingRoute)
        }
    }

    private func apply(route: AppRoute?) {
        guard let route else { return }
        switch route {
        case .today(let date):
            jump(to: date ?? .now)
        case .day(let date):
            jump(to: date)
        case .event(let id):
            path.append(EventRoute(id: id))
        }
        appModel.pendingRoute = nil
    }

    private func jump(to date: Date) {
        if let match = dates.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            selectedOffset = match.offset
            return
        }
        // Outside the default window — rebuild anchored on the requested date.
        dates = DayKey.window(anchor: date)
        selectedOffset = 0
    }
}

struct EventRoute: Hashable {
    let id: String
}

private struct DayKey: Identifiable, Hashable {
    let offset: Int
    let date: Date
    let label: String

    var id: Int { offset }

    static func defaultWindow(anchor: Date = .now, calendar: Calendar = .current) -> [DayKey] {
        (-7 ... 0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: anchor) else { return nil }
            return DayKey(offset: offset, date: date, label: Self.label(for: date, offset: offset))
        }
    }

    static func window(anchor: Date, calendar: Calendar = .current) -> [DayKey] {
        (0 ..< 8).compactMap { i in
            let offset = -i
            guard let date = calendar.date(byAdding: .day, value: offset, to: anchor) else { return nil }
            return DayKey(offset: offset, date: date, label: Self.label(for: date, offset: offset))
        }.sorted(by: { $0.offset < $1.offset })
    }

    private static func label(for date: Date, offset: Int) -> String {
        if offset == 0 { return "Today" }
        if offset == -1 { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: date)
    }
}
