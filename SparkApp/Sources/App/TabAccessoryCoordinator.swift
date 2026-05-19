import Observation
import SparkUI
import SwiftUI

@MainActor
@Observable
final class TabAccessoryCoordinator {
    var accessory: TabAccessory?

    func set(_ accessory: TabAccessory) {
        self.accessory = accessory
    }

    func clear(owner: AppTab) {
        guard accessory?.owner == owner else { return }
        accessory = nil
    }
}

struct TabAccessory {
    let owner: AppTab
    let title: String
    let items: [TabAccessoryItem]
    let selectedID: String
    let select: @MainActor (String) -> Void
}

struct TabAccessoryItem: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String?

    init(id: String, title: String, systemImage: String? = nil) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

private struct TabAccessoryCoordinatorKey: EnvironmentKey {
    static let defaultValue: TabAccessoryCoordinator? = nil
}

extension EnvironmentValues {
    var tabAccessoryCoordinator: TabAccessoryCoordinator? {
        get { self[TabAccessoryCoordinatorKey.self] }
        set { self[TabAccessoryCoordinatorKey.self] = newValue }
    }
}

struct TabAccessoryView: View {
    let accessory: TabAccessory

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        switch placement {
        case .inline:
            inlinePicker
        case .expanded, .none:
            expandedPicker
        @unknown default:
            expandedPicker
        }
    }

    private var selection: Binding<String> {
        Binding(
            get: { accessory.selectedID },
            set: { accessory.select($0) }
        )
    }

    private var expandedPicker: some View {
        Picker(accessory.title, selection: selection) {
            ForEach(accessory.items) { item in
                if let systemImage = item.systemImage {
                    Label(item.title, systemImage: systemImage).tag(item.id)
                } else {
                    Text(item.title).tag(item.id)
                }
            }
        }
        .pickerStyle(.segmented)
        .padding(SparkSpacing.sm)
    }

    @ViewBuilder
    private var inlinePicker: some View {
        if accessory.items.count <= 3 {
            inlineSegmentedPicker
        } else {
            inlineMenuPicker
        }
    }

    private var inlineSegmentedPicker: some View {
        Picker(accessory.title, selection: selection) {
            ForEach(accessory.items) { item in
                Text(item.title).tag(item.id)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.regular)
        .frame(width: inlineSegmentedWidth)
        .fixedSize(horizontal: true, vertical: true)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .accessibilityLabel(accessory.title)
    }

    private var inlineMenuPicker: some View {
        Menu {
            Picker(accessory.title, selection: selection) {
                ForEach(accessory.items) { item in
                    if let systemImage = item.systemImage {
                        Label(item.title, systemImage: systemImage).tag(item.id)
                    } else {
                        Text(item.title).tag(item.id)
                    }
                }
            }
        } label: {
            Label(selectedTitle, systemImage: "chevron.up.chevron.down")
                .font(SparkTypography.captionStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityLabel(accessory.title)
        .accessibilityValue(selectedTitle)
    }

    private var selectedTitle: String {
        accessory.items.first { $0.id == accessory.selectedID }?.title ?? accessory.title
    }

    private var inlineSegmentedWidth: CGFloat {
        CGFloat(accessory.items.count) * 96
    }
}
