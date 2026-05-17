import SparkKit
import SparkUI
import SwiftUI

struct CreateAccountSheet: View {
    let onSuccess: (MoneyAccount) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var accountType = "current_account"
    @State private var currency = "GBP"
    @State private var provider = ""
    @State private var accountNumber = ""
    @State private var sortCode = ""
    @State private var interestRateText = ""
    @State private var startDate = Date.now
    @State private var showStartDate = false
    @State private var isNegativeBalance = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private var negativeForced: Bool {
        ["credit_card", "loan", "mortgage"].contains(accountType)
    }

    private var showAccountNumber: Bool {
        ["current_account", "savings_account", "mortgage"].contains(accountType)
    }

    private var showInterestRate: Bool {
        ["savings_account", "loan", "mortgage", "pension"].contains(accountType)
    }

    var body: some View {
        SparkSheetScaffold("New Account") {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                // Name
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    SectionLabel("ACCOUNT NAME")
                    TextField("e.g. Monzo Current", text: $name)
                        .font(SparkTypography.body)
                        .padding(SparkSpacing.md)
                        .sparkGlass(.roundedRect(SparkRadii.md))
                }

                // Account Type
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    SectionLabel("TYPE")
                    Picker("Account Type", selection: $accountType) {
                        ForEach(AccountTypeOption.allCases, id: \.value) { opt in
                            Text(opt.label).tag(opt.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(SparkSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sparkGlass(.roundedRect(SparkRadii.md))
                }
                .onChange(of: accountType) { _, newType in
                    if ["credit_card", "loan", "mortgage"].contains(newType) {
                        isNegativeBalance = true
                    }
                }

                // Currency
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    SectionLabel("CURRENCY")
                    Picker("Currency", selection: $currency) {
                        Text("GBP (£)").tag("GBP")
                        Text("USD ($)").tag("USD")
                        Text("EUR (€)").tag("EUR")
                    }
                    .pickerStyle(.segmented)
                    .padding(SparkSpacing.md)
                    .sparkGlass(.roundedRect(SparkRadii.md))
                }

                // Provider
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    SectionLabel("PROVIDER (OPTIONAL)")
                    TextField("e.g. Monzo, Barclays", text: $provider)
                        .font(SparkTypography.body)
                        .padding(SparkSpacing.md)
                        .sparkGlass(.roundedRect(SparkRadii.md))
                }

                // Account Number + Sort Code (conditional)
                if showAccountNumber {
                    HStack(alignment: .top, spacing: SparkSpacing.md) {
                        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                            SectionLabel("ACCOUNT NO.")
                            TextField("Optional", text: $accountNumber)
                                .font(SparkTypography.body)
                                .keyboardType(.numberPad)
                                .padding(SparkSpacing.md)
                                .sparkGlass(.roundedRect(SparkRadii.md))
                        }
                        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                            SectionLabel("SORT CODE")
                            TextField("00-00-00", text: $sortCode)
                                .font(SparkTypography.body)
                                .keyboardType(.numberPad)
                                .padding(SparkSpacing.md)
                                .sparkGlass(.roundedRect(SparkRadii.md))
                        }
                    }
                }

                // Interest Rate (conditional)
                if showInterestRate {
                    VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                        SectionLabel("INTEREST RATE (%)")
                        TextField("0.00", text: $interestRateText)
                            .keyboardType(.decimalPad)
                            .font(SparkTypography.body)
                            .padding(SparkSpacing.md)
                            .sparkGlass(.roundedRect(SparkRadii.md))
                    }
                }

                // Start Date
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    Toggle(isOn: $showStartDate) {
                        SectionLabel("START DATE")
                    }
                    .toggleStyle(.switch)
                    if showStartDate {
                        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .padding(SparkSpacing.md)
                            .sparkGlass(.roundedRect(SparkRadii.md))
                    }
                }

                // Negative Balance toggle (only when not forced)
                if !negativeForced {
                    VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                        Toggle("Debt account (higher balance = worse)", isOn: $isNegativeBalance)
                            .font(SparkTypography.bodySmall)
                            .padding(SparkSpacing.md)
                            .sparkGlass(.roundedRect(SparkRadii.md))
                    }
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
                        if isSubmitting { ProgressView().scaleEffect(0.85) }
                        Text(isSubmitting ? "Creating…" : "Create Account")
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
        isSubmitting = true
        errorMessage = nil

        let request = CreateAccountRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            accountType: accountType,
            currency: currency,
            provider: provider.isEmpty ? nil : provider,
            accountNumber: accountNumber.isEmpty ? nil : accountNumber,
            sortCode: sortCode.isEmpty ? nil : sortCode,
            interestRate: Double(interestRateText),
            startDate: showStartDate ? startDate.formatted(.iso8601.year().month().day()) : nil,
            isNegativeBalance: isNegativeBalance
        )

        do {
            let response = try await appModel.apiClient.request(MoneyEndpoint.createAccount(request))
            onSuccess(response.data)
            dismiss()
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't create account."
        }

        isSubmitting = false
    }
}

private enum AccountTypeOption: CaseIterable {
    case currentAccount, savingsAccount, creditCard, mortgage, loan, investmentAccount, pension, other

    var value: String {
        switch self {
        case .currentAccount: "current_account"
        case .savingsAccount: "savings_account"
        case .creditCard: "credit_card"
        case .mortgage: "mortgage"
        case .loan: "loan"
        case .investmentAccount: "investment_account"
        case .pension: "pension"
        case .other: "other"
        }
    }

    var label: String {
        switch self {
        case .currentAccount: "Current Account"
        case .savingsAccount: "Savings Account"
        case .creditCard: "Credit Card"
        case .mortgage: "Mortgage"
        case .loan: "Loan"
        case .investmentAccount: "Investment Account"
        case .pension: "Pension"
        case .other: "Other"
        }
    }
}
