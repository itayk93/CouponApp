import Foundation
import UIKit

/// Manages temporary image files exchanged with extensions via the app group container.
enum SharedImageInbox {
    private static let appGroupIdentifier = "group.com.itaykarkason.CouponManagerApp"
    private static let inboxFolderName = "ShareInbox"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private static func inboxURL() -> URL? {
        guard let base = containerURL else { return nil }
        let url = base.appendingPathComponent(inboxFolderName, isDirectory: true)
        // Ensure the folder exists
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func loadImage(named fileName: String) -> UIImage? {
        guard let dir = inboxURL() else { return nil }
        let fileURL = dir.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    static func removeImage(named fileName: String) {
        guard let dir = inboxURL() else { return }
        let fileURL = dir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}

