import Foundation

enum AppLogger {
    // Toggle to enable verbose logging during development.
    static var isEnabled: Bool = false

    static func log(_ message: String) {
        guard isEnabled else { return }
        print(message)
    }
}

