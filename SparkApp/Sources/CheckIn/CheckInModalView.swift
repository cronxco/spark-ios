import CoreLocation
import SparkKit
import SparkUI
import SwiftUI

struct CheckInModalView: View {
    let viewModel: TodayViewModel
    let date: Date
    let initialPeriod: CheckInPeriod
    let allowsPeriodSelection: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var period: CheckInPeriod
    @State private var physical: Int? = nil
    @State private var mental: Int? = nil
    @State private var notes: String = ""
    @State private var locationState: LocationState = .idle
    @State private var isSubmitting = false
    @State private var submitError: String? = nil

    init(
        viewModel: TodayViewModel,
        date: Date,
        initialPeriod: CheckInPeriod,
        allowsPeriodSelection: Bool = false
    ) {
        self.viewModel = viewModel
        self.date = date
        self.initialPeriod = initialPeriod
        self.allowsPeriodSelection = allowsPeriodSelection
        _period = State(initialValue: initialPeriod)
    }

    private var otherPeriodAlsoPending: Bool {
        guard allowsPeriodSelection else { return false }
        switch initialPeriod {
        case .morning:
            if case .pending = viewModel.checkInDayStatus.afternoon { return true }
        case .afternoon:
            if case .pending = viewModel.checkInDayStatus.morning { return true }
        }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                    if otherPeriodAlsoPending {
                        periodPicker
                    }
                    physicalSection
                    mentalSection
                    notesSection
                    locationSection
                    if let err = submitError {
                        Text(err)
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(Color.sparkError)
                    }
                    logButton
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.vertical, SparkSpacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(SparkResolvedAppBackground().ignoresSafeArea())
            .navigationTitle("\(period.rawValue.capitalized) check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
        }
    }

    // MARK: - Sections

    private var periodPicker: some View {
        HStack(spacing: SparkSpacing.sm) {
            ForEach(CheckInPeriod.allCases, id: \.self) { p in
                Button {
                    period = p
                } label: {
                    Text(p.rawValue.capitalized)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(period == p ? Color.sparkAccent : .primary)
                        .padding(.horizontal, SparkSpacing.md)
                        .padding(.vertical, SparkSpacing.sm)
                        .background(
                            period == p
                                ? Color.sparkAccent.opacity(0.15)
                                : Color.primary.opacity(0.06)
                        )
                        .clipShape(.capsule)
                        .overlay {
                            if period == p {
                                Capsule().strokeBorder(Color.sparkAccent.opacity(0.5), lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(p.rawValue.capitalized)\(period == p ? ", selected" : "")")
                .accessibilityAddTraits(period == p ? .isSelected : [])
            }
        }
    }

    private var physicalSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionLabel("HOW'S YOUR BODY?")
            EmojiRatingRow(
                selected: $physical,
                emojis: CheckInPresentation.physicalEmojis,
                labels: CheckInPresentation.physicalLabels
            )
        }
    }

    private var mentalSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionLabel("HOW'S YOUR MIND?")
            EmojiRatingRow(
                selected: $mental,
                emojis: CheckInPresentation.mentalEmojis,
                labels: CheckInPresentation.mentalLabels
            )
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack {
                SectionLabel("NOTE")
                Spacer()
                Text("\(notes.count) / 1000")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: Binding(
                get: { notes },
                set: { notes = String($0.prefix(1000)) }
            ))
            .font(SparkTypography.body)
            .frame(minHeight: 80, maxHeight: 160)
            .scrollContentBackground(.hidden)
            .padding(SparkSpacing.md)
            .sparkGlass(.roundedRect(SparkRadii.md))
        }
    }

    private var logButton: some View {
        Button {
            Task { await logCheckIn() }
        } label: {
            HStack(spacing: SparkSpacing.sm) {
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
                Text("Log it")
                    .font(SparkTypography.body)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SparkSpacing.md)
            .background(physical != nil && mental != nil ? Color.sparkAccent : Color.secondary.opacity(0.25))
            .foregroundStyle(physical != nil && mental != nil ? Color.white : Color.secondary)
            .clipShape(.rect(cornerRadius: SparkRadii.md))
        }
        .disabled(physical == nil || mental == nil || isSubmitting)
        .animation(.easeInOut(duration: 0.15), value: physical == nil || mental == nil)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionLabel("LOCATION")
            LocationChip(state: locationState) {
                Task { await fetchLocation() }
            } onClear: {
                locationState = .idle
            }
        }
    }

    // MARK: - Actions

    private func logCheckIn() async {
        guard let phy = physical, let men = mental else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let dateKey = Self.isoDate(date)
        let (lat, lng, addr): (Double?, Double?, String?) = {
            if case let .resolved(address, lat, lng) = locationState {
                return (lat, lng, address)
            }
            return (nil, nil, nil)
        }()

        let request = CheckInRequest(
            period: period,
            physical: phy,
            mental: men,
            date: dateKey,
            occurredAt: CheckInPresentation.occurredAtOverride(for: date, period: period),
            latitude: lat,
            longitude: lng,
            address: addr,
            notes: notes.isEmpty ? nil : notes
        )

        do {
            try await viewModel.submitCheckIn(request: request)
            dismiss()
        } catch {
            submitError = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }

    private func fetchLocation() async {
        locationState = .fetching
        locationState = await fetchLocationState(current: locationState)
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

