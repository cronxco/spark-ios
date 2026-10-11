import SparkKit
import SparkUI
import SwiftUI

/// Edits when each repeating Flint routine runs: one or more local times, which days, and an
/// optional advanced cron expression. The backend checks everything before storing it.
struct FlintSchedulesView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: FlintSchedulesViewModel?

    var body: some View {
        Group {
            switch viewModel?.state {
            case .loaded(let routines):
                List {
                    Section {
                        SparkSystemScreenHeader(
                            title: "Flint schedules",
                            subtitle: "Choose when each routine runs, in your timezone. Add several times for more than one run a day."
                        )
                        .padding(.vertical, SparkSpacing.sm)
                    }
                    .listRowBackground(Color.clear)

                    ForEach(routines) { routine in
                        NavigationLink {
                            FlintScheduleEditorView(routine: routine, viewModel: viewModel!)
                        } label: {
                            routineRow(routine)
                        }
                    }
                }
            case .error(let message):
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load schedules",
                    message: message,
                    actionTitle: "Retry"
                ) { Task { await viewModel?.load() } }
            default:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Flint schedules")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = FlintSchedulesViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    private func routineRow(_ routine: FlintRoutineSchedule) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(routine.displayName).font(SparkTypography.body)
            Text(summary(routine))
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func summary(_ routine: FlintRoutineSchedule) -> String {
        guard routine.enabled else { return "Off" }
        if let next = routine.nextRun {
            return "Next run " + next.formatted(date: .abbreviated, time: .shortened)
        }
        return "On"
    }
}

private struct FlintScheduleEditorView: View {
    let routine: FlintRoutineSchedule
    let viewModel: FlintSchedulesViewModel

    @State private var enabled: Bool
    @State private var frequency: String
    @State private var days: Set<String>
    @State private var dayOfMonth: String
    @State private var times: [Date]
    @State private var cron: String

    private static let weekdays = [
        ("mon", "Monday"), ("tue", "Tuesday"), ("wed", "Wednesday"), ("thu", "Thursday"),
        ("fri", "Friday"), ("sat", "Saturday"), ("sun", "Sunday"),
    ]

    init(routine: FlintRoutineSchedule, viewModel: FlintSchedulesViewModel) {
        self.routine = routine
        self.viewModel = viewModel
        let schedule = routine.schedule
        _enabled = State(initialValue: routine.enabled)
        _frequency = State(initialValue: schedule?.frequency ?? "daily")
        _days = State(initialValue: Set(schedule?.days ?? []))
        _dayOfMonth = State(initialValue: schedule?.dayOfMonth ?? "1")
        // A cron-only schedule has no simple times; adding the default would add an extra run.
        let hasCron = !(schedule?.cron ?? "").isEmpty
        let existing = schedule?.times ?? (hasCron ? [] : [routine.defaultTime])
        _times = State(initialValue: existing.compactMap(Self.parse))
        _cron = State(initialValue: schedule?.cron ?? "")
    }

    var body: some View {
        Form {
            Section {
                Toggle(routine.displayName, isOn: $enabled)
            }

            Section("How often") {
                Picker("Repeat", selection: $frequency) {
                    Text("Every day").tag("daily")
                    Text("Weekdays").tag("weekdays")
                    Text("Chosen days").tag("weekly")
                    Text("Once a month").tag("monthly")
                }
                if frequency == "weekly" {
                    ForEach(Self.weekdays, id: \.0) { value, label in
                        Toggle(label, isOn: Binding(
                            get: { days.contains(value) },
                            set: { isOn in
                                if isOn { days.insert(value) } else { days.remove(value) }
                            }
                        ))
                    }
                }
                if frequency == "monthly" {
                    Picker("Day", selection: $dayOfMonth) {
                        ForEach(1...28, id: \.self) { Text("\($0)").tag(String($0)) }
                        Text("Last day").tag("last")
                        Text("First working day").tag("first_working")
                    }
                }
            }

            Section("Times") {
                ForEach(times.indices, id: \.self) { index in
                    DatePicker(
                        "Time \(index + 1)",
                        selection: Binding(get: { times[index] }, set: { times[index] = $0 }),
                        displayedComponents: .hourAndMinute
                    )
                }
                .onDelete { times.remove(atOffsets: $0) }
                Button("Add another time") {
                    times.append(Self.parse("09:00") ?? Date())
                }
            }

            Section {
                TextField("0 9 * * 1-5", text: $cron)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("Advanced: cron")
            } footer: {
                Text("Five fields: minute hour day month weekday. A cron chooses its own days.")
            }

            if let error = viewModel.errors[routine.routine] {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if viewModel.savingRoutine == routine.routine {
                        ProgressView()
                    } else {
                        Text(viewModel.savedRoutine == routine.routine ? "Saved" : "Save")
                    }
                }
                .disabled(viewModel.savingRoutine != nil)
            }
        }
        .navigationTitle(routine.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        let formatted = times.map(Self.format).sorted()
        let schedule = FlintSchedule(
            frequency: frequency,
            days: frequency == "weekly" ? Self.weekdays.map(\.0).filter(days.contains) : nil,
            dayOfMonth: frequency == "monthly" ? dayOfMonth : nil,
            times: formatted,
            cron: cron
        )
        await viewModel.save(routine: routine, enabled: enabled, schedule: schedule)
    }

    private static func parse(_ value: String) -> Date? {
        let parts = value.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

    private static func format(_ date: Date) -> String {
        let calendar = Calendar.current
        return String(format: "%02d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date))
    }
}
