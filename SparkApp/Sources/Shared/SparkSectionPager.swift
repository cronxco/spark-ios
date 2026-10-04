import SparkUI
import SwiftUI

/// One page of a `SparkSectionPager`.
struct SparkPagerSection<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
}

/// A main tab split into sections: the tab's title with a section picker
/// under it, and the sections side by side so you can swipe between them.
///
/// The pages sit in a horizontal paging `ScrollView`, not a page-style
/// `TabView`. A nested page `TabView` lays its pages out inside the safe
/// area, so each page's scroll view stopped at the tab bar and the floating
/// bar sat on a plain band; it also hid the scroll view from the bars, so
/// the tab bar never minimised. A scroll view keeps every page running under
/// the bars like the tabs with no sections.
struct SparkSectionPager<ID: Hashable, Page: View>: View {
    let title: String
    let sections: [SparkPagerSection<ID>]
    @Binding var selection: ID
    /// Sections whose content needs the horizontal drag for itself, such as
    /// a map. Swiping is off while one is showing; the picker still works.
    var swipeDisabled: Set<ID> = []
    @ViewBuilder let page: (ID) -> Page

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var scrolledID: ID?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(sections) { section in
                    page(section.id)
                        .containerRelativeFrame(.horizontal)
                        .id(section.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrolledID)
        .scrollDisabled(swipeDisabled.contains(selection))
        .sparkAppBackground()
        .safeAreaBar(edge: .top) { header }
        .onAppear { scrolledID = selection }
        .onChange(of: scrolledID) { _, new in
            if let new, new != selection { selection = new }
        }
        .onChange(of: selection) { _, new in
            guard scrolledID != new else { return }
            withAnimation(.snappy) { scrolledID = new }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SparkMainPageHeader(title: title)
            picker
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.bottom, SparkSpacing.sm)
    }

    @ViewBuilder
    private var picker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Menu {
                Picker("\(title) section", selection: $selection) {
                    ForEach(sections) { Text($0.title).tag($0.id) }
                }
            } label: {
                Label(selectedTitle, systemImage: "chevron.up.chevron.down")
                    .font(SparkTypography.bodyStrong)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("\(title) section")
            .accessibilityValue(selectedTitle)
        } else {
            Picker("\(title) section", selection: $selection) {
                ForEach(sections) { Text($0.title).tag($0.id) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var selectedTitle: String {
        sections.first { $0.id == selection }?.title ?? title
    }
}

/// The line under a section's content that used to sit under its own page
/// title ("Last synced …", "12 items"), now that the title belongs to the tab.
struct SparkSectionCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(SparkTypography.bodySmall)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
