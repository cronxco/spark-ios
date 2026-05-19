import SparkKit
import SparkUI
import SwiftData
import SwiftUI
import UIKit

struct SparkMainPageHeader: View {
    let title: String
    var subtitle: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(title)
                .font(SparkTypography.heroXL)
                .foregroundStyle(colorScheme == .dark ? Color.spark100 : Color.sparkTextPrimary)
                .accessibilityAddTraits(.isHeader)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SparkSystemScreenHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(title)
                .font(SparkFonts.display(.title2, weight: .bold))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SparkMainPageScaffold<Content: View>: View {
    var horizontalPadding: CGFloat
    var topPadding: CGFloat
    var bottomPadding: CGFloat
    var refresh: (() async -> Void)?
    @ViewBuilder let content: Content

    init(
        horizontalPadding: CGFloat = SparkSpacing.lg,
        topPadding: CGFloat = SparkSpacing.xl,
        bottomPadding: CGFloat = SparkSpacing.xl,
        refresh: (() async -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalPadding = horizontalPadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.refresh = refresh
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                content
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
        .scrollContentBackground(.hidden)
        .sparkAppBackground()
        .refreshable {
            await refresh?()
        }
    }
}

extension View {
    func sparkMainNavigationTitle(_ title: String) -> some View {
        navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("")
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(title)
    }
}

struct SparkSheetScaffold<Content: View>: View {
    let title: String
    var showsDismissButton = true
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss

    init(
        _ title: String,
        showsDismissButton: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsDismissButton = showsDismissButton
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(SparkSpacing.lg)
            }
            .scrollContentBackground(.hidden)
            .background(SparkResolvedAppBackground().ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                }
            }
        }
    }
}

struct SparkRawPayloadView: View {
    let text: String
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Button {
                UIPasteboard.general.string = text
                didCopy = true
                Task {
                    try? await Task.sleep(for: .seconds(1.4))
                    didCopy = false
                }
            } label: {
                Label(didCopy ? "Copied" : "Copy JSON", systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(didCopy ? Color.sparkSuccess : Color.sparkTextPrimary)
            }
            .buttonStyle(.bordered)

            Text(text)
                .font(SparkTypography.monoSmall)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SparkSpacing.md)
                .sparkGlass(.roundedRect(SparkRadii.md))
        }
    }
}

struct SparkOnboardingScaffold<Content: View, Actions: View>: View {
    let icon: String
    let title: String
    let bodyText: String?
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    init(
        icon: String,
        title: String,
        bodyText: String? = nil,
        @ViewBuilder content: () -> Content = { EmptyView() },
        @ViewBuilder actions: () -> Actions
    ) {
        self.icon = icon
        self.title = title
        self.bodyText = bodyText
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: SparkSpacing.xl) {
                    VStack(spacing: SparkSpacing.md) {
                        Image(systemName: icon)
                            .font(.system(size: 52, weight: .light))
                            .foregroundStyle(Color.sparkAccent)

                        VStack(spacing: SparkSpacing.sm) {
                            Text(title)
                                .font(SparkFonts.display(.largeTitle, weight: .bold))
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)

                            if let bodyText, !bodyText.isEmpty {
                                Text(bodyText)
                                    .font(SparkTypography.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }

                    content
                }
                .padding(.horizontal, SparkSpacing.xl)
                .padding(.top, SparkSpacing.xxl)
                .padding(.bottom, SparkSpacing.xl)
            }
            .scrollContentBackground(.hidden)

            VStack(spacing: SparkSpacing.md) {
                actions
            }
            .padding(.horizontal, SparkSpacing.xl)
            .padding(.top, SparkSpacing.md)
            .padding(.bottom, SparkSpacing.xxl)
        }
        .background(SparkResolvedAppBackground().ignoresSafeArea())
        .navigationBarBackButtonHidden()
    }
}

struct SparkShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SparkFeedbackContext: Sendable {
    let entityType: String
    let entityId: String
    let title: String

    var displayLabel: String {
        "\(entityType.capitalized): \(title)"
    }
}

struct SparkUserFeedbackSheet: View {
    let context: SparkFeedbackContext
    let profile: UserProfile?

    @Environment(\.dismiss) private var dismiss
    @State private var comments = ""
    @State private var isSending = false

    private var trimmedComments: String {
        comments.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(context.displayLabel)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }

                Section("Feedback") {
                    TextEditor(text: $comments)
                        .frame(minHeight: 160)
                        .accessibilityLabel("Feedback")
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSending)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? "Sending..." : "Send") {
                        submit()
                    }
                    .disabled(trimmedComments.isEmpty || isSending)
                }
            }
        }
    }

    private func submit() {
        let comments = trimmedComments
        guard !comments.isEmpty else { return }
        isSending = true
        SparkObservability.captureUserFeedback(
            comments: comments,
            context: context,
            profile: profile
        )
        dismiss()
    }
}

struct SparkMainAppToolbarModifier: ViewModifier {
    let isVisible: Bool

    @State private var showSettings = false
    @State private var showNotifications = false

    @Query(filter: #Predicate<CachedNotification> { !$0.isRead })
    private var unreadNotifications: [CachedNotification]
    @Query private var allIntegrations: [CachedIntegration]

    private var hasUnhealthyIntegration: Bool {
        let healthy: Set<String> = ["up_to_date", "ok", "active", "syncing", "running"]
        return allIntegrations.contains { !healthy.contains($0.status) }
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                if isVisible {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(hasUnhealthyIntegration ? Color.sparkError : Color.primary)
                        }
                        .accessibilityLabel("Settings")

                        Button {
                            showNotifications = true
                        } label: {
                            notificationIcon
                        }
                        .accessibilityLabel(
                            unreadNotifications.isEmpty
                                ? "Notifications"
                                : "Notifications, \(unreadNotifications.count) unread"
                        )
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsRootView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsInboxView()
            }
    }

    @ViewBuilder
    private var notificationIcon: some View {
        let icon = Image(systemName: "bell")
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(unreadNotifications.isEmpty ? Color.primary : Color.sparkAccent)

        if unreadNotifications.isEmpty {
            icon
        } else {
            icon.badge(unreadNotifications.count)
        }
    }
}

struct SparkSubViewToolbarModifier: ViewModifier {
    let shareItems: [Any]
    let rawTitle: String
    let rawPayload: String?
    let feedbackContext: SparkFeedbackContext?
    let refresh: () async -> Void
    let reprocess: (() async -> Void)?

    @Environment(AppModel.self) private var appModel
    @State private var showShareSheet = false
    @State private var showRawSheet = false
    @State private var showFeedbackSheet = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.primary)
                    }
                    .accessibilityLabel("Share")

                    Menu {
                        Button("Tag") {}
                            .disabled(true)
                        if feedbackContext != nil {
                            Button {
                                showFeedbackSheet = true
                            } label: {
                                Label("Send Feedback", systemImage: "bubble.left.and.bubble.right")
                            }
                        }
                        Button {
                            Task { await refresh() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        Button {
                            Task { await reprocess?() }
                        } label: {
                            Label("Reprocess", systemImage: "wand.and.sparkles")
                        }
                        .disabled(reprocess == nil)
                        Button {
                            showRawSheet = true
                        } label: {
                            Label("Raw", systemImage: "curlybraces")
                        }
                        .disabled(rawPayload == nil)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.primary)
                    }
                    .accessibilityLabel("More")
                }
            }
            .sheet(isPresented: $showShareSheet) {
                SparkShareSheet(items: shareItems)
            }
            .sheet(isPresented: $showRawSheet) {
                SparkSheetScaffold(rawTitle) {
                    SparkRawPayloadView(text: rawPayload ?? "{}")
                }
            }
            .sheet(isPresented: $showFeedbackSheet) {
                if let feedbackContext {
                    SparkUserFeedbackSheet(
                        context: feedbackContext,
                        profile: appModel.profile
                    )
                }
            }
    }
}

extension View {
    func sparkMainAppToolbar(isVisible: Bool = true) -> some View {
        modifier(SparkMainAppToolbarModifier(isVisible: isVisible))
    }

    func sparkSubViewToolbar(
        shareItems: [Any],
        rawTitle: String = "Raw",
        rawPayload: String?,
        feedbackContext: SparkFeedbackContext? = nil,
        refresh: @escaping () async -> Void,
        reprocess: (() async -> Void)? = nil
    ) -> some View {
        modifier(SparkSubViewToolbarModifier(
            shareItems: shareItems,
            rawTitle: rawTitle,
            rawPayload: rawPayload,
            feedbackContext: feedbackContext,
            refresh: refresh,
            reprocess: reprocess
        ))
    }
}

enum SparkPrettyJSON {
    static func string<T: Encodable>(for value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func fallback(entity: String, id: String, title: String? = nil) -> String {
        string(for: RawFallback(entity: entity, id: id, title: title)) ?? "{}"
    }

    private struct RawFallback: Encodable {
        let entity: String
        let id: String
        let title: String?
    }
}
