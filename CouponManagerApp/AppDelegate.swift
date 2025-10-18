
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

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
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
}
