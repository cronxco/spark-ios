import SparkKit
import SparkUI
import SwiftUI

struct DevicesView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: DevicesViewModel?

    var body: some View {
        Group {
            switch viewModel?.state {
            case .loaded(let devices):
                if devices.isEmpty {
                    EmptyState(systemImage: "iphone", title: "No devices", message: "Devices appear here after sign-in.")
                } else {
                    List {
                        ForEach(devices) { device in
                            DeviceRow(device: device) {
                                Task { await viewModel?.revoke(device) }
                            }
                        }
                    }
                }
            case .error(let msg):
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load devices",
                    message: msg,
                    actionTitle: "Retry"
                ) { Task { await viewModel?.load() } }
            default:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = DevicesViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }
}

private struct DeviceRow: View {
    let device: RegisteredDevice
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            Image(systemName: platformIcon)
                .font(.system(size: 24))
                .foregroundStyle(Color.sparkAccent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: SparkSpacing.sm) {
                    Text(device.name)
                        .font(SparkTypography.body)
                    if device.isCurrentDevice {
                        TagChip("this device")
                    }
                }
                if let lastSeen = device.lastSeenAt {
                    Text(lastSeen.formatted(.relative(presentation: .named)))
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !device.isCurrentDevice {
                Button(role: .destructive, action: onRevoke) {
                    Label("Revoke", systemImage: "trash")
                }
            }
        }
    }

    private var platformIcon: String {
        switch device.platform.lowercased() {
        case "ios", "iphone": "iphone"
        case "ipad": "ipad"
        case "mac", "macos": "laptopcomputer"
        default: "rectangle.on.rectangle"
        }
    }
}
