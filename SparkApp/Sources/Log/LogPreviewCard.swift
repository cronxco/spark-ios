import SparkKit
import SparkUI
import SwiftUI

/// What was understood from the line, one row each for the type, name, amount, time and people.
/// Every row can be fixed before anything is logged.
struct LogPreviewCard: View {
    @Binding var draft: LogRequest
    let canLog: Bool
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

            if draft.kind == .tv {
                LogPreviewRow(index: 2, symbol: "number", label: "Season") {
                    Text(draft.season.map { "Season \($0)" } ?? "Not said, you’ll be asked")
                        .font(SparkTypography.body)
                        .foregroundStyle(draft.season == nil ? .secondary : .primary)
                }
                LogPreviewRow(index: 3, symbol: "list.number", label: "Episodes") {
                    Text(LogPreviewFormat.episodes(draft.episodes ?? []))
                        .font(SparkTypography.body)
                }
            } else if draft.kind == .wine || draft.kind == .beer {
                LogPreviewRow(index: 2, symbol: "scalemass", label: "Amount") {
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

            LogPreviewRow(index: 4, symbol: "clock", label: "When") {
                HStack {
                    Text(LogPreviewFormat.when(draft.occurredAt))
                        .font(SparkTypography.body)
                    Spacer()
                    DatePicker("When", selection: occurredAt, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }

            LogPreviewRow(index: 5, symbol: "person.2", label: "With") {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    if let people = draft.people, !people.isEmpty {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 96), spacing: SparkSpacing.sm)],
                            alignment: .leading,
                            spacing: SparkSpacing.sm
                        ) {
                            ForEach(people, id: \.self) { name in
                                Button {
                                    onRemovePerson(name)
                                } label: {
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

            HStack {
                Button("Edit", action: onEdit)
                    .font(SparkTypography.bodySmall)
                Spacer()
                Button("Log", action: onLog)
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
