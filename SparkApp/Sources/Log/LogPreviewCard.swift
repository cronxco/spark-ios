import SparkKit
import SparkUI
import SwiftUI

/// What was understood from the line, one row each for the type, name, amount, time and people.
/// Every row can be fixed before anything is logged.
struct LogPreviewCard: View {
    @Binding var draft: LogRequest
    let match: LogViewModel.MatchState
    let chosenCard: LogMatch.Card?
    let canLog: Bool
    let onAnswerQuestion: (LogClarification.Option) -> Void
    let onChooseMatch: (LogMatch.Card?) -> Void
    let personCheck: (String) -> LogPersonCheck?
    let isNewPerson: (String) -> Bool
    let onResolvePerson: (String, LogPersonCheck.Match) -> Void
    let onKeepNewPerson: (String) -> Void
    let onAddPerson: (String) -> Void
    let onRemovePerson: (String) -> Void
    let onEdit: () -> Void
    let onLog: () -> Void

    @State private var newPerson = ""

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            LogPreviewRow(index: 0, symbol: LogPreviewFormat.kindSymbol(draft.kind), label: "Type") {
                Text(LogPreviewFormat.kindName(draft.kind))
                    .font(SparkTypography.bodyStrong)
            }

            LogPreviewRow(index: 1, symbol: "textformat", label: "Name") {
                TextField("Name", text: $draft.title)
                    .font(SparkTypography.body)
            }

            if draft.kind != .cinema, draft.kind != .boardGame {
                LogPreviewRow(index: 2, symbol: "sparkle.magnifyingglass", label: "Match") {
                    LogMatchView(
                        kind: draft.kind,
                        state: match,
                        chosen: chosenCard,
                        onAnswer: onAnswerQuestion,
                        onChoose: onChooseMatch
                    )
                }
            }

            if draft.kind == .tv {
                LogPreviewRow(index: 3, symbol: "number", label: "Season") {
                    Text(draft.season.map { "Season \($0)" } ?? "Not said, you’ll be asked")
                        .font(SparkTypography.body)
                        .foregroundStyle(draft.season == nil ? .secondary : .primary)
                }
                LogPreviewRow(index: 4, symbol: "list.number", label: "Episodes") {
                    Text(LogPreviewFormat.episodes(draft.episodes ?? []))
                        .font(SparkTypography.body)
                }
            } else if draft.kind == .wine || draft.kind == .beer {
                LogPreviewRow(index: 3, symbol: "scalemass", label: "Amount") {
                    HStack {
                        Text(LogPreviewFormat.amount(draft) ?? "Not said")
                            .font(SparkTypography.body)
                            .foregroundStyle(draft.quantity == nil && draft.unit == nil && draft.serving == nil ? .secondary : .primary)
                        Spacer()
                        Stepper("Quantity", value: quantity, in: 0.5...100, step: 0.5)
                            .labelsHidden()
                    }
                }
            }

            LogPreviewRow(index: 5, symbol: "clock", label: "When") {
                HStack {
                    Text(LogPreviewFormat.when(draft.occurredAt))
                        .font(SparkTypography.body)
                    Spacer()
                    DatePicker("When", selection: occurredAt, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }

            LogPreviewRow(index: 6, symbol: "person.2", label: "With") {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    if let people = draft.people, !people.isEmpty {
                        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                            ForEach(people, id: \.self) { name in
                                LogPersonRow(
                                    name: name,
                                    check: personCheck(name),
                                    isNew: isNewPerson(name),
                                    onResolve: { onResolvePerson(name, $0) },
                                    onKeepNew: { onKeepNewPerson(name) },
                                    onRemove: { onRemovePerson(name) }
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    TextField("Add someone", text: $newPerson)
                        .font(SparkTypography.body)
                        .submitLabel(.done)
                        .onSubmit {
                            onAddPerson(newPerson)
                            newPerson = ""
                        }
                }
                .animation(.spring(duration: 0.35, bounce: 0.25), value: draft.people)
            }

            LogPreviewRow(index: 7, symbol: "star", label: "Rating") {
                LogStarRating(rating: $draft.rating)
            }

            HStack {
                Button("Edit", action: onEdit)
                    .font(SparkTypography.bodySmall)
                Spacer()
                Button("Log") {
                    let person = newPerson.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !person.isEmpty {
                        onAddPerson(person)
                    }
                    onLog()
                    newPerson = ""
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canLog)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.md)
        .sparkGlass(.roundedRect(SparkRadii.md))
        .sensoryFeedback(.impact(weight: .light), trigger: draft.kind)
    }

    private var quantity: Binding<Double> {
        Binding(
            get: { draft.quantity ?? 1 },
            set: { draft.quantity = $0 }
        )
    }

    private var occurredAt: Binding<Date> {
        Binding(
            get: { draft.occurredAt ?? .now },
            set: { draft.occurredAt = $0 >= Date.now.addingTimeInterval(-120) ? nil : $0 }
        )
    }
}

/// One line of the preview: an icon, a label and the value, sliding in after the line above it.
private struct LogPreviewRow<Content: View>: View {
    let index: Int
    let symbol: String
    let label: String
    @ViewBuilder let content: Content

    @State private var shown = false

    var body: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            Image(systemName: symbol)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(Color.sparkAccent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(label)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 12)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3).delay(Double(index) * 0.07)) {
                shown = true
            }
        }
    }
}

/// Up to five stars. Tapping the star already chosen clears the rating.
private struct LogStarRating: View {
    @Binding var rating: Double?

    var body: some View {
        HStack(spacing: SparkSpacing.xs) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = rating == Double(star) ? nil : Double(star)
                } label: {
                    Image(systemName: Double(star) <= (rating ?? 0) ? "star.fill" : "star")
                        .font(SparkTypography.body)
                        .foregroundStyle(Double(star) <= (rating ?? 0) ? Color.sparkAccent : .secondary)
                        .symbolEffect(.bounce, value: rating == Double(star))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(star) \(star == 1 ? "star" : "stars")")
            }
            if rating == nil {
                Text("Not rated")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sensoryFeedback(.selection, trigger: rating)
    }
}

/// What the backend would match: the Vivino or Untappd card, or the TheTVDB series, season and episodes.
private struct LogMatchView: View {
    let kind: LogKind
    let state: LogViewModel.MatchState
    let chosen: LogMatch.Card?
    let onAnswer: (LogClarification.Option) -> Void
    let onChoose: (LogMatch.Card?) -> Void

    @State private var showsOthers = false
    @State private var pulsing = false

    var body: some View {
        switch state {
        case .idle, .loading:
            HStack(spacing: SparkSpacing.sm) {
                Image(systemName: "magnifyingglass")
                Text("Looking up…")
            }
            .font(SparkTypography.bodySmall)
            .foregroundStyle(.secondary)
            .opacity(pulsing ? 0.35 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulsing = true }
            }
        case .failed:
            note("Couldn’t reach Spark. It will still log.")
        case .question(let question):
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                Text(question.question)
                    .font(SparkTypography.bodyStrong)
                ForEach(orderedOptions(question)) { option in
                    Button(option.label) { onAnswer(option) }
                        .font(SparkTypography.bodySmall)
                        .buttonStyle(.bordered)
                }
            }
        case .loaded(let match):
            if let match {
                loaded(match)
            }
        }
    }

    @ViewBuilder
    private func loaded(_ match: LogMatch) -> some View {
        switch match.state {
        case .unavailable:
            note("Couldn’t check. It will still log.")
        case .none:
            note(kind == .tv ? "TheTVDB doesn’t know this show." : "No match. It will log as typed.")
        case .matched where kind == .tv:
            television(match)
        case .matched, .candidates:
            drink(match)
        }
    }

    private func television(_ match: LogMatch) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
            if let series = match.series {
                Text(match.season.map { "\(series.name) · Season \($0)" } ?? series.name)
                    .font(SparkTypography.bodyStrong)
            }
            ForEach(match.episodes) { episode in
                Text("E\(episode.number)" + (episode.name.map { " \($0)" } ?? ""))
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
            if !match.missingEpisodes.isEmpty {
                Text("No episode \(match.missingEpisodes.map(String.init).joined(separator: ", ")).")
                    .font(SparkTypography.caption)
                    .foregroundStyle(Color.sparkError)
            }
        }
    }

    private func drink(_ match: LogMatch) -> some View {
        let shown = chosen ?? match.best
        let others = match.candidates + (chosen != nil ? [match.best].compactMap { $0 } : [])

        return VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            if let shown {
                card(shown)
            } else {
                note("No close match. It will log as typed.")
            }

            if !others.isEmpty {
                Button(showsOthers ? "Hide" : (shown == nil ? "Closest" : "Not this one?")) {
                    withAnimation(.spring(duration: 0.35, bounce: 0.2)) { showsOthers.toggle() }
                }
                .font(SparkTypography.caption)

                if showsOthers {
                    ForEach(others) { other in
                        Button {
                            onChoose(other.id == match.best?.id ? nil : other)
                            withAnimation(.spring(duration: 0.35, bounce: 0.2)) { showsOthers = false }
                        } label: {
                            HStack {
                                card(other)
                                Spacer(minLength: 0)
                                Text("\(Int((other.score * 100).rounded()))%")
                                    .font(SparkTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private func card(_ card: LogMatch.Card) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
            Text(card.title)
                .font(SparkTypography.bodyStrong)
                .multilineTextAlignment(.leading)
            let detail = [card.detail, card.rating.map { String(format: "★ %.1f", $0) }].compactMap { $0 }.joined(separator: " · ")
            if !detail.isEmpty {
                Text(detail)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(SparkTypography.bodySmall)
            .foregroundStyle(.secondary)
    }

    private func orderedOptions(_ question: LogClarification) -> [LogClarification.Option] {
        guard let suggested = question.suggested else { return question.options }
        return question.options.filter { $0.value == suggested } + question.options.filter { $0.value != suggested }
    }
}

/// One named person: the chip with its remove button, and whether they match someone known.
private struct LogPersonRow: View {
    let name: String
    let check: LogPersonCheck?
    let isNew: Bool
    let onResolve: (LogPersonCheck.Match) -> Void
    let onKeepNew: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            HStack(spacing: SparkSpacing.sm) {
                Button(action: onRemove) {
                    HStack(spacing: SparkSpacing.xxs) {
                        Text(name)
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .font(SparkTypography.bodySmall)
                    .padding(.horizontal, SparkSpacing.sm)
                    .padding(.vertical, SparkSpacing.xxs)
                    .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(name)")

                status
            }

            if !isNew, let check, check.state == .likely || check.state == .ambiguous {
                HStack(spacing: SparkSpacing.sm) {
                    ForEach(check.matches) { match in
                        Button(match.name) { onResolve(match) }
                            .buttonStyle(.bordered)
                    }
                    Button("New", action: onKeepNew)
                        .buttonStyle(.bordered)
                }
                .font(SparkTypography.bodySmall)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: check)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: isNew)
    }

    @ViewBuilder
    private var status: some View {
        if isNew {
            label("New", symbol: "person.badge.plus", tint: .secondary)
        } else if let check {
            switch check.state {
            case .existing:
                label("Matched", symbol: "checkmark.circle.fill", tint: Color.sparkAccent)
            case .likely, .ambiguous:
                label("Which one?", symbol: "questionmark.circle", tint: .secondary)
            case .new:
                label("New", symbol: "person.badge.plus", tint: .secondary)
            }
        }
    }

    private func label(_ text: String, symbol: String, tint: some ShapeStyle) -> some View {
        Label(text, systemImage: symbol)
            .font(SparkTypography.caption)
            .foregroundStyle(tint)
            .symbolRenderingMode(.hierarchical)
    }
}
