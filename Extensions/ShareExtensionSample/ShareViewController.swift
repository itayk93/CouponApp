import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

/// Minimal share extension controller that forwards a single image to the main app.
final class ShareViewController: UIViewController {
    private let appGroup = "group.com.itaykarkason.CouponManagerApp"
    private let inboxFolderName = "ShareInbox"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleShare()
    }

    private func handleShare() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            complete()
            return
        }

        // Find first image provider
        let provider = extensionItems
            .compactMap { $0.attachments }
            .flatMap { $0 }
            .first { item in
                if #available(iOS 14.0, *) {
                    return item.hasItemConformingToTypeIdentifier(UTType.image.identifier)
                } else {
                    return item.hasItemConformingToTypeIdentifier(kUTTypeImage as String)
                }
            }

        guard let itemProvider = provider else {
            complete()
            return
        }

        // Load the image data
        let typeId: String
        if #available(iOS 14.0, *) {
            typeId = UTType.image.identifier
        } else {
            typeId = kUTTypeImage as String
        }

        itemProvider.loadItem(forTypeIdentifier: typeId, options: nil) { [weak self] item, _ in
            guard let self = self else { return }

            // Convert to Data
            let imageData: Data?
            if let url = item as? URL {
                imageData = try? Data(contentsOf: url)
            } else if let image = item as? UIImage {
                imageData = image.jpegData(compressionQuality: 0.9)
            } else {
                imageData = nil
            }

            guard let data = imageData,
                  let fileName = self.saveToAppGroup(data: data) else {
                self.complete()
                return
            }

            // Open container app to the import screen
            if let url = URL(string: "couponmanager://import-image?file=\(fileName)") {
                self.extensionContext?.open(url, completionHandler: { _ in
                    self.complete()
                })
            } else {
                self.complete()
            }
        }
    }

    private func saveToAppGroup(data: Data) -> String? {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return nil }
        let folder = base.appendingPathComponent(inboxFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "img_" + UUID().uuidString + ".jpg"
        let url = folder.appendingPathComponent(name)
        do {
            try data.write(to: url, options: [.atomic])
            return name
        } catch {
            return nil
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

