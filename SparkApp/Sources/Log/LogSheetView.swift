import SparkKit
import SparkUI
import SwiftUI

/// Type a line, check what was understood, log it. The model reads it on the phone and the sheet shows
/// the type, name, time, amount and people it found. Fix anything wrong, then the backend writes and enriches it,
/// and a TV entry that needs a series or season asks first.
struct LogSheetView: View {
    let apiClient: APIClient

    @Environment(\.dismiss) private var dismiss
    @State private var model = LogViewModel()
    @State private var detent: PresentationDetent = .medium
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    TextField("Had half a bottle of Rioja", text: Binding(
                        get: { model.text },
                        set: { newValue in
                            guard newValue.contains("\n") else {
                                model.updateText(newValue)
                                return
                            }
                            model.updateText(newValue.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces))
                            submit()
                        }
                    ), axis: .vertical)
                        .font(SparkTypography.body)
                        .lineLimit(1...4)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .padding(SparkSpacing.md)
                        .sparkGlass(.roundedRect(SparkRadii.md))
                        .disabled(!isEditable)
                        .onSubmit { submit() }
                        .accessibilityLabel("What did you have?")

                    content
                        .animation(.spring(duration: 0.45, bounce: 0.2), value: model.phase)
                }
                .padding(SparkSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SparkResolvedAppBackground().ignoresSafeArea())
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isFinished ? "Done" : "Cancel") { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .onChange(of: isPreviewing) { _, previewing in
            if previewing { detent = .large }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            EmptyView()
        case .working(let label):
            HStack(spacing: SparkSpacing.sm) {
                Image(systemName: "sparkles")
                    .symbolEffect(.variableColor.iterative.reversing, isActive: true)
                    .foregroundStyle(Color.sparkAccent)
                Text(label)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
            .accessibilityElement(children: .combine)
        case .preview:
            LogPreviewCard(
                draft: Bindable(model).draft,
                match: model.matchState,
                chosenCard: model.chosenCard,
                canLog: model.canConfirm,
                onAnswerQuestion: { model.answerMatchQuestion($0) },
                onChooseMatch: { model.chooseMatch($0) },
                onAddPerson: { model.addPerson($0) },
                onRemovePerson: { model.removePerson($0) },
                onEdit: {
                    model.edit()
                    isFocused = true
                },
                onLog: { Task { await model.confirm(using: apiClient) } }
            )
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .task(id: model.matchKey) { await model.refreshMatch(using: apiClient) }
        case .question(let question):
            LogQuestionCard(question: question) { option in
                Task { await model.answer(option, using: apiClient) }
            }
        case .logged(let outcome):
            LogOutcomeCard(outcome: outcome, undoError: model.undoError) {
                Task { await model.undo(using: apiClient) }
            }
        case .undone:
            HStack {
                Label("Removed", systemImage: "arrow.uturn.backward")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Log another") {
                    model.reset()
                    isFocused = true
                }
                .font(SparkTypography.bodySmall)
            }
        case .failed(let message):
            Text(message)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(Color.sparkError)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var isEditable: Bool {
        switch model.phase {
        case .idle, .failed: true
        default: false
        }
    }

    private var isPreviewing: Bool {
        if case .preview = model.phase { return true }
        return false
    }

    private var isFinished: Bool {
        switch model.phase {
        case .logged, .undone: true
        default: false
        }
    }

    private func submit() {
        guard model.canSubmit, isEditable else { return }
        isFocused = false
        Task { await model.submit(using: apiClient) }
    }
}

/// The logged result with its Undo.
private struct LogOutcomeCard: View {
    let outcome: LogViewModel.Outcome
    let undoError: String?
    let onUndo: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            ForEach(outcome.events) { event in
                Label {
                    Text(event.title ?? "Logged")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolEffect(.bounce, value: appeared)
                }
                .font(SparkTypography.bodyStrong)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.sparkAccent)
            }

            if !outcome.people.isEmpty {
                Label(
                    "With " + outcome.people.map { $0.created ? "\($0.name) (new)" : $0.name }.joined(separator: ", "),
                    systemImage: "person.2"
                )
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
            }

            if !outcome.missingEpisodes.isEmpty {
                Text("No episode \(outcome.missingEpisodes.map(String.init).joined(separator: ", ")).")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if let undoError {
                Text(undoError)
                    .font(SparkTypography.caption)
                    .foregroundStyle(Color.sparkError)
            }

            Button("Undo", action: onUndo)
                .font(SparkTypography.bodySmall)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.md)
        .sparkGlass(.roundedRect(SparkRadii.md))
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear { appeared = true }
    }
}

/// Which series, or which season, with the likeliest answer first.
struct LogQuestionCard: View {
    let question: LogClarification
    let onSelect: (LogClarification.Option) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Text(question.question)
                .font(SparkTypography.bodyStrong)

            ForEach(orderedOptions) { option in
                Button {
                    onSelect(option)
                } label: {
                    VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                        Text(option.label)
                            .font(SparkTypography.body)
                        if let overview = option.overview, !overview.isEmpty {
                            Text(overview)
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SparkSpacing.md)
                    .sparkGlass(.roundedRect(SparkRadii.md))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
            }
        }
    }

    private var orderedOptions: [LogClarification.Option] {
        guard let suggested = question.suggested else { return question.options }
        return question.options.filter { $0.value == suggested } + question.options.filter { $0.value != suggested }
    }
}
