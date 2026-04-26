import SparkUI
import SwiftUI

/// Notification preferences. Populated fully on D12.
struct NotificationsPreferencesView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
    }
}
