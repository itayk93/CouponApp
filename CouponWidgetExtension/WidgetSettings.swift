import Foundation

final class WidgetSettings {
    static let shared = WidgetSettings()
    private init() {}

    private let appGroupIdentifier = "group.com.itaykarkason.CouponManagerApp"
    private let widgetRefreshIntervalKey = "WidgetRefreshIntervalMinutes"
    private let defaultRefreshIntervalMinutes = 10

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    var widgetRefreshIntervalMinutes: Int {
        guard let sharedDefaults = sharedDefaults else {
            return defaultRefreshIntervalMinutes
        }

        if let storedValue = sharedDefaults.object(forKey: widgetRefreshIntervalKey) as? Int {
            return max(1, storedValue)
        }

        return defaultRefreshIntervalMinutes
    }
}
