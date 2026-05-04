import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct DayPagerView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedOffset: Int = 0
    @State private var dates: [DayKey] = DayKey.defaultWindow()
    @State private var path: [DetailRoute] = []
    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        @Bindable var appModel = appModel
        ZStack {
            SparkResolvedAppBackground()

            NavigationStack(path: $path) {
                ZStack {
                    SparkResolvedAppBackground()

                    GeometryReader { proxy in
                        dayPages(width: proxy.size.width)
                    }
                    .ignoresSafeArea()
                }
                .ignoresSafeArea()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
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
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onChange(of: appModel.pendingRoute) { _, route in
            apply(route: route)
        }
        .onAppear {
            apply(route: appModel.pendingRoute)
        }
    }

    private var selectedDay: DayKey {
        dates.first(where: { $0.offset == selectedOffset }) ?? dates.first ?? DayKey(date: .now, offset: 0)
    }

    private var visibleDays: [DayKey] {
        guard let index = dates.firstIndex(where: { $0.offset == selectedOffset }) else {
            return [selectedDay]
        }

        let lower = max(dates.startIndex, index - 1)
        let upper = min(dates.index(before: dates.endIndex), index + 1)
        return Array(dates[lower ... upper])
    }

    @ViewBuilder
    private func dayPages(width: CGFloat) -> some View {
        let pages = visibleDays
        let selectedIndex = pages.firstIndex(where: { $0.offset == selectedOffset }) ?? 0

        HStack(spacing: 0) {
            ForEach(pages) { key in
                TodayView(date: key.date, showsToolbar: key.offset == selectedOffset)
                    .frame(width: width)
            }
        }
        .offset(x: -CGFloat(selectedIndex) * width + boundedDragTranslation(width: width))
        .animation(.interactiveSpring(response: 0.36, dampingFraction: 0.88), value: selectedOffset)
        .frame(width: width, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(daySwipeGesture(width: width))
    }

    private func daySwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) else { return }

                let projected = value.predictedEndTranslation.width
                let threshold = min(max(width * 0.18, 72), 132)
                let shouldPage = abs(horizontal) > threshold || abs(projected) > threshold * 1.35
                guard shouldPage else { return }

                let step = horizontal < 0 ? 1 : -1
                selectAdjacentDay(step: step)
            }
    }

    private func boundedDragTranslation(width: CGFloat) -> CGFloat {
        let hasPrevious = previousDay != nil
        let hasNext = nextDay != nil
        if dragTranslation > 0, !hasPrevious {
            return rubberBand(dragTranslation, limit: width)
        }
        if dragTranslation < 0, !hasNext {
            return -rubberBand(abs(dragTranslation), limit: width)
        }
        return dragTranslation
    }

    private func rubberBand(_ distance: CGFloat, limit: CGFloat) -> CGFloat {
        let constant = max(limit, 1)
        return (distance * 0.35 * constant) / (constant + distance * 0.35)
    }

    private var previousDay: DayKey? {
        guard let index = dates.firstIndex(where: { $0.offset == selectedOffset }),
              index > dates.startIndex
        else { return nil }
        return dates[dates.index(before: index)]
    }

    private var nextDay: DayKey? {
        guard let index = dates.firstIndex(where: { $0.offset == selectedOffset }) else { return nil }
        let next = dates.index(after: index)
        guard next < dates.endIndex else { return nil }
        return dates[next]
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
        if path.last == route { return }
        path.append(route)
    }

    private func jump(to date: Date) {
        if let match = dates.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            selectedOffset = match.offset
            return
        }
        dates = DayKey.window(anchor: date)
        selectedOffset = 0
    }

    private func selectAdjacentDay(step: Int) {
        guard let index = dates.firstIndex(where: { $0.offset == selectedOffset }) else { return }
        let next = index + step
        guard dates.indices.contains(next) else { return }
        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.88)) {
            selectedOffset = dates[next].offset
        }
    }
}

/// Detail destinations pushed onto the Day tab's `NavigationStack`.
enum DetailRoute: Hashable {
    case event(id: String)
    case object(id: String)
    case block(id: String)
    case metric(identifier: String)
    case place(id: String)
    case integration(service: String)
}

private struct DayKey: Identifiable, Hashable {
    let date: Date
    let offset: Int
    let label: String

    var id: Int { offset }

    init(date: Date, offset: Int, label: String? = nil) {
        self.date = date
        self.offset = offset
        self.label = label ?? Self.label(for: date, offset: offset)
    }

    static func defaultWindow(anchor: Date = .now, calendar: Calendar = .current) -> [DayKey] {
        (-7 ... 1).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: anchor) else { return nil }
            return DayKey(date: date, offset: offset)
        }
    }

    static func window(anchor: Date, calendar: Calendar = .current) -> [DayKey] {
        (0 ..< 8).compactMap { i in
            let offset = -i
            guard let date = calendar.date(byAdding: .day, value: offset, to: anchor) else { return nil }
            return DayKey(date: date, offset: offset)
        }.sorted(by: { $0.offset < $1.offset })
    }

    private static func label(for date: Date, offset: Int) -> String {
        if offset == 1 { return "Tomorrow" }
        if offset == 0 { return "Today" }
        if offset == -1 { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: date)
    }
}
