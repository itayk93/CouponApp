import Foundation

enum AppLogger {
    static var isEnabled: Bool = false
    static func log(_ message: String) {
        guard isEnabled else { return }
        print(message)
    }
}

