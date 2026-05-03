import SparkKit
import SparkUI
import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: ProfileViewModel?

    var body: some View {
        Group {
            switch viewModel?.state {
            case .loaded(let profile):
                profileContent(profile)
            case .error(let msg):
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load profile",
                    message: msg,
                    actionTitle: "Retry"
                ) { Task { await viewModel?.load() } }
            default:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.sparkSurface.ignoresSafeArea())
        .task {
            if viewModel == nil {
                viewModel = ProfileViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    private func profileContent(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: SparkSpacing.lg) {
                GlassCard {
                    VStack(spacing: SparkSpacing.md) {
                        AsyncImage(url: profile.avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(Color.sparkAccent)
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(.circle)
                        .frame(maxWidth: .infinity)

                        Text(profile.name)
                            .font(SparkFonts.display(.title2, weight: .bold))
                            .multilineTextAlignment(.center)

                        Text(profile.email)
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)

                        if let timezone = profile.timezone {
                            Text(timezone)
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.vertical, SparkSpacing.xl)
        }
        .scrollContentBackground(.hidden)
    }
}
