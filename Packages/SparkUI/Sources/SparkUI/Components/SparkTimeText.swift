import SwiftUI

/// A time that reads relative first ("1 hour ago") and shows the exact
/// 24-hour time ("09:14", or "Tue 14:05" on another day) when tapped. A
/// second tap goes back. The relative form refreshes each minute.
///
/// It is its own button, so it can sit inside a row that opens something
/// else: a tap on the time toggles it, a tap anywhere else opens the row.
public struct SparkTimeText: View {
    let date: Date
    let font: Font

    @State private var showsExact = false

    public init(_ date: Date, font: Font = SparkTypography.caption) {
        self.date = date
        self.font = font
    }

    public var body: some View {
        TimelineView(.everyMinute) { context in
            let relative = Self.relative.localizedString(for: date, relativeTo: context.date)
            let exact = Self.exact(date, now: context.date)
            Button {
                showsExact.toggle()
            } label: {
                Text(showsExact ? exact : relative)
                    .font(font)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showsExact ? exact : relative)
            .accessibilityHint(showsExact ? "Shows how long ago" : "Shows the exact time, \(exact)")
        }
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dayAndTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEE HH:mm"
        return f
    }()

    private static func exact(_ date: Date, now: Date) -> String {
        Calendar.current.isDate(date, inSameDayAs: now)
            ? time.string(from: date)
            : dayAndTime.string(from: date)
    }
}
