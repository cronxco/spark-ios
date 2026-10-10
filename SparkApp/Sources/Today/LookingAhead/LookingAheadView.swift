import SparkKit
import SparkUI
import SwiftUI

/// The Day tab's page for a day that has not happened yet.
///
/// This used to be the Today layout with "Looking ahead" for a title, so it
/// showed empty metrics, a "Baselines holding" line, check-ins to log and a
/// heatmap of the past — none of which can mean anything for tomorrow. It
/// now shows what Spark already knows about the day: the schedule, the plan,
/// the weather, and a bedtime target when tomorrow starts early.
struct LookingAheadView: View {
    let date: Date
    var showsToolbar = true
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var viewModel: LookingAheadViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                hero

                if let ahead = viewModel?.ahead {
                    content(ahead)
                } else {
                    loadingOrError
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.sm)
            .padding(.bottom, SparkSpacing.xl)
            .containerRelativeFrame(.horizontal)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await viewModel?.refresh() }
        .sparkMainAppToolbar(isVisible: showsToolbar)
        .task(id: date) {
            if viewModel == nil {
                viewModel = LookingAheadViewModel(date: date, apiClient: appModel.apiClient, container: appModel.container)
            }
            await viewModel?.load()
        }
        .onChange(of: appModel.lastSyncAt) {
            Task { await viewModel?.load() }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            VStack(alignment: .leading, spacing: 0) {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .foregroundStyle(colorScheme == .dark ? AnyShapeStyle(Color.spark2) : AnyShapeStyle(.primary))
                Text(date.formatted(.dateTime.day().month(.wide)))
                    .foregroundStyle(.secondary)
            }
            .font(Font.custom(SparkFonts.displayPostScriptName, size: 32, relativeTo: .largeTitle).weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.88)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if let headline = viewModel?.ahead?.headline, !headline.isEmpty {
                Text(headline)
                    .font(SparkTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ ahead: DayAhead) -> some View {
        AheadGlanceStrip(ahead: ahead)

        if ahead.hasSchedule {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                SectionLabel("Schedule", style: .dayHeading)
                ScheduleTimeline(entries: ahead.calendar, birthdays: ahead.birthdays) { eventID in
                    appModel.pendingRoute = .event(id: eventID)
                }
            }
        } else {
            emptySchedule(ahead)
        }

        if !ahead.plan.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                SectionLabel("Plan", style: .dayHeading)
                PlanList(items: ahead.plan, dayNoteURL: ahead.dayNoteURL) { openURL($0) }
            }
        }

        if let target = ahead.sleepTarget {
            SleepTargetCard(target: target, firstCommitment: ahead.firstCommitment)
        }

        if let vm = viewModel, !vm.questions.isEmpty {
            FlintQuestionStack(
                questions: vm.questions,
                onAnswer: { question, option in
                    Task { await vm.answer(question: question, with: option) }
                },
                onOpen: {}
            )
        }
    }

    private func emptySchedule(_ ahead: DayAhead) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text("Nothing on the calendar for \(date.formatted(.dateTime.weekday(.wide)))")
                .font(SparkTypography.bodyStrong)
            if let url = ahead.dayNoteURL {
                Button("Open the day note") { openURL(url) }
                    .font(SparkTypography.bodySmall)
                    .tint(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.lg)
        .sparkGlass(.roundedRect(SparkRadii.lg))
    }

    @ViewBuilder
    private var loadingOrError: some View {
        switch viewModel?.networkState {
        case .error(let message):
            EmptyState(
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn't load \(date.formatted(.dateTime.weekday(.wide)))",
                message: message,
                actionTitle: "Retry"
            ) { Task { await viewModel?.refresh() } }
        default:
            VStack(spacing: SparkSpacing.md) {
                LoadingShimmerCard()
                LoadingShimmerCard()
            }
        }
    }
}

// MARK: - Glance strip

/// Weather, the first commitment and how much is on, as three chips.
struct AheadGlanceStrip: View {
    let ahead: DayAhead

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SparkSpacing.sm) { chips }
            VStack(alignment: .leading, spacing: SparkSpacing.sm) { chips }
        }
    }

    @ViewBuilder
    private var chips: some View {
        if let weather = ahead.weather, weather.hasContent {
            chip(
                symbol: DayContextSection.symbol(for: weather.condition, rainProbability: weather.rainProbabilityPct),
                text: weatherText(weather),
                tint: .sparkOcean
            )
        }
        if let start = ahead.firstCommitment?.startDate {
            chip(symbol: "clock", text: "First up \(start.formatted(date: .omitted, time: .shortened))", tint: .sparkAccent)
        }
        let count = ahead.calendar.count + ahead.openPlanCount
        if count > 0 {
            chip(symbol: "list.bullet", text: count == 1 ? "1 thing" : "\(count) things", tint: .secondary)
        }
    }

    private func weatherText(_ weather: FlintDayContextWeather) -> String {
        [
            weather.tempHighC.map { "\(Int($0.rounded()))°" },
            weather.condition,
            weather.rainProbabilityPct.flatMap { $0 > 0 ? "\($0)% rain" : nil },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private func chip(symbol: String, text: String, tint: Color) -> some View {
        Label {
            Text(text).font(SparkTypography.captionStrong).foregroundStyle(.primary)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
        .lineLimit(1)
        .padding(.horizontal, SparkSpacing.md)
        .padding(.vertical, SparkSpacing.sm)
        .sparkGlass(.capsule)
    }
}

// MARK: - Schedule

/// Birthdays and all-day items first, then the day in time order. Each row
/// carries a Will, Dan or Both tag when a digest has attributed it.
struct ScheduleTimeline: View {
    let entries: [DayAhead.CalendarEntry]
    let birthdays: [FlintDayContextBirthday]
    let onOpenEvent: (String) -> Void

    var body: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    rowView(row)
                    if index < rows.count - 1 {
                        Divider().opacity(0.15)
                    }
                }
            }
        }
    }

    private enum Row: Identifiable {
        case birthday(FlintDayContextBirthday)
        case entry(DayAhead.CalendarEntry)

        var id: String {
            switch self {
            case .birthday(let birthday): "birthday-\(birthday.id)"
            case .entry(let entry): entry.id
            }
        }
    }

    private var rows: [Row] {
        birthdays.map(Row.birthday) + entries.map(Row.entry)
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        switch row {
        case .birthday(let birthday):
            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
                allDayChip
                Label(birthday.title, systemImage: "birthday.cake.fill")
                    .font(SparkTypography.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .rowPadding()
        case .entry(let entry):
            if let eventID = entry.eventId {
                Button { onOpenEvent(eventID) } label: { entryRow(entry) }
                    .buttonStyle(.plain)
            } else {
                entryRow(entry)
            }
        }
    }

    private func entryRow(_ entry: DayAhead.CalendarEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
            if entry.allDay {
                allDayChip
            } else {
                Text(entry.startDate?.formatted(date: .omitted, time: .shortened) ?? "—")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 62, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(SparkTypography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let location = entry.location, !location.isEmpty {
                    Text(location)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let person = entry.person {
                PersonTag(person: person)
            }
        }
        .rowPadding()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var allDayChip: some View {
        Text("All day")
            .font(SparkTypography.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, SparkSpacing.sm)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.primary.opacity(0.07)))
            .frame(width: 62, alignment: .leading)
    }
}

/// Will, Dan or Both, in the same colours the Up to Speed day view uses.
struct PersonTag: View {
    let person: DayAhead.CalendarEntry.Person

    var body: some View {
        Text(label)
            .font(SparkTypography.captionStrong)
            .foregroundStyle(tint)
            .padding(.horizontal, SparkSpacing.sm)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    private var label: String {
        switch person {
        case .will: "Will"
        case .dan: "Dan"
        case .both: "Both"
        }
    }

    private var tint: Color {
        switch person {
        case .will: .sparkAccent
        case .dan: .sparkOcean
        case .both: .sparkSuccess
        }
    }
}

// MARK: - Plan

/// Tasks from the day note, Flint topic tasks due that day, and topics up for
/// review. Read-only: ticking off happens in the day note or the thread.
struct PlanList: View {
    let items: [DayAhead.PlanItem]
    let dayNoteURL: URL?
    let onOpen: (URL) -> Void

    var body: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(item)
                    if index < items.count - 1 {
                        Divider().opacity(0.15)
                    }
                }
                if let dayNoteURL {
                    Divider().opacity(0.15)
                    Button { onOpen(dayNoteURL) } label: {
                        Label("Open the day note", systemImage: "arrow.up.right")
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .rowPadding()
                }
            }
        }
    }

    private func row(_ item: DayAhead.PlanItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
            Image(systemName: symbol(for: item))
                .foregroundStyle(item.done ? Color.sparkSuccess : .secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(SparkTypography.body)
                    .foregroundStyle(item.done ? .secondary : .primary)
                    .strikethrough(item.done)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = detail(for: item) {
                    Text(detail)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .rowPadding()
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.done ? "Done" : "")
    }

    private func symbol(for item: DayAhead.PlanItem) -> String {
        switch item.kind {
        case .topicReview: "arrow.triangle.2.circlepath"
        default: item.done ? "checkmark.circle.fill" : "circle"
        }
    }

    private func detail(for item: DayAhead.PlanItem) -> String? {
        switch item.kind {
        case .topicTask:
            return item.topicTitle.map { "Due · \($0)" } ?? "Due"
        case .topicReview:
            return "Thread up for review"
        case .dayNote, .unknown:
            return nil
        }
    }
}

// MARK: - Sleep target

/// "Tonight sets up tomorrow": when to be in bed, and why the page is saying
/// so. The server only sends a target when there is a reason to.
struct SleepTargetCard: View {
    let target: DayAhead.SleepTarget
    let firstCommitment: DayAhead.FirstCommitment?

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionLabel("Tonight sets up tomorrow", style: .dayHeading)

            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                    Image(systemName: "bed.double.fill")
                        .foregroundStyle(Color.sparkOcean)
                    if let bedBy = target.bedByDate {
                        Text("In bed by \(bedBy.formatted(date: .omitted, time: .shortened))")
                            .font(SparkFonts.display(.title2, weight: .bold))
                    }
                }
                Text(reason)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SparkSpacing.lg)
            .sparkGlass(.roundedRect(SparkRadii.lg))
        }
    }

    private var reason: String {
        var sentences: [String] = []
        let sleep = Self.duration(minutes: target.sleepNeedMinutes)

        if target.earlyStart, let first = firstCommitment, let start = first.startDate, let wake = target.wakeByDate {
            sentences.append(
                "\(first.title) is at \(start.formatted(date: .omitted, time: .shortened)), so you'll want to be up by \(wake.formatted(date: .omitted, time: .shortened)), earlier than your usual \(target.typicalWake ?? "start")."
            )
        } else if let wake = target.wakeByDate {
            sentences.append("To be up by \(wake.formatted(date: .omitted, time: .shortened)).")
        }
        sentences.append("That gives you your usual \(sleep) of sleep.")
        if target.readinessLowNights >= 3 {
            sentences.append("Readiness has been below your average for \(target.readinessLowNights) nights running.")
        }
        return sentences.joined(separator: " ")
    }

    nonisolated static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

private extension View {
    func rowPadding() -> some View {
        padding(.horizontal, SparkSpacing.lg)
            .padding(.vertical, SparkSpacing.md)
    }
}
