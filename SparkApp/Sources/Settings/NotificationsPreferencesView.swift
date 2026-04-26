import SparkKit
import SparkUI
import SwiftUI

struct NotificationsPreferencesView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: NotificationsPreferencesViewModel?

    var body: some View {
        Group {
            switch viewModel?.state {
            case .loaded(let prefs):
                prefsForm(prefs)
            case .error(let msg):
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load preferences",
                    message: msg,
                    actionTitle: "Retry"
                ) { Task { await viewModel?.load() } }
            default:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = NotificationsPreferencesViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    private func prefsForm(_ prefs: NotificationPreferences) -> some View {
        @Bindable var vm = viewModel!
        return Form {
            Section("Categories") {
                ForEach(NotificationPreferences.Category.allCases, id: \.self) { category in
                    categoryRow(category, prefs: prefs)
                }
            }

            Section("Delivery") {
                Picker("Mode", selection: deliveryModeBinding(prefs)) {
                    ForEach(NotificationPreferences.DeliveryMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if case .loaded(let current) = vm.state, current.deliveryMode == .dailyDigest {
                    digestTimePicker(current)
                }
            }

            if vm.saveStatus != .idle {
                Section {
                    saveStatusRow(vm.saveStatus)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if case .saved = vm.saveStatus {
                StatusPill(.ok, message: "Saved")
                    .padding(.horizontal, SparkSpacing.lg)
                    .padding(.bottom, SparkSpacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: vm.saveStatus == .saved)
    }

    private func categoryRow(_ category: NotificationPreferences.Category, prefs: NotificationPreferences) -> some View {
        let isOn = Binding(
            get: { prefs.categories[category] ?? true },
            set: { newValue in
                guard case .loaded(var current) = viewModel?.state else { return }
                current.categories[category] = newValue
                viewModel?.updateLocal(current)
            }
        )
        return Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(SparkTypography.body)
                Text(category.subtitle)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deliveryModeBinding(_ prefs: NotificationPreferences) -> Binding<NotificationPreferences.DeliveryMode> {
        Binding(
            get: { prefs.deliveryMode },
            set: { newMode in
                guard case .loaded(var current) = viewModel?.state else { return }
                current.deliveryMode = newMode
                viewModel?.updateLocal(current)
            }
        )
    }

    private func digestTimePicker(_ prefs: NotificationPreferences) -> some View {
        let timeBinding = Binding<Date>(
            get: {
                guard let str = prefs.digestTime else { return defaultDigestTime() }
                return parseHHmm(str) ?? defaultDigestTime()
            },
            set: { date in
                guard case .loaded(var current) = viewModel?.state else { return }
                let cal = Calendar.current
                let h = cal.component(.hour, from: date)
                let m = cal.component(.minute, from: date)
                current.digestTime = String(format: "%02d:%02d", h, m)
                viewModel?.updateLocal(current)
            }
        )
        return DatePicker("Digest time", selection: timeBinding, displayedComponents: .hourAndMinute)
    }

    @ViewBuilder
    private func saveStatusRow(_ status: NotificationsPreferencesViewModel.SaveStatus) -> some View {
        switch status {
        case .saving:
            HStack {
                ProgressView().controlSize(.small)
                Text("Saving…").font(SparkTypography.bodySmall).foregroundStyle(.secondary)
            }
        case .error(let msg):
            Text(msg).font(SparkTypography.bodySmall).foregroundStyle(Color.sparkError)
        default:
            EmptyView()
        }
    }

    private func defaultDigestTime() -> Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    }

    private func parseHHmm(_ s: String) -> Date? {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: .now)
    }
}
