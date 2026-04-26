import SparkKit
import SparkUI
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var onboardingComplete: Bool = {
        UserDefaults(suiteName: "group.co.cronx.spark")?.bool(forKey: "onboarding.completed") == true
    }()

    var body: some View {
        Group {
            switch model.session {
            case .unknown:
                ProgressView()
                    .task { await model.bootstrap() }
            case .loggedOut:
                OnboardingFlow(isComplete: $onboardingComplete)
            case .loggedIn:
                if onboardingComplete {
                    MainTabView()
                } else {
                    OnboardingFlow(isComplete: $onboardingComplete)
                }
            }
        }
        .onOpenURL(perform: handle(url:))
    }

    private func handle(url: URL) {
        guard let link = DeepLink.parse(url) else { return }
        switch link {
        case .authCallback:
            break
        case .today(let date):
            model.pendingRoute = .today(date: date)
        case .day(let date):
            model.pendingRoute = .day(date)
        case .event(let id):
            model.pendingRoute = .event(id: id)
        case .object(let id):
            model.pendingRoute = .object(id: id)
        case .block(let id):
            model.pendingRoute = .block(id: id)
        case .metric(let identifier):
            model.pendingRoute = .metric(identifier: identifier)
        case .place(let id):
            model.pendingRoute = .place(id: id)
        case .integration(let service):
            model.pendingRoute = .integration(service: service)
        }
    }
}
