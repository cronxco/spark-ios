import SparkKit
import SparkUI
import SwiftUI

/// The map's timeline: a glass control with a day stepper over a 24-hour
/// track. Each stop is a tick in its domain tint. Dragging or tapping the
/// track snaps to the nearest stop; ticks after the selected stop fade.
/// Hour markers use 24-hour time.
struct TimelineScrubber: View {
    @Bindable var viewModel: MapViewModel

    @State private var choosingDay = false
    @ScaledMetric(relativeTo: .caption) private var trackHeight: CGFloat = 50

    var body: some View {
        VStack(spacing: 0) {
            dayStepper
            track
                .frame(height: trackHeight)
                .padding(.horizontal, SparkSpacing.lg)
        }
        .padding(.top, SparkSpacing.xs)
        .padding(.bottom, SparkSpacing.sm)
        .sparkGlass(.roundedRect(SparkRadii.lg))
        .sensoryFeedback(.selection, trigger: viewModel.selectedStopID)
        .sheet(isPresented: $choosingDay) {
            dayPicker
        }
    }

    // MARK: - Day

    private var dayStepper: some View {
        HStack(spacing: 0) {
            Button {
                viewModel.showDay(offset: -1)
            } label: {
                SparkGlyph(.previous, size: 15)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous day")

            Spacer(minLength: 0)

            Button {
                choosingDay = true
            } label: {
                HStack(spacing: SparkSpacing.sm) {
                    SparkGlyph(.calendarEvent, size: 14)
                        .foregroundStyle(.secondary)
                    Text(dayLabel)
                        .font(SparkTypography.bodyStrong)
                }
                .frame(minHeight: 44)
                .padding(.horizontal, SparkSpacing.md)
                .contentShape(.rect)
            }
            .accessibilityLabel("Choose day")
            .accessibilityValue(dayLabel)

            Spacer(minLength: 0)

            Button {
                viewModel.showDay(offset: 1)
            } label: {
                SparkGlyph(.forward, size: 15)
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.isToday)
            .accessibilityLabel("Next day")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SparkSpacing.xs)
    }

    private var dayPicker: some View {
        NavigationStack {
            DatePicker(
                "Day",
                selection: Binding(
                    get: { viewModel.day },
                    set: { viewModel.showDay($0); choosingDay = false }
                ),
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal, SparkSpacing.lg)
            .navigationTitle("Choose a day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Today") {
                        viewModel.showDay(.now)
                        choosingDay = false
                    }
                    .disabled(viewModel.isToday)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var dayLabel: String {
        if viewModel.isToday { return "Today" }
        if Calendar.current.isDateInYesterday(viewModel.day) { return "Yesterday" }
        return Self.dayFormatter.string(from: viewModel.day)
    }

    // MARK: - Track

    private var track: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let selectedTime = viewModel.timelineTime
            let handleX = x(for: selectedTime, width: width)

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: width, height: 2)
                    .offset(y: 16)
                Capsule()
                    .fill(Color.domainOnline)
                    .frame(width: max(0, handleX), height: 2)
                    .offset(y: 16)

                ForEach(viewModel.stops) { stop in
                    let time = stop.stopTime ?? viewModel.day
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(stop.mapTint)
                        .frame(width: 8, height: 8)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.sparkElevated)
                                .padding(-1.5)
                        )
                        .opacity(time <= selectedTime ? 1 : 0.4)
                        .offset(x: x(for: time, width: width) - 4, y: 13)
                }

                Circle()
                    .fill(Color.sparkElevated)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
                    .frame(width: 22, height: 22)
                    .offset(x: handleX - 11, y: 6)
                    .animation(.snappy, value: handleX)

                ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                    Text(String(format: "%02d", hour))
                        .font(SparkTypography.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .frame(width: 24)
                        .offset(x: width * CGFloat(hour) / 24 - 12, y: 32)
                }
            }
            .frame(width: width, alignment: .topLeading)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        snap(toX: value.location.x, width: width)
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Stops")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(viewModel.stops.isEmpty ? "" : "Swipe up or down to move between stops")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: viewModel.selectStop(offset: 1)
            case .decrement: viewModel.selectStop(offset: -1)
            @unknown default: break
            }
        }
    }

    private var accessibilityValue: String {
        guard !viewModel.stops.isEmpty else { return "No stops" }
        guard let stop = viewModel.selectedStop, let index = viewModel.selectedIndex else {
            return "\(viewModel.stops.count) stops"
        }
        let time = stop.stopTime.map { Self.timeFormatter.string(from: $0) } ?? ""
        return "\(stop.title), \(time), stop \(index + 1) of \(viewModel.stops.count)"
    }

    private func snap(toX locationX: CGFloat, width: CGFloat) {
        guard width > 0, !viewModel.stops.isEmpty else { return }
        let fraction = min(max(locationX / width, 0), 1)
        let time = viewModel.day.addingTimeInterval(dayLength * fraction)
        viewModel.selectStop(nearest: time)
    }

    private var dayLength: TimeInterval {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.day) ?? viewModel.day
        return max(next.timeIntervalSince(viewModel.day), 1)
    }

    private func x(for time: Date, width: CGFloat) -> CGFloat {
        let fraction = min(max(time.timeIntervalSince(viewModel.day) / dayLength, 0), 1)
        return width * fraction
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return f
    }()
}
