import SparkKit
import SparkUI
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var model = model
        Group {
            switch model.session {
            case .unknown:
                ProgressView()
            case .loggedOut:
                OnboardingFlow(isComplete: $model.onboardingComplete)
            case .loggedIn:
                if model.onboardingComplete {
                    MainTabView()
                } else {
                    OnboardingFlow(isComplete: $model.onboardingComplete)
                }
            }
        }
        .task { await model.bootstrap() }
        .alert(
            "Timezone Change",
            isPresented: Binding(
                get: { model.timezonePrompt != nil },
                set: { if !$0 { model.timezonePrompt = nil } }
            ),
            presenting: model.timezonePrompt
        ) { prompt in
            Button("Use New Timezone") {
                Task { await model.acceptTimezoneChange(prompt) }
            }
            .tint(dialogActionTint)
            Button("Keep \(prompt.acknowledgedTimezone)", role: .cancel) {
                model.rejectTimezoneChange(prompt)
            }
            .tint(dialogActionTint)
        } message: { prompt in
            Text(
                "Your device is now using \(prompt.deviceTimezone). "
                    + "Should Spark use this timezone?"
            )
        }
        .alert(
            "Couldn't Update Timezone",
            isPresented: Binding(
                get: { model.timezoneUpdateError != nil },
                set: { if !$0 { model.timezoneUpdateError = nil } }
            ),
            presenting: model.timezoneUpdateError
        ) { failure in
            Button("Try Again") {
                Task { await model.acceptTimezoneChange(failure.prompt) }
            }
            .tint(dialogActionTint)
            Button("Cancel", role: .cancel) {
                model.timezoneUpdateError = nil
            }
            .tint(dialogActionTint)
        } message: { failure in
            Text("\(failure.message)\n\nSpark is still using \(failure.prompt.acknowledgedTimezone).")
        }
        .onOpenURL(perform: handle(url:))
        .environment(\.openURL, OpenURLAction { url in
            // In-app deep links embedded in rendered prose (e.g. Flint digest
            // markdown). Anything not a navigable Spark route falls through to
            // the system (real external links still open in Safari).
            guard let link = DeepLink.parse(url), link.detailRoute != nil else {
                return .systemAction
            }
            handle(url: url)
            return .handled
        })
    }

    private var dialogActionTint: Color {
        colorScheme == .dark ? .spark200 : .spark700
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
        case .tag(let name):
            model.pendingRoute = .tag(name: name, type: nil)
        }
    }
}
