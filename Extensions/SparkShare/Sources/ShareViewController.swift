import SparkKit
import UniformTypeIdentifiers
import UIKit

/// Share extension — handles URL, image, and text items from the share sheet.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let tokenStore = KeychainTokenStore()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        handleSharedItems()
    }

    // MARK: - Item routing

    private func handleSharedItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            complete()
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                // Cast to Sendable type before crossing actor boundary.
                Task { @MainActor [weak self] in
                    if let url { self?.shareURL(url) } else { self?.complete() }
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
                        else { self?.complete() }
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
                        else { self?.complete() }
                    }
                }
            }
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            _ = provider.loadObject(ofClass: String.self) { [weak self] text, _ in
                Task { @MainActor [weak self] in
                    if let text { self?.shareText(text) } else { self?.complete() }
                }
            }
            return
        }

        complete()
    }

    // MARK: - URL sharing (bookmark)

    private func shareURL(_ url: URL) {
        Task {
            do {
                let client = APIClient(tokenStore: tokenStore, etagCache: ETagCache())
                let body = try? JSONEncoder().encode(["url": url.absoluteString])
                let endpoint = Endpoint<EmptyShareResponse>(
                    method: .post, path: "/bookmarks",
                    body: body, contentType: "application/json"
                )
                _ = try await client.request(endpoint)
                await MainActor.run { self.showToast("Bookmarked!") }
            } catch {
                await MainActor.run { self.showToast("Couldn't save bookmark.") }
            }
            complete()
        }
    }

    // MARK: - Image sharing

    private func shareImage(at fileURL: URL) {
        Task {
            let scheduled = await scheduleBackgroundImageUpload(fileURL: fileURL)
            if !scheduled {
                try? FileManager.default.removeItem(at: fileURL)
            }
            await MainActor.run {
                self.showToast(scheduled ? "Photo upload queued." : "Couldn't save photo.")
            }
            complete()
        }
    }

    private func shareImageData(_ data: Data) {
        let dir = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.co.cronx.sparkapp")?
            .appendingPathComponent("ShareUploads", isDirectory: true)
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("\(UUID().uuidString).jpg")

        guard (try? data.write(to: dest)) != nil else {
            showToast("Couldn't save photo.")
            complete()
            return
        }

        Task {
            let scheduled = await scheduleBackgroundImageUpload(fileURL: dest)
            if !scheduled {
                // Nothing will collect an orphaned file, so don't leave it in
                // the shared container pretending to be queued work.
                try? FileManager.default.removeItem(at: dest)
            }
            await MainActor.run {
                self.showToast(scheduled ? "Photo upload queued." : "Couldn't save photo.")
            }
            complete()
        }
    }

    /// Copies a provider-owned image into storage that survives its callback.
    private static func copySharedImage(from source: URL) -> URL? {
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
            showToast("Sharing text isn't supported yet.")
            complete()
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

    // MARK: - Helpers

    private func showToast(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            label.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

private struct EmptyShareResponse: Decodable, Sendable {}
