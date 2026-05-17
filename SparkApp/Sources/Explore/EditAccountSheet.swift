import SparkKit
import SparkUI
import SwiftUI

struct EditAccountSheet: View {
    let account: MoneyAccount
    let onSuccess: (MoneyAccount) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var accountType: String
    @State private var currency: String
    @State private var provider: String
    @State private var accountNumber: String
    @State private var sortCode: String
    @State private var interestRateText: String
    @State private var startDate: Date
    @State private var showStartDate: Bool
    @State private var isNegativeBalance: Bool
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(account: MoneyAccount, onSuccess: @escaping (MoneyAccount) -> Void) {
        self.account = account
        self.onSuccess = onSuccess
        _name = State(initialValue: account.title)
        _accountType = State(initialValue: account.accountType ?? "other")
        _currency = State(initialValue: account.currency)
        _provider = State(initialValue: account.provider ?? "")
        _accountNumber = State(initialValue: account.accountNumber ?? "")
        _sortCode = State(initialValue: account.sortCode ?? "")
        _interestRateText = State(initialValue: account.interestRate.map { String($0) } ?? "")
        let parsedDate = account.startDate.flatMap { DateFormatter.iso8601Short.date(from: $0) } ?? Date.now
        _startDate = State(initialValue: parsedDate)
        _showStartDate = State(initialValue: account.startDate != nil)
        _isNegativeBalance = State(initialValue: account.isNegativeBalance)
    }

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
        SparkSheetScaffold("Edit Account") {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    SectionLabel("ACCOUNT NAME")
                    TextField("Account name", text: $name)
                        .font(SparkTypography.body)
                        .padding(SparkSpacing.md)
                        .sparkGlass(.roundedRect(SparkRadii.md))
                }

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

                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    SectionLabel("PROVIDER (OPTIONAL)")
                    TextField("e.g. Monzo, Barclays", text: $provider)
                        .font(SparkTypography.body)
                        .padding(SparkSpacing.md)
                        .sparkGlass(.roundedRect(SparkRadii.md))
                }

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
                        Text(isSubmitting ? "Saving…" : "Save Changes")
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

        let request = UpdateAccountRequest(
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
            let response = try await appModel.apiClient.request(
                MoneyEndpoint.updateAccount(id: account.id, request)
            )
            onSuccess(response.data)
            dismiss()
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't save changes."
        }

        isSubmitting = false
    }
}

private extension DateFormatter {
    static let iso8601Short: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
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
