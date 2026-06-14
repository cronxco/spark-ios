import SparkKit
import SparkUI
import SwiftUI

/// Full-screen Instagram-style stories container for the Up to Speed flow.
/// Uses TabView page-style swiping for navigation — horizontal swipe moves between
/// screens, vertical scroll works within each screen, swipe-down from any screen
/// dismisses the whole flow.
struct UpToSpeedView: View {
    @Binding var isPresented: Bool
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: UpToSpeedViewModel?
    @State private var didRequestDismiss = false
    @State private var isKeyboardVisible = false

    init(isPresented: Binding<Bool>, viewModel: UpToSpeedViewModel? = nil) {
        self._isPresented = isPresented
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SparkResolvedAppBackground().ignoresSafeArea()

                if let vm = viewModel {
                    if vm.isLoading && vm.screens.isEmpty {
                        loadingView
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
                if let vm = viewModel, !vm.screens.isEmpty {
                    controlsOverlay(vm: vm, safeAreaTop: proxy.safeAreaInsets.top)
                }
            }
            .simultaneousGesture(dismissDragGesture)
            .ignoresSafeArea()
        }
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
                viewModel = UpToSpeedViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
            await refreshLoop()
        }
        .onChange(of: appModel.timezoneRefreshRevision) {
            Task { await viewModel?.reloadQueue() }
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
            ForEach(Array(vm.screens.enumerated()), id: \.offset) { index, screen in
                screenRenderer(screen, index: index, vm: vm)
                    .tag(index)
            }
            caughtUpStoryScreen(vm: vm)
                .tag(vm.screens.count)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
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

    @ViewBuilder
    private func caughtUpStoryScreen(vm: UpToSpeedViewModel) -> some View {
        VStack(spacing: SparkSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.sparkSuccess)

            Text("You're all caught up!")
                .font(SparkTypography.heroSmall)
                .foregroundStyle(.primary)

            Text("Nothing more to review right now.")
                .font(SparkTypography.body)
                .foregroundStyle(.secondary)

            PillButton("Done") { dismissFlow(vm: vm) }
                .padding(.top, SparkSpacing.sm)
            Spacer()
        }
        .padding(SparkSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Controls overlay

    private func controlsOverlay(vm: UpToSpeedViewModel, safeAreaTop: CGFloat) -> some View {
        VStack(spacing: SparkSpacing.sm) {
            HStack(alignment: .center, spacing: SparkSpacing.sm) {
                StoryProgressBar(total: vm.screens.count + 1, currentIndex: vm.currentIndex)
                    .padding(.horizontal, SparkSpacing.md)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .sparkGlass(.capsule)

                Button {
                    dismissFlow(vm: vm)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .sparkGlass(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .highPriorityGesture(
                    TapGesture().onEnded {
                        dismissFlow(vm: vm)
                    }
                )
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, safeAreaTop + SparkSpacing.sm)

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
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 36)
            .onEnded { value in
                guard let vm = viewModel else { return }
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
    private func screenRenderer(_ screen: UpToSpeedScreen, index: Int, vm: UpToSpeedViewModel) -> some View {
        switch screen {
        case .flintHeader(let item, let firstSection):
            FlintHeaderPage(item: item, firstSection: firstSection)
        case .flintParagraph(let item, let text, _):
            FlintParagraphPage(item: item, text: text)
        case .flintInsight(_, let block):
            FlintInsightPage(block: block)
        case .flintQuestion(let item, let block):
            FlintQuestionPage(item: item, block: block, viewModel: vm)
        case .checkIn(let item):
            CheckInScreen(item: item, viewModel: vm)
        case .anomaly(let item):
            AnomalyScreen(item: item, viewModel: vm)
        case .newsSummary(let item):
            NewsSummaryScreen(item: item, viewModel: vm, onReachedBottom: { vm.markScrolledToBottom(at: index) })
        }
    }

    // MARK: - Loading / empty

    private var loadingView: some View {
        VStack(spacing: SparkSpacing.md) {
            ProgressView()
                .tint(.primary)
            Text("Getting you up to speed…")
                .font(SparkTypography.body)
                .foregroundStyle(.secondary)
        }
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
}
