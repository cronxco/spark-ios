import SparkUI
import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: version)
                    .font(SparkTypography.body)
                LabeledContent("Build", value: build)
                    .font(SparkTypography.monoSmall)
            }

            Section("Legal") {
                Link(destination: URL(string: "https://spark.cronx.co/legal/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
                Link(destination: URL(string: "https://spark.cronx.co/legal/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                Link(destination: URL(string: "https://spark.cronx.co/legal/licenses")!) {
                    Label("Open Source Licenses", systemImage: "scroll")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
