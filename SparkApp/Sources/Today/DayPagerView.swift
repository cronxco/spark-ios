import SparkKit
import SparkUI
import SwiftUI

struct DayPagerView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedOffset: Int = 0
    @State private var dates: [DayKey] = DayKey.defaultWindow()
    @State private var path: [DetailRoute] = []

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
            .navigationDestination(for: DetailRoute.self) { route in
                switch route {
                case .event(let id):
                    EventDetailView(eventId: id)
                case .object(let id):
                    ObjectDetailView(objectId: id)
                case .block(let id):
                    BlockDetailView(blockId: id)
                case .metric(let identifier):
                    MetricDetailView(identifier: identifier)
                case .place(let id):
                    PlaceDetailView(placeId: id)
                case .integration(let service):
                    IntegrationDetailView(integrationId: service)
                }
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
            push(.event(id: id))
        case .object(let id):
            push(.object(id: id))
        case .block(let id):
            push(.block(id: id))
        case .metric(let identifier):
            push(.metric(identifier: identifier))
        case .place(let id):
            push(.place(id: id))
        case .integration(let service):
            push(.integration(service: service))
        }
        appModel.pendingRoute = nil
    }

    private func push(_ route: DetailRoute) {
        // Avoid duplicate pushes when the deep link fires twice in quick
        // succession (Safari sometimes dispatches scene + onOpenURL).
        if path.last == route { return }
        path.append(route)
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

/// Detail destinations pushed onto the Today tab's `NavigationStack`. New
/// detail surfaces should add a case here and a destination clause above.
enum DetailRoute: Hashable {
    case event(id: String)
    case object(id: String)
    case block(id: String)
    case metric(identifier: String)
    case place(id: String)
    case integration(service: String)
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
