import SwiftUI

public enum SparkTypography {
    public static let displayLarge = Font.system(.largeTitle, design: .rounded).weight(.bold)
    public static let display = Font.system(.title, design: .rounded).weight(.semibold)
    public static let titleStrong = Font.system(.title2, design: .rounded).weight(.semibold)
    public static let title = Font.system(.title3, design: .rounded)
    public static let bodyStrong = Font.system(.body).weight(.semibold)
    public static let body = Font.system(.body)
    public static let bodySmall = Font.system(.callout)
    public static let caption = Font.system(.caption)
    public static let captionStrong = Font.system(.caption).weight(.semibold)
    public static let monoBody = Font.system(.body, design: .monospaced)
}

public extension View {
    func sparkDynamicTypeClamp() -> some View {
        self.dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
