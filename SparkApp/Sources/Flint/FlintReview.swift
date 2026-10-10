import Observation
import SparkKit
import SparkUI
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Flint's Review queue: decisions Spark made by itself, and suggestions it
/// was not sure enough to act on (decisions E-1 and EX-D4).
@MainActor
@Observable
final class FlintReviewModel {
    enum State: Equatable {
        case idle, loading, loaded
        case error(String)
    }

    private(set) var items: [FlintReviewItem] = []
    private(set) var state: State = .idle
    var actionError: String?
    /// True while a finger is down on a row, so the section pager leaves the
    /// sideways drag to the row's swipe actions.
    var isTouchingRow = false
    /// Items swiped away whose action is still in flight.
    private var pendingKeys: Set<String> = []
    /// Items acted on this session, so a slower response that predates the
    /// action can't bring one back.
    private var settledKeys: Set<String> = []

    let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await load()
    }

    func load() async {
        state = .loading
        do {
            apply(try await apiClient.request(FlintEndpoint.review()).data)
            state = .loaded
        } catch where error.isAPICancellation {
            state = items.isEmpty ? .idle : .loaded
        } catch APIError.notModified {
            // Nothing new since the last load; keep what's showing.
            state = .loaded
        } catch {
            SparkObservability.captureHandled(error)
            state = .error((error as? LocalizedError)?.errorDescription ?? "Couldn’t load the review queue.")
        }
    }

    func canPerform(_ action: FlintReviewAction, on item: FlintReviewItem) -> Bool {
        guard !pendingKeys.contains(item.reviewKey) else { return false }
        return action == item.acceptAction || action == item.rejectAction
    }

    /// A swiped decision held back for a few seconds so it can be undone.
    /// The server has no reverse for these actions, so nothing is sent
    /// until the window closes.
    struct StagedDecision: Equatable, Sendable {
        let id = UUID()
        let item: FlintReviewItem
        let action: FlintReviewAction
        let index: Int

        var isAccept: Bool { action == item.acceptAction }

        var message: String {
            let verb = switch action {
            case .confirm: "Linked"
            case .keep: "Kept"
            case .dismiss: "Dismissed"
            case .undo: "Unlinked"
            }
            let title = item.subject.title.flatMap { $0.isEmpty ? nil : $0 } ?? "item"
            return "\(verb) \(title)"
        }
    }

    static let undoWindow: Duration = .seconds(5)

    private(set) var staged: StagedDecision?
    private var commitTask: Task<Void, Never>?

    /// Removes the item straight away, so a swipe feels instant, and sends
    /// the action once the undo window closes. A second swipe sends the
    /// first one at once.
    func stage(_ action: FlintReviewAction, on item: FlintReviewItem) {
        guard canPerform(action, on: item),
              let index = items.firstIndex(where: { $0.reviewKey == item.reviewKey }) else { return }
        commitStaged()
        pendingKeys.insert(item.reviewKey)
        items.remove(at: index)
        staged = StagedDecision(item: item, action: action, index: index)
        commitTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoWindow)
            guard !Task.isCancelled else { return }
            self?.commitStaged()
        }
    }

    func undoStaged() {
        guard let decision = staged else { return }
        commitTask?.cancel()
        commitTask = nil
        staged = nil
        pendingKeys.remove(decision.item.reviewKey)
        restore(decision.item, at: decision.index)
    }

    /// Sends the held decision now, e.g. when the tab goes off screen.
    func commitStaged() {
        guard let decision = staged else { return }
        commitTask?.cancel()
        commitTask = nil
        staged = nil
        Task { await send(decision) }
    }

    /// Puts the item back if the server refuses.
    private func send(_ decision: StagedDecision) async {
        let item = decision.item
        let key = item.reviewKey
        let request = FlintReviewActionRequest(
            action: decision.action,
            transactionID: decision.action == .confirm && item.kind == .receiptSuggestion ? item.bestCandidate?.id : nil
        )
        do {
            let fresh = try await apiClient.request(FlintEndpoint.reviewAction(kind: item.kind, id: item.id, request)).data
            pendingKeys.remove(key)
            settledKeys.insert(key)
            apply(fresh)
        } catch where error.isAPICancellation {
            pendingKeys.remove(key)
            restore(item, at: decision.index)
        } catch {
            pendingKeys.remove(key)
            SparkObservability.captureHandled(error)
            if case APIError.httpStatus(404, _, _) = error {
                settledKeys.insert(key)
                await load()
                actionError = "That item is no longer available. The list has been refreshed."
                return
            }
            if case APIError.httpStatus(422, _, _) = error {
                await load()
            } else {
                restore(item, at: decision.index)
            }
            actionError = (error as? LocalizedError)?.errorDescription ?? "Couldn’t save that. Please try again."
        }
    }

    private func apply(_ fresh: [FlintReviewItem]) {
        items = fresh.filter { !pendingKeys.contains($0.reviewKey) && !settledKeys.contains($0.reviewKey) }
    }

    private func restore(_ item: FlintReviewItem, at index: Int) {
        guard !items.contains(where: { $0.reviewKey == item.reviewKey }) else { return }
        items.insert(item, at: min(index, items.count))
    }
}

/// The Review tab: glass rows in a scroll view of its own. A short swipe
/// right accepts a row, a short swipe left rejects it.
struct FlintReviewSection: View {
    let model: FlintReviewModel
    @State private var showingUnmatched = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SparkSpacing.lg) {
                content

                Button {
                    showingUnmatched = true
                } label: {
                    Label("Unmatched receipts", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.medium))
                        .padding(SparkSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sparkGlass(.roundedRect(SparkRadii.lg))
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.lg)
            .padding(.bottom, SparkSpacing.xxl * 2)
        }
        .animation(.default, value: model.items.map(\.reviewKey))
        .safeAreaInset(edge: .bottom) {
            if let staged = model.staged {
                UndoToast(staged.message, systemImage: staged.isAccept ? "checkmark" : "xmark") {
                    model.undoStaged()
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.bottom, SparkSpacing.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: model.staged)
        .sensoryFeedback(trigger: model.staged) { _, new in
            guard let new else { return nil }
            return new.isAccept ? .success : .impact(weight: .medium)
        }
        .onDisappear { model.commitStaged() }
        .sheet(isPresented: $showingUnmatched) {
            NavigationStack {
                ReceiptUnmatchedView(apiClient: model.apiClient)
                    .sparkDetailDestinations()
            }
        }
        .alert("Couldn’t save", isPresented: Binding(
            get: { model.actionError != nil },
            set: { if !$0 { model.actionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.actionError ?? "Please try again.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle where model.items.isEmpty, .loading where model.items.isEmpty:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, SparkSpacing.xl)
        case .error(let message) where model.items.isEmpty:
            VStack(spacing: SparkSpacing.md) {
                EmptyState(systemImage: "wifi.exclamationmark", title: "Couldn’t load review", message: message)
                PillButton("Retry", systemImage: "arrow.clockwise", tint: .sparkAccent) {
                    Task { await model.load() }
                }
            }
            .frame(maxWidth: .infinity)
        default:
            if model.items.isEmpty {
                EmptyState(systemImage: "checkmark.circle", title: "Nothing to review", message: "Spark has nothing waiting for you.")
                    .frame(maxWidth: .infinity)
            } else {
                reviewGroup("To decide", items: model.items.filter(\.needsDecision))
                reviewGroup("Linked by Spark", items: model.items.filter { !$0.needsDecision })
            }
        }
    }

    @ViewBuilder
    private func reviewGroup(_ title: String, items: [FlintReviewItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                Text("\(title) (\(items.count))")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                ForEach(items, id: \.reviewKey) { item in
                    FlintReviewRow(item: item, model: model)
                        .transition(.opacity)
                }
            }
        }
    }
}

/// One decision on one line: the receipt or first transaction on the left,
/// what it is (or would be) linked to on the right.
private struct FlintReviewRow: View {
    let item: FlintReviewItem
    let model: FlintReviewModel
    @State private var showingReceiptMatch = false
    @State private var offset: CGFloat = 0
    @State private var rowWidth: CGFloat = 0
    @State private var isPastThreshold = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// How far a row travels before letting go commits it. Kept short so a
    /// flick of the thumb is enough.
    private static let commitDistance: CGFloat = 72

    private var isReceipt: Bool { item.kind == .receiptSuggestion || item.kind == .receiptAutoMatch }

    var body: some View {
        card
            .offset(x: offset)
            .background(alignment: offset >= 0 ? .leading : .trailing) { swipeHint }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
            .gesture(HorizontalSwipeGesture(onChanged: dragChanged, onEnded: dragEnded))
            .gesture(RowTouchTracker { touching in
                if model.isTouchingRow != touching { model.isTouchingRow = touching }
            })
            .sensoryFeedback(.selection, trigger: isPastThreshold) { _, new in new }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityActions {
                if let accept = item.acceptAction {
                    Button(accept.label) { model.stage(accept, on: item) }
                }
                if let reject = item.rejectAction {
                    Button(reject.label) { model.stage(reject, on: item) }
                }
            }
            .sheet(isPresented: $showingReceiptMatch, onDismiss: {
                Task { await model.load() }
            }) {
                NavigationStack {
                    ReceiptMatchingView(receiptID: item.subject.id, apiClient: model.apiClient)
                        .sparkDetailDestinations()
                }
            }
    }

    private var card: some View {
        Group {
            if isReceipt {
                Button { showingReceiptMatch = true } label: { pairing }
            } else {
                NavigationLink(value: DetailRoute.event(id: item.subject.id)) { pairing }
            }
        }
        .buttonStyle(.plain)
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.lg))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: SparkRadii.lg))
        .contextMenu {
            NavigationLink(value: DetailRoute.event(id: item.subject.id)) {
                Label(isReceipt ? "Open receipt" : "Open transaction", systemImage: "arrow.up.forward.app")
            }
            if let counterpart = item.counterpart {
                NavigationLink(value: DetailRoute.event(id: counterpart.id)) {
                    Label(isReceipt ? "Open transaction" : "Open linked transaction", systemImage: "arrow.up.forward.app")
                }
            }
        }
    }

    /// The strip the card uncovers as it slides: green for accept on the
    /// left, red for reject on the right. It only fills the uncovered gap so
    /// the colour never shows through the glass.
    @ViewBuilder
    private var swipeHint: some View {
        let accepting = offset > 0
        if let action = accepting ? item.acceptAction : item.rejectAction, offset != 0 {
            RoundedRectangle(cornerRadius: SparkRadii.lg)
                .fill(accepting ? Color.sparkSuccess : Color.sparkError)
                .opacity(isPastThreshold ? 1 : 0.45)
                .overlay {
                    Image(systemName: accepting ? "checkmark" : "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .scaleEffect(isPastThreshold ? 1.15 : 0.9)
                        .accessibilityLabel(action.label)
                }
                .frame(width: max(abs(offset) - SparkSpacing.xs, 0))
                .animation(.snappy(duration: 0.15), value: isPastThreshold)
        }
    }

    private func dragChanged(_ translation: CGFloat) {
        let allowed = translation > 0 ? item.acceptAction != nil : item.rejectAction != nil
        // A direction with no action still gives a little, so the row
        // doesn't feel stuck.
        offset = allowed ? translation : translation / 4
        let past = allowed && abs(translation) >= Self.commitDistance
        if past != isPastThreshold { isPastThreshold = past }
    }

    private func dragEnded(_ translation: CGFloat, _ velocity: CGFloat) {
        let action = translation > 0 ? item.acceptAction : item.rejectAction
        let flicked = abs(velocity) > 600 && abs(translation) > 24 && (velocity > 0) == (translation > 0)
        isPastThreshold = false

        guard let action, abs(translation) >= Self.commitDistance || flicked else {
            withAnimation(.snappy) { offset = 0 }
            return
        }
        let travel = max(rowWidth, 320) + SparkSpacing.xl
        withAnimation(.snappy(duration: 0.2)) {
            offset = translation > 0 ? travel : -travel
        } completion: {
            model.stage(action, on: item)
        }
    }

    private var pairing: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SparkSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: SparkSpacing.sm))
        return layout {
            FlintReviewSide(event: item.subject, alignment: .leading)
            score
            if let counterpart = item.counterpart {
                FlintReviewSide(event: counterpart, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            } else {
                Text("No match")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            }
        }
        .contentShape(Rectangle())
    }

    private var score: some View {
        VStack(spacing: 2) {
            Image(systemName: "link")
            if let confidence = item.counterpartConfidence {
                Text(confidence, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var accessibilityDescription: String {
        var parts = ["\(FlintReviewSide.title(item.subject)), \(FlintReviewSide.value(item.subject))"]
        if let counterpart = item.counterpart {
            parts.append("linked to \(FlintReviewSide.title(counterpart)), \(FlintReviewSide.value(counterpart))")
        } else {
            parts.append("no match")
        }
        if let confidence = item.counterpartConfidence {
            parts.append("\(Int((confidence * 100).rounded()))% match")
        }
        return parts.joined(separator: ", ")
    }
}

private struct FlintReviewSide: View {
    let event: FlintReviewEvent
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(Self.title(event))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(Self.value(event))
                .font(.subheadline)
                .monospacedDigit()
            if let time = event.time {
                Text(time, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }

    static func title(_ event: FlintReviewEvent) -> String {
        event.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled"
    }

    static func value(_ event: FlintReviewEvent) -> String {
        guard let amount = event.amount else { return "No amount" }
        guard let unit = event.unit, unit.count == 3 else {
            return "\(amount.formatted())\(event.unit.map { " \($0)" } ?? "")"
        }
        return amount.formatted(.currency(code: unit.uppercased()))
    }
}

struct FlintReviewEventCard: View {
    let event: FlintReviewEvent
    let role: String

    private var title: String { event.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled event" }

    private var value: String {
        guard let amount = event.amount else { return "No value recorded" }
        guard let unit = event.unit, unit.count == 3 else {
            return "\(amount.formatted())\(event.unit.map { " \($0)" } ?? "")"
        }
        return amount.formatted(.currency(code: unit.uppercased()))
    }

    private var reference: EntityReference {
        EntityReference(type: .event, id: event.id, title: title, service: event.service, domain: "money")
    }

    var body: some View {
        NavigationLink(value: DetailRoute.event(id: event.id)) {
            content
                .padding(SparkSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.sparkElevated, in: RoundedRectangle(cornerRadius: SparkRadii.md))
                .overlay(RoundedRectangle(cornerRadius: SparkRadii.md).strokeBorder(Color.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .contextMenu {
            NavigationLink(value: DetailRoute.event(id: event.id)) {
                Label("Open event", systemImage: "arrow.up.forward.app")
            }
        } preview: {
            EntityPreviewCard(reference: reference)
        }
        .accessibilityLabel("View \(role): \(title), \(value), \(event.service?.capitalized ?? "unknown source"), \(dateLabel)")
    }

    private var dateLabel: String {
        event.time?.formatted(date: .abbreviated, time: .shortened) ?? "time not recorded"
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                    roleLabel
                    Spacer(minLength: SparkSpacing.xs)
                    valueLabel
                }
                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    roleLabel
                    valueLabel
                }
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(dateLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var roleLabel: some View {
        Text("\(role) · \(event.service?.capitalized ?? "Unknown source")")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var valueLabel: some View {
        Text(value)
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.trailing)
    }
}

/// A pan that only starts when the finger moves more sideways than up or
/// down, so vertical scrolling still belongs to the scroll view.
private struct HorizontalSwipeGesture: UIGestureRecognizerRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        // Window coordinates: the row itself moves with the finger.
        let translation = recognizer.translation(in: nil).x
        switch recognizer.state {
        case .began, .changed:
            onChanged(translation)
        case .ended:
            onEnded(translation, recognizer.velocity(in: nil).x)
        case .cancelled, .failed:
            onEnded(0, 0)
        default:
            break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: nil)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

/// Reports when a finger goes down on, and lifts off, the view it's attached
/// to. It never recognises, so taps, scrolling and swipe actions carry on.
private struct RowTouchTracker: UIGestureRecognizerRepresentable {
    let onChange: (Bool) -> Void

    func makeUIGestureRecognizer(context: Context) -> TouchTrackingRecognizer {
        let recognizer = TouchTrackingRecognizer()
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: TouchTrackingRecognizer, context: Context) {
        recognizer.onChange = onChange
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private final class TouchTrackingRecognizer: UIGestureRecognizer {
    var onChange: ((Bool) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        onChange?(true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        finish()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        finish()
    }

    override func reset() {
        super.reset()
        onChange?(false)
    }

    private func finish() {
        onChange?(false)
        state = .failed
    }
}
