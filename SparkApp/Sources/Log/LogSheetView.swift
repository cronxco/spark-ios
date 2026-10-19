import SparkKit
import SparkUI
import SwiftUI

/// Type a line, get it logged. The model reads it on the phone, the backend writes and enriches it,
/// and a TV entry that needs a series or season asks first.
struct LogSheetView: View {
    let apiClient: APIClient

    @Environment(\.dismiss) private var dismiss
    @State private var model = LogViewModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                TextField("Had half a bottle of Rioja", text: Binding(
                    get: { model.text },
                    set: { model.updateText($0) }
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

                Spacer(minLength: 0)
            }
            .padding(SparkSpacing.lg)
            .background(SparkResolvedAppBackground().ignoresSafeArea())
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isFinished ? "Done" : "Cancel") { dismiss() }
                }
                if !isFinished {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Log") { submit() }
                            .disabled(!model.canSubmit || !isEditable)
                    }
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            EmptyView()
        case .working(let label):
            HStack(spacing: SparkSpacing.sm) {
                ProgressView()
                Text(label)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
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

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            ForEach(outcome.events) { event in
                Label(event.title ?? "Logged", systemImage: "checkmark.circle.fill")
                    .font(SparkTypography.bodyStrong)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.sparkAccent)
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
