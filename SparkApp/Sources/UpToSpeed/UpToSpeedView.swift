import SparkKit
import SparkUI
import SwiftUI

/// Full-screen Instagram-style stories container for the Up to Speed flow.
/// Uses TabView page-style swiping for navigation — horizontal swipe moves between
/// screens, vertical scroll works within each screen, swipe-down from any screen
/// dismisses the whole flow. Screens are grouped into chapters shown in the
/// progress bar.
struct UpToSpeedView: View {
    @Binding var isPresented: Bool
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: UpToSpeedViewModel?
    @State private var didRequestDismiss = false
    @State private var isKeyboardVisible = false
    @State private var showsRecap = false
    @State private var noteComposerContext: FlintNoteContext?
    @State private var headerHeight: CGFloat = 0
    @State private var isCurrentStoryAtTop = true
    @State private var dismissDragStartedAtTop: Bool?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isPresented: Binding<Bool>, viewModel: UpToSpeedViewModel? = nil) {
        self._isPresented = isPresented
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            SparkResolvedAppBackground().ignoresSafeArea()

            if let vm = viewModel {
                if vm.isLoading && vm.screens.isEmpty {
                    loadingView
                } else if let error = vm.error, vm.screens.isEmpty {
                    // Without this branch a failed request rendered as "You're
                    // all caught up!" — the app reporting success for content
                    // it never received.
                    failureView(message: error, vm: vm)
                } else if vm.screens.isEmpty {
                    allCaughtUpView
                } else {
                    storiesContent(vm: vm)
                }
            } else {
                loadingView
            }
        }
        .overlay(alignment: .top) {
            // Close stays available in every state. Gating it on a populated
            // queue left loading, empty and failed states with no way out
            // except an undocumented downward drag.
            if let vm = viewModel, !vm.screens.isEmpty {
                controlsOverlay(vm: vm)
            } else {
                closeButtonOverlay
            }
        }
        .simultaneousGesture(dismissDragGesture)
        .environment(\.storyHeaderClearance, headerHeight + SparkSpacing.lg)
        .environment(\.storyShowsReadIndicator, true)
        .environment(\.storyScrollTopChanged) { isCurrentStoryAtTop = $0 }
        .sheet(isPresented: $showsRecap, onDismiss: {
            Task { await viewModel?.reconcileAfterRecap() }
        }) {
            if let vm = viewModel {
                RecapScreen(viewModel: vm)
                    .environment(\.storyHeaderClearance, SparkSpacing.lg)
                    .environment(\.storyShowsReadIndicator, false)
            }
        }
        .sheet(item: $noteComposerContext) { context in
            FlintNoteComposerView(context: context, apiClient: appModel.apiClient)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .environment(\.openURL, OpenURLAction { url in
            guard let link = DeepLink.parse(url), link.detailRoute != nil else {
                return .systemAction
            }
            switch link {
            case .event(let id): appModel.pendingRoute = .event(id: id)
            case .object(let id): appModel.pendingRoute = .object(id: id)
            case .block(let id): appModel.pendingRoute = .block(id: id)
            case .metric(let identifier): appModel.pendingRoute = .metric(identifier: identifier)
            case .place(let id): appModel.pendingRoute = .place(id: id)
            case .integration(let service): appModel.pendingRoute = .integration(service: service)
            case .tag(let name): appModel.pendingRoute = .tag(name: name, type: nil)
            case .anomaly(let id): appModel.pendingRoute = .anomaly(id: id)
            default: return .systemAction
            }
            if let viewModel {
                dismissFlow(vm: viewModel)
            } else {
                isPresented = false
                dismiss()
            }
            return .handled
        })
        .task {
            if viewModel == nil {
                viewModel = UpToSpeedViewModel(
                    apiClient: appModel.apiClient,
                    profileName: appModel.profile?.name
                )
            }
            await viewModel?.load()
            await refreshLoop()
        }
        .onDisappear {
            guard !didRequestDismiss, let viewModel else { return }
            viewModel.flush()
        }
    }

    // MARK: - Stories content

    @ViewBuilder
    private func storiesContent(vm: UpToSpeedViewModel) -> some View {
        @Bindable var vm = vm

        TabView(selection: $vm.currentIndex) {
            ForEach(Array(vm.screens.enumerated()), id: \.element.id) { index, screen in
                screenRenderer(screen, index: index, isActive: index == vm.currentIndex && !showsRecap, vm: vm)
                    .id("\(screen.id)-\(vm.restorationVersion(for: screen.item?.id))")
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .accessibilityAction(named: "Next card") {
            guard vm.currentIndex + 1 < vm.screens.count else { return }
            vm.jump(to: vm.currentIndex + 1)
        }
        .accessibilityAction(named: "Previous card") {
            guard vm.currentIndex > 0 else { return }
            vm.jump(to: vm.currentIndex - 1)
        }
        .onChange(of: vm.currentIndex) { old, new in
            if new > old {
                vm.markRead(at: old)
            }
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }

    private func supplement(for screen: UpToSpeedScreen, vm: UpToSpeedViewModel) -> AnyView? {
        let items = vm.supplementalItems(for: screen)
        guard !items.isEmpty else { return nil }
        return AnyView(VStack(alignment: .leading, spacing: SparkSpacing.md) {
            ForEach(items) { item in DigestSupplementView(item: item, viewModel: vm) }
        })
    }

    // MARK: - Controls overlay

    private func controlsOverlay(vm: UpToSpeedViewModel) -> some View {
        VStack(spacing: SparkSpacing.sm) {
            StoryProgressBar(chapters: progressChapters(vm: vm), currentIndex: vm.currentIndex)
            HStack(alignment: .center, spacing: SparkSpacing.sm) {
                HStack(spacing: SparkSpacing.sm) {
                    if let chapter = vm.currentChapter {
                        Circle().fill(chapter.accent).frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                        Text(chapter.shortLabel)
                            .font(SparkTypography.bodyStrong)
                            .foregroundStyle(.primary)
                    }
                    Text(vm.chapterCounter)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                Button {
                    noteComposerContext = currentScreen(in: vm)?.flintNoteContext ?? .generic
                } label: {
                    Image(systemName: "square.and.pencil")
                        .frame(width: 44, height: 44)
                        .sparkGlass(.circle)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .accessibilityLabel("Note to Flint")
                Button { showsRecap = true } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .frame(width: 44, height: 44)
                        .sparkGlass(.circle)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .accessibilityLabel("Recap")
                closeButton { dismissFlow(vm: vm) }
            }

            if vm.newItemsAvailable > 0 {
                Button {
                    Task { await vm.reloadQueue() }
                } label: {
                    Label("\(vm.newItemsAvailable) new", systemImage: "arrow.up")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, SparkSpacing.lg)
                        .padding(.vertical, SparkSpacing.sm)
                        .sparkGlass(.capsule)
                }
                .buttonStyle(.plain)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.top, topSafeArea + SparkSpacing.sm)
        .padding(.bottom, SparkSpacing.md)
        .glassEffect(.regular, in: Rectangle())
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
    }

    private func currentScreen(in viewModel: UpToSpeedViewModel) -> UpToSpeedScreen? {
        guard viewModel.screens.indices.contains(viewModel.currentIndex) else { return nil }
        return viewModel.screens[viewModel.currentIndex]
    }

    private func progressChapters(vm: UpToSpeedViewModel) -> [StoryProgressBar.ChapterSpec] {
        vm.chapters.map { .init(label: $0.shortLabel, segments: max($0.cardCount, 1), accent: $0.accent) }
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                // Latch the scroll position at touch-down. A drag that starts
                // lower in the page must not become a dismiss gesture merely
                // because that same drag scrolls the page back to the top.
                if dismissDragStartedAtTop == nil {
                    dismissDragStartedAtTop = isCurrentStoryAtTop
                }
            }
            .onEnded { value in
                defer { dismissDragStartedAtTop = nil }
                guard let vm = viewModel else { return }
                guard dismissDragStartedAtTop == true else { return }
                let vertical = value.translation.height
                let horizontal = abs(value.translation.width)
                guard vertical > 120, vertical > horizontal * 1.35 else { return }
                if isKeyboardVisible {
                    dismissKeyboard()
                    return
                }
                dismissFlow(vm: vm)
            }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    private func dismissFlow(vm: UpToSpeedViewModel) {
        guard !didRequestDismiss else { return }
        didRequestDismiss = true
        vm.flush()
        isPresented = false
        dismiss()
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, let viewModel else { return }
            await viewModel.refreshFeed()
        }
    }

    // MARK: - Screen registry

    @ViewBuilder
    private func screenRenderer(
        _ screen: UpToSpeedScreen,
        index: Int,
        isActive: Bool,
        vm: UpToSpeedViewModel
    ) -> some View {
        // `isActive` matters because TabView(.page) builds the next page before
        // the swipe lands. Without it an off-screen card reaches the end of its
        // content and would be marked read before the reader ever sees it.
        let consumed: () -> Void = { vm.markScreenConsumed(at: index) }
        let supplement = supplement(for: screen, vm: vm)

        switch screen {
        case .opener:
            FlintOpenerScreen(viewModel: vm, onShowRecap: { showsRecap = true })
        case .flintHeader(let item, let firstSection):
            FlintHeaderPage(item: item, firstSection: firstSection, isActive: isActive, onReachedBottom: consumed, supplement: supplement)
        case .flintParagraph(let item, let text, _):
            FlintParagraphPage(item: item, text: text, isActive: isActive, onReachedBottom: consumed, supplement: supplement)
        case .flintInsight(_, let block):
            FlintInsightPage(block: block, isActive: isActive, onReachedBottom: consumed, supplement: supplement)
        case .flintQuestion(let item, let block):
            FlintQuestionPage(item: item, block: block, viewModel: vm, isActive: isActive, onReachedBottom: consumed, supplement: supplement)
        case .checkIn(let item):
            CheckInScreen(item: item, viewModel: vm)
        case .anomaly(let item):
            AnomalyScreen(item: item, viewModel: vm, isActive: isActive)
        case .newsStory(let item, let section, let sectionIndex, let total):
            NewsStoryScreen(
                item: item,
                section: section,
                index: sectionIndex,
                total: total,
                viewModel: vm,
                isActive: isActive,
                onReachedBottom: consumed
            )
        case .newsSummary(let item):
            NewsSummaryScreen(item: item, isActive: isActive, onReachedBottom: consumed, viewModel: vm)
        case .wrap:
            WrapScreen(
                viewModel: vm,
                onDone: { dismissFlow(vm: vm) },
                isActive: isActive,
                onShowRecap: { showsRecap = true }
            )
        case .recap:
            RecapScreen(viewModel: vm, isActive: isActive)
        }
    }

    // MARK: - Loading / empty

    private var loadingView: some View {
        VStack(spacing: SparkSpacing.md) {
            ProgressView()
                .tint(Color.sparkAccent)
            Text("Getting you up to speed…")
                .font(SparkTypography.body)
                .foregroundStyle(.secondary)
        }
    }

    private func failureView(message: String, vm: UpToSpeedViewModel) -> some View {
        VStack(spacing: SparkSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(Color.sparkWarning)

            Text("Couldn't get your catch-up")
                .font(SparkTypography.heroSmall)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            PillButton("Try again") {
                Task { await vm.load() }
            }
        }
        .padding(SparkSpacing.xxl)
        .frame(maxWidth: .infinity)
    }

    private func closeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .sparkGlass(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .highPriorityGesture(TapGesture().onEnded(action))
    }

    /// The close control on its own, for the states that have no progress bar
    /// to hang it from.
    private var closeButtonOverlay: some View {
        HStack {
            Spacer()
            closeButton {
                if let viewModel {
                    dismissFlow(vm: viewModel)
                } else {
                    isPresented = false
                    dismiss()
                }
            }
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.top, topSafeArea + SparkSpacing.sm)
    }

    private var allCaughtUpView: some View {
        VStack(spacing: SparkSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.sparkSuccess)

            Text("You're all caught up!")
                .font(SparkTypography.heroSmall)
                .foregroundStyle(.primary)

            Text("Nothing new to review right now.")
                .font(SparkTypography.body)
                .foregroundStyle(.secondary)

            PillButton("Done") { isPresented = false }
        }
        .padding(SparkSpacing.xxl)
    }

    private var topSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first?
            .keyWindow?.safeAreaInsets.top ?? 44
    }
}
