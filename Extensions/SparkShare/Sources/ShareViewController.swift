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
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                // Cast to Sendable type before crossing actor boundary.
                let url: URL? = item as? URL
                Task { @MainActor [weak self] in
                    if let url { self?.shareURL(url) } else { self?.complete() }
                }
            }
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, _ in
                let fileURL: URL? = item as? URL
                // UIImage → convert to Data (Sendable) before crossing boundary.
                let imageData: Data? = (item as? UIImage)?.jpegData(compressionQuality: 0.8)
                Task { @MainActor [weak self] in
                    if let fileURL { self?.shareImage(at: fileURL) }
                    else if let imageData { self?.shareImageData(imageData) }
                    else { self?.complete() }
                }
            }
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                let text: String? = item as? String
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
        scheduleBackgroundImageUpload(fileURL: fileURL)
        showToast("Photo saved to Spark.")
        complete()
    }

    private func shareImageData(_ data: Data) {
        let dir = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.co.cronx.spark")?
            .appendingPathComponent("ShareUploads", isDirectory: true)
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("\(UUID().uuidString).jpg")
        if (try? data.write(to: dest)) != nil {
            scheduleBackgroundImageUpload(fileURL: dest)
        }
        showToast("Photo saved to Spark.")
        complete()
    }

    private func scheduleBackgroundImageUpload(fileURL: URL) {
        guard let token = syncAccessToken() else { return }
        let uploadURL = APIEnvironment.current().baseURL.appendingPathComponent("check-ins/media")
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let config = URLSessionConfiguration.background(withIdentifier: "co.cronx.spark.share.upload")
        config.sharedContainerIdentifier = "group.co.cronx.spark"
        URLSession(configuration: config).uploadTask(with: request, fromFile: fileURL).resume()
    }

    // MARK: - Text sharing (note)

    private func shareText(_ text: String) {
        Task {
            do {
                let client = APIClient(tokenStore: tokenStore, etagCache: ETagCache())
                let body = try? JSONEncoder().encode(["content": text, "type": "note"])
                let endpoint = Endpoint<EmptyShareResponse>(
                    method: .post, path: "/notes",
                    body: body, contentType: "application/json"
                )
                _ = try await client.request(endpoint)
                await MainActor.run { self.showToast("Note saved to Spark.") }
            } catch {
                await MainActor.run { self.showToast("Couldn't save note.") }
            }
            complete()
        }
    }

    // MARK: - Helpers

    private func syncAccessToken() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "co.cronx.spark.accessToken",
            kSecAttrAccessGroup: "$(AppIdentifierPrefix)co.cronx.spark",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

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
