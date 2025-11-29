
import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Force right-to-left layout across UIKit components (affects system alerts as well)
        UIView.appearance().semanticContentAttribute = .forceRightToLeft
        UINavigationBar.appearance().semanticContentAttribute = .forceRightToLeft
        UITabBar.appearance().semanticContentAttribute = .forceRightToLeft
        UITableView.appearance().semanticContentAttribute = .forceRightToLeft
        UICollectionView.appearance().semanticContentAttribute = .forceRightToLeft

        // Ensure UIAlertController contents (title/message) are right aligned
        if #available(iOS 13.0, *) {
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).semanticContentAttribute = .forceRightToLeft
            UILabel.appearance(whenContainedInInstancesOf: [UIAlertController.self]).textAlignment = .right
            UITextView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).textAlignment = .right
        }
        
        if let remoteInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            _ = handleMonthlySummaryIfNeeded(userInfo: remoteInfo)
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("📱 Device Push Token: \(token)")
        
        // Send token to your server
        Task {
            await updateUserPushToken(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) { }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if handleMonthlySummaryIfNeeded(userInfo: userInfo) {
            completionHandler(.newData)
            return
        }
        completionHandler(.noData)
    }
    
    private func updateUserPushToken(_ token: String) async {
        guard let user = AppGroupManager.shared.getCurrentUserFromSharedContainer() else {
            print("⚠️ Cannot update push token: User not found in shared container.")
            return
        }
        
        let userId = user.id
        let apiClient = APIClient() // Create an instance of APIClient
        
        do {
            try await apiClient.updateUserPushToken(userId: userId, token: token)
            print("✅ Successfully updated push token on server for user \(userId).")
        } catch {
            print("❌ Error updating push token on server for user \(userId): \(error)")
        }
    }
    
    @discardableResult
    private func handleMonthlySummaryIfNeeded(userInfo: [AnyHashable: Any]) -> Bool {
        guard let type = userInfo["type"] as? String, type == "monthly_summary" else {
            return false
        }
        
        let summaryId = userInfo["summary_id"] as? String ?? userInfo["summaryId"] as? String
        let monthValue = (userInfo["month"] as? Int) ?? Int((userInfo["month"] as? String) ?? "")
        let yearValue = (userInfo["year"] as? Int) ?? Int((userInfo["year"] as? String) ?? "")
        let style = userInfo["style"] as? String
        
        let trigger = MonthlySummaryTrigger(
            summaryId: summaryId,
            month: monthValue ?? Calendar.current.component(.month, from: Date()),
            year: yearValue ?? Calendar.current.component(.year, from: Date()),
            style: style
        )
        MonthlySummaryCache.shared.savePending(trigger: trigger)
        
        NotificationCenter.default.post(
            name: .navigateToMonthlySummary,
            object: nil,
            userInfo: [
                "summaryId": trigger.summaryId as Any,
                "month": trigger.month,
                "year": trigger.year,
                "style": trigger.style as Any
            ]
        )
        return true
    }
}
