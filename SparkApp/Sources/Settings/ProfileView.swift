import Foundation
import SparkKit
import SparkUI
import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var appModel
    @AppStorage("spark.background.mode", store: .sparkAppGroup)
    private var backgroundMode = SparkAppBackgroundMode.auto.rawValue
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
                Text("Your Spark account and appearance preferences.")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

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

                GlassCard {
                    VStack(alignment: .leading, spacing: SparkSpacing.md) {
                        GlassCardHeader(
                            icon: "paintpalette.fill",
                            tint: .sparkAccent,
                            title: "Appearance"
                        )

                        Picker("Background", selection: backgroundModeBinding) {
                            ForEach(SparkAppBackgroundMode.allCases) { mode in
                                Text(mode.displayName).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: SparkSpacing.md) {
                        GlassCardHeader(
                            icon: "globe",
                            tint: .sparkAccent,
                            title: "Timezone"
                        )

                        LabeledContent(
                            "Spark",
                            value: appModel.timezoneState?.timezone ?? profile.timezone ?? "Unknown"
                        )
                        LabeledContent(
                            "Device",
                            value: TimeZone.autoupdatingCurrent.identifier
                        )

                        Button("Reconsider Device Timezone") {
                            Task { await appModel.reconsiderTimezoneChange() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.vertical, SparkSpacing.xl)
        }
        .scrollContentBackground(.hidden)
    }

    private var backgroundModeBinding: Binding<String> {
        Binding(
            get: {
                SparkAppBackgroundMode(rawValue: backgroundMode)?.rawValue
                    ?? SparkAppBackgroundMode.auto.rawValue
            },
            set: { backgroundMode = $0 }
        )
    }
}
