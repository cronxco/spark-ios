import SparkKit
import SparkUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Share extension — handles URL, image, and text items from the share sheet.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let tokenStore = KeychainTokenStore()
    private let status = ShareStatusModel()
    private var work: Task<Void, Never>?
    private var isFinished = false

    /// How long the success state stays up before the sheet dismisses itself.
    private static let successDwell: Duration = .milliseconds(1200)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Color.sparkSurface)
        embedStatusView()
        handleSharedItems()
    }

    private func embedStatusView() {
        status.onCancel = { [weak self] in self?.cancel() }
        status.onDone = { [weak self] in self?.complete() }

        let host = UIHostingController(rootView: ShareStatusView(model: status))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }

    // MARK: - Item routing

    private func handleSharedItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            fail("Nothing to share.")
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }

        if let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier)
        }) {
            _ = provider.loadDataRepresentation(for: .propertyList) { [weak self] data, _ in
                let page = data.flatMap(Self.preprocessedPage(from:))
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch page {
                    case .some(.captured(let page)):
                        self.shareCapturedPage(page)
                    case .some(.url(let url)):
                        self.shareURL(url)
                    case .none:
                        self.fail("Couldn't read this page.")
                    }
                }
            }
            return
        }

        handleFallbackProviders(providers)
    }

    private func handleFallbackProviders(_ providers: [NSItemProvider]) {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                // Cast to Sendable type before crossing actor boundary.
                Task { @MainActor [weak self] in
                    if let url { self?.shareURL(url) } else { self?.fail("Couldn't read this link.") }
                }
            }
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            if provider.canLoadObject(ofClass: UIImage.self as NSItemProviderReading.Type) {
                _ = provider.loadObject(ofClass: UIImage.self as NSItemProviderReading.Type) { [weak self] item, _ in
                    // UIImage → convert to Data (Sendable) before crossing boundary.
                    let imageData = (item as? UIImage)?.jpegData(compressionQuality: 0.8)
                    Task { @MainActor [weak self] in
                        if let imageData { self?.shareImageData(imageData) }
                        else { self?.fail("Couldn't read this photo.") }
                    }
                }
            } else {
                _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] fileURL, _ in
                    // The provider owns `fileURL` and may delete it as soon as
                    // this completion returns. Copy it while the lease is
                    // still valid, then only send our durable URL across the
                    // actor boundary.
                    let copiedURL = fileURL.flatMap { Self.copySharedImage(from: $0) }
                    Task { @MainActor [weak self] in
                        if let copiedURL { self?.shareImage(at: copiedURL) }
                        else { self?.fail("Couldn't read this photo.") }
                    }
                }
            }
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            _ = provider.loadObject(ofClass: String.self) { [weak self] text, _ in
                Task { @MainActor [weak self] in
                    if let text { self?.shareText(text) } else { self?.fail("Couldn't read this text.") }
                }
            }
            return
        }

        fail("Spark can't save this kind of item.")
    }

    // MARK: - URL sharing (bookmark)

    private func shareCapturedPage(_ page: CapturedWebPage) {
        status.phase = .working("Saving page to Spark…")
        work = Task {
            do {
                let client = APIClient(tokenStore: tokenStore, etagCache: ETagCache())
                let payload = CapturedWebPageRequest(
                    url: page.url.absoluteString,
                    title: page.title,
                    html: page.html
                )
                let endpoint = Endpoint<EmptyResponse>(
                    method: .post,
                    path: "/bookmarks/capture",
                    body: try JSONEncoder().encode(payload),
                    contentType: "application/json"
                )
                _ = try await client.request(endpoint)
                succeed("Page saved to Spark.")
            } catch {
                if !Task.isCancelled { fail(Self.failureMessage(for: error, saving: "this page")) }
            }
        }
    }

    private func shareURL(_ url: URL) {
        status.phase = .working("Saving bookmark…")
        work = Task {
            do {
                let client = APIClient(tokenStore: tokenStore, etagCache: ETagCache())
                let body = try? JSONEncoder().encode(["url": url.absoluteString])
                let endpoint = Endpoint<EmptyResponse>(
                    method: .post, path: "/bookmarks",
                    body: body, contentType: "application/json"
                )
                _ = try await client.request(endpoint)
                succeed("Bookmarked.")
            } catch {
                if !Task.isCancelled { fail(Self.failureMessage(for: error, saving: "this bookmark")) }
            }
        }
    }

    // MARK: - Image sharing

    private func shareImage(at fileURL: URL) {
        status.phase = .working("Sending photo to Spark…")
        work = Task {
            let scheduled = await scheduleBackgroundImageUpload(fileURL: fileURL)
            if !scheduled {
                try? FileManager.default.removeItem(at: fileURL)
            }
            finishPhotoUpload(scheduled: scheduled)
        }
    }

    private func shareImageData(_ data: Data) {
        let dir = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.co.cronx.sparkapp")?
            .appendingPathComponent("ShareUploads", isDirectory: true)
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("\(UUID().uuidString).jpg")

        status.phase = .working("Sending photo to Spark…")
        guard (try? data.write(to: dest)) != nil else {
            fail("Couldn't save this photo.")
            return
        }

        work = Task {
            let scheduled = await scheduleBackgroundImageUpload(fileURL: dest)
            if !scheduled {
                // Nothing will collect an orphaned file, so don't leave it in
                // the shared container pretending to be queued work.
                try? FileManager.default.removeItem(at: dest)
            }
            finishPhotoUpload(scheduled: scheduled)
        }
    }

    private func finishPhotoUpload(scheduled: Bool) {
        if scheduled {
            // The upload carries on in the background after the sheet closes.
            succeed("Photo is uploading to Spark.")
        } else {
            fail("Couldn't send this photo. Open Spark to sign in, then try again.")
        }
    }

    /// Copies a provider-owned image into storage that survives its callback.
    nonisolated private static func copySharedImage(from source: URL) -> URL? {
        let directory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.co.cronx.sparkapp")?
            .appendingPathComponent("ShareUploads", isDirectory: true)
            ?? FileManager.default.temporaryDirectory

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let pathExtension = source.pathExtension.isEmpty ? "jpg" : source.pathExtension
            let destination = directory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(pathExtension)
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    /// Hands the file to a background upload task.
    ///
    /// Returns whether the upload was actually scheduled. The caller must not
    /// claim success before this resolves: the previous implementation showed
    /// "Photo saved to Spark." and dismissed the sheet before this ran, and
    /// because the token read always failed it returned early every time — so
    /// the user was told the photo was saved while nothing had been queued.
    @discardableResult
    private func scheduleBackgroundImageUpload(fileURL: URL) async -> Bool {
        guard let token = await tokenStore.accessToken() else { return false }
        let uploadURL = APIEnvironment.current().baseURL.appendingPathComponent("check-ins/media")
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let config = URLSessionConfiguration.background(withIdentifier: "co.cronx.sparkapp.share.upload")
        config.sharedContainerIdentifier = "group.co.cronx.sparkapp"
        let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

        // The user may have tapped Cancel while the token read was pending.
        guard !Task.isCancelled else { return false }
        URLSession(configuration: config).uploadTask(with: request, fromFile: fileURL).resume()

        await APITelemetry.shared.capture(
            APITelemetryEvent(
                operation: "http.client.background_upload.schedule",
                method: request.httpMethod ?? "POST",
                url: APITelemetryRedactor.url(uploadURL),
                endpointPath: "/check-ins/media",
                requiresAuth: true,
                requestHeaders: APITelemetryRedactor.headers(request.allHTTPHeaderFields ?? [:]),
                responseSizeBytes: fileSize,
                durationMillis: 0,
                outcome: .success
            )
        )

        return true
    }

    // MARK: - Text sharing (note)

    /// Shared plain text.
    ///
    /// Text that is really a URL is captured as a bookmark. Anything else has
    /// no capture endpoint on the mobile surface — this used to POST to
    /// `/notes`, which does not exist and returned 404 every time — so it is
    /// declined honestly rather than silently dropped.
    private func shareText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = Self.firstURL(in: trimmed) else {
            fail("Sharing text isn't supported yet. Share a link or a photo instead.")
            return
        }

        shareURL(url)
    }

    /// The URL a shared string represents, if it is one.
    ///
    /// Share sheets routinely hand over a URL as plain text, so this recovers
    /// the common case rather than declining it.
    private static func firstURL(in text: String) -> URL? {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector.matches(in: text, range: range)

        // Only treat it as a link when the whole string is one, so a sentence
        // that happens to mention a URL is not silently turned into a bookmark.
        guard matches.count == 1,
              let match = matches.first,
              match.range == range,
              let url = match.url,
              url.scheme?.hasPrefix("http") == true
        else { return nil }

        return url
    }

    nonisolated private static func preprocessedPage(from data: Data) -> PreprocessedPage? {
        guard let item = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let payload = item as? [String: Any],
              let results = payload[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any],
              let urlString = results["url"] as? String,
              let url = URL(string: urlString),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else { return nil }

        guard results["captureError"] == nil,
              let html = results["html"] as? String,
              !html.isEmpty,
              html.utf8.count <= CapturedWebPage.maximumHTMLBytes
        else { return .url(url) }

        let title = (results["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        return .captured(
            CapturedWebPage(
                url: url,
                title: title?.isEmpty == false ? title : nil,
                html: html
            )
        )
    }

    // MARK: - Outcome

    /// Shows the success state briefly, then dismisses the sheet.
    private func succeed(_ message: String) {
        guard !isFinished else { return }
        status.phase = .succeeded(message)
        Task {
            try? await Task.sleep(for: Self.successDwell)
            complete()
        }
    }

    /// Shows the failure state and leaves it up until the user taps Done.
    private func fail(_ message: String) {
        guard !isFinished else { return }
        status.phase = .failed(message)
    }

    private static func failureMessage(for error: Error, saving thing: String) -> String {
        if case APIError.unauthorized = error {
            return "Couldn't save \(thing). Open Spark to sign in, then try again."
        }
        return "Couldn't save \(thing). Check your connection and try again."
    }

    private func cancel() {
        guard !isFinished else { return }
        isFinished = true
        work?.cancel()
        extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
    }

    private func complete() {
        guard !isFinished else { return }
        isFinished = true
        extensionContext?.completeRequest(returningItems: nil)
    }
}

private enum PreprocessedPage: Sendable {
    case captured(CapturedWebPage)
    case url(URL)
}

private struct CapturedWebPage: Sendable {
    static let maximumHTMLBytes = 5 * 1024 * 1024

    let url: URL
    let title: String?
    let html: String
}

private struct CapturedWebPageRequest: Encodable, Sendable {
    let url: String
    let title: String?
    let html: String
}
