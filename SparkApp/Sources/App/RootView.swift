import SparkKit
import SparkUI
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.session {
            case .unknown:
                ProgressView()
                    .task { await model.bootstrap() }
            case .loggedOut:
                LoginView()
            case .loggedIn:
                MainTabView()
            }
        }
        .onOpenURL(perform: handle(url:))
    }

    private func handle(url: URL) {
        guard let link = DeepLink.parse(url) else { return }
        switch link {
        case .authCallback:
            break // ASWebAuthenticationSession owns the callback.
        case .today(let date):
            model.pendingRoute = .today(date: date)
        case .day(let date):
            model.pendingRoute = .day(date)
        case .event(let id):
            model.pendingRoute = .event(id: id)
        }
    }
}
