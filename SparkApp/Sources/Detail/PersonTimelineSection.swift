import SparkKit
import SparkUI
import SwiftUI

/// A person's month calendar and timeline: events they act in, are tagged
/// with, or are @mentioned in. Tapping a day narrows the list to that day.
struct PersonTimelineSection: View {
    let personID: String
    let personName: String
    let apiClient: APIClient

    @State private var month = Date.now
    @State private var timeline: PersonTimeline?
    @State private var selectedDay: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var activeLoadID = UUID()

    private static let monthKey: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .iso8601)
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .iso8601)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let monthTitle: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            monthHeader
            grid
            SparkDetailSectionHeader(
                "With \(personName)",
                trailing: timeline.map { "\($0.eventCount) events" }
            )
            if let errorMessage {
                Button { Task { await load() } } label: {
                    Label(errorMessage, systemImage: "arrow.clockwise")
                        .font(SparkTypography.bodySmall).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            } else if isLoading && timeline == nil {
                ProgressView().frame(maxWidth: .infinity)
            } else if let events = timeline?.events, !events.isEmpty {
                ForEach(events) { event in
                    NavigationLink {
                        EventDetailView(eventId: event.id)
                    } label: {
                        SparkDetailLinkedRow(
                            title: rowTitle(for: event),
                            subtitle: event.time.map { SparkDetailFormatters.compactDateTime.string(from: $0) },
                            trailing: event.displayValue?.sparkPlainTextFromHTMLFragment,
                            tint: Color.domainTint(for: event.domain)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("No events.").font(SparkTypography.bodySmall).foregroundStyle(.secondary)
            }
        }
        .task(id: "\(personID):\(Self.monthKey.string(from: month)):\(selectedDay ?? "")") { await load() }
    }

    private func rowTitle(for event: Event) -> String {
        let action = event.action.sparkActionTitle
        guard event.displayWithObject,
              let target = event.target?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !target.isEmpty
        else {
            return action
        }
        return "\(action) \(target)"
    }

    private var monthHeader: some View {
        HStack {
            Text(Self.monthTitle.string(from: month))
                .font(SparkTypography.bodySmall.weight(.semibold))
            Spacer()
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous month")
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next month")
        }
        .buttonStyle(.borderless)
    }

    private var grid: some View {
        let counts = timeline?.calendar ?? [:]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, label in
                Text(label).font(SparkTypography.bodySmall).foregroundStyle(.tertiary)
            }
            ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 28) }
            ForEach(days, id: \.self) { day in
                let key = Self.dayKey.string(from: day)
                let count = counts[key] ?? 0
                Button {
                    selectedDay = selectedDay == key ? nil : key
                } label: {
                    Text("\(calendar.component(.day, from: day))")
                        .font(SparkTypography.bodySmall.weight(count > 0 ? .semibold : .regular))
                        .foregroundStyle(count > 0 ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(
                            RoundedRectangle(cornerRadius: SparkRadii.sm)
                                .fill(Color.accentColor.opacity(selectedDay == key ? 0.5 : count >= 3 ? 0.35 : count > 0 ? 0.18 : 0))
                        )
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
                .accessibilityLabel("\(key), \(count) events")
            }
        }
    }

    private var days: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let count = calendar.range(of: .day, in: .month, for: month)?.count ?? 0
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var leadingBlanks: Int {
        guard let first = days.first else { return 0 }
        return (calendar.component(.weekday, from: first) + 5) % 7
    }

    private func shift(_ by: Int) {
        selectedDay = nil
        month = calendar.date(byAdding: .month, value: by, to: month) ?? month
    }

    private func load() async {
        let loadID = UUID()
        activeLoadID = loadID
        isLoading = true
        errorMessage = nil
        defer {
            if activeLoadID == loadID { isLoading = false }
        }
        do {
            let response = try await apiClient.request(
                PeopleEndpoint.timeline(id: personID, month: Self.monthKey.string(from: month), date: selectedDay)
            )
            guard activeLoadID == loadID else { return }
            timeline = response
        } catch where error.isAPICancellation {
            return
        } catch {
            guard activeLoadID == loadID else { return }
            errorMessage = "Couldn't load the timeline. Tap to retry."
        }
    }
}
