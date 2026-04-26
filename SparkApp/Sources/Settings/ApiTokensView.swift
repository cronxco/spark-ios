import SparkKit
import SparkUI
import SwiftUI

struct ApiTokensView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: ApiTokensViewModel?
    @State private var showCreateSheet = false
    @State private var showCopyBanner = false

    var body: some View {
        Group {
            switch viewModel?.state {
            case .loaded(let tokens):
                tokenList(tokens)
            case .error(let msg):
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load tokens",
                    message: msg,
                    actionTitle: "Retry"
                ) { Task { await viewModel?.load() } }
            default:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("API Tokens")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateTokenSheet(viewModel: viewModel ?? ApiTokensViewModel(apiClient: appModel.apiClient)) {
                showCreateSheet = false
                showCopyBanner = viewModel?.createdToken != nil
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showCopyBanner, let token = viewModel?.createdToken {
                CopyTokenBanner(token: token.plaintext) {
                    showCopyBanner = false
                    viewModel?.createdToken = nil
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: showCopyBanner)
        .task {
            if viewModel == nil {
                viewModel = ApiTokensViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    private func tokenList(_ tokens: [ApiToken]) -> some View {
        Group {
            if tokens.isEmpty {
                EmptyState(
                    systemImage: "key.fill",
                    title: "No tokens",
                    message: "Create an API token to access Spark from external tools."
                )
            } else {
                List(tokens) { token in
                    TokenRow(token: token)
                }
            }
        }
    }
}

private struct TokenRow: View {
    let token: ApiToken

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(token.name)
                .font(SparkTypography.body)
            TagChipRow(token.abilities)
                .padding(.top, 2)
            if let used = token.lastUsedAt {
                Text("Last used \(used.formatted(.relative(presentation: .named)))")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            } else {
                Text("Never used")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CreateTokenSheet: View {
    @Bindable var viewModel: ApiTokensViewModel
    let onDone: () -> Void

    private let availableAbilities = ["mcp:read", "mcp:write", "webhooks:read", "data:export"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Claude MCP", text: $viewModel.newTokenName)
                }
                Section("Abilities") {
                    ForEach(availableAbilities, id: \.self) { ability in
                        Toggle(ability, isOn: Binding(
                            get: { viewModel.newTokenAbilities.contains(ability) },
                            set: { on in
                                if on { viewModel.newTokenAbilities.append(ability) }
                                else { viewModel.newTokenAbilities.removeAll { $0 == ability } }
                            }
                        ))
                        .font(SparkTypography.monoSmall)
                    }
                }
                if let err = viewModel.createError {
                    Section {
                        Text(err)
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(Color.sparkError)
                    }
                }
            }
            .navigationTitle("New Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDone() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        Task {
                            await viewModel.create()
                            onDone()
                        }
                    }
                    .disabled(viewModel.newTokenName.isEmpty || viewModel.isCreating)
                }
            }
        }
    }
}

private struct CopyTokenBanner: View {
    let token: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Token created — copy it now")
                    .font(SparkTypography.bodyStrong)
                Text(token)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: SparkSpacing.sm)
            Button {
                UIPasteboard.general.string = token
            } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(Color.sparkAccent)
            }
            .accessibilityLabel("Copy token")
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(SparkSpacing.lg)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: SparkRadii.lg))
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.bottom, SparkSpacing.md)
    }
}
