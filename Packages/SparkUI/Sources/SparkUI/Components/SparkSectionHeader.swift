import SwiftUI

/// Comfortaa 22pt section heading with an optional leading icon. Use in
/// Explore screens to open named content groups.
public struct SparkSectionHeader: View {
    public let title: String
    public let icon: String?
    public let tint: Color

    public init(title: String, icon: String? = nil, tint: Color = .primary) {
        self.title = title
        self.icon = icon
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(SparkFonts.display(.title2))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
