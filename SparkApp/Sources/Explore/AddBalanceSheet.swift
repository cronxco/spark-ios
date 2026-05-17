import SparkKit
import SparkUI
import SwiftUI

struct AddBalanceSheet: View {
    let accountId: String
    let currency: String
    let onSuccess: (BalanceEntry) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var balanceText = ""
    @State private var date = Date.now
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isValid: Bool { !balanceText.isEmpty && Double(balanceText) != nil }

    var body: some View {
        SparkSheetScaffold("Add Balance") {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                // Balance field
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    SectionLabel("BALANCE (\(currency))")
                    TextField("0.00", text: $balanceText)
                        .keyboardType(.decimalPad)
                        .font(SparkTypography.body)
                        .padding(SparkSpacing.md)
                        .sparkGlass(.roundedRect(SparkRadii.md))
                }

                // Date field
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    SectionLabel("DATE")
                    DatePicker("Balance date", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .padding(SparkSpacing.md)
                        .sparkGlass(.roundedRect(SparkRadii.md))
                }

                // Notes field
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    HStack {
                        SectionLabel("NOTES")
                        Spacer()
                        Text("\(notes.count)/500")
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                    TextEditor(text: Binding(
                        get: { notes },
                        set: { notes = String($0.prefix(500)) }
                    ))
                    .font(SparkTypography.body)
                    .frame(minHeight: 72, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(SparkSpacing.md)
                    .sparkGlass(.roundedRect(SparkRadii.md))
                }

                if let error = errorMessage {
                    Text(error)
                        .font(SparkTypography.caption)
                        .foregroundStyle(Color.sparkError)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().scaleEffect(0.85)
                        }
                        Text(isSubmitting ? "Saving…" : "Save Balance")
                            .font(SparkTypography.bodyStrong)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(SparkSpacing.md)
                    .sparkGlass(.roundedRect(SparkRadii.md), tint: Color.domainMoney.opacity(0.25))
                }
                .buttonStyle(.plain)
                .disabled(!isValid || isSubmitting)
                .opacity(isValid ? 1 : 0.5)
            }
        }
    }

    private func submit() async {
        guard let balance = Double(balanceText) else { return }
        isSubmitting = true
        errorMessage = nil

        let dateString = date.formatted(.iso8601.year().month().day())
        let request = AddBalanceRequest(
            balance: balance,
            date: dateString,
            notes: notes.isEmpty ? nil : notes
        )

        do {
            let response = try await appModel.apiClient.request(
                MoneyEndpoint.addBalance(accountId: accountId, request)
            )
            onSuccess(response.data)
            dismiss()
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't save balance."
        }

        isSubmitting = false
    }
}
