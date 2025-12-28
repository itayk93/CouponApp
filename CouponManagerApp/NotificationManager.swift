//
//  NotificationManager.swift
//  CouponManagerApp
//
//  מנהל התראות עבור קופונים שעומדים לפוג תוקף
//

import Foundation
import UserNotifications
import SwiftUI
import Combine

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private let center = UNUserNotificationCenter.current()
    private let globalSettings = GlobalNotificationSettings.shared
    
    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ??
        "CouponManagerApp"
    }
    
    private func makeNotificationContent(body: String, userInfo: [AnyHashable: Any]) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = appDisplayName
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        return content
    }
    
    override init() {
        super.init()
        center.delegate = self
        checkAuthorizationStatus()
        
        // Listen for global settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGlobalSettingsChange),
            name: .globalNotificationSettingsChanged,
            object: nil
        )
    }
    
    @objc private func handleGlobalSettingsChange() { }
    
    private func checkAuthorizationStatus() {
        center.getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            await MainActor.run {
                authorizationStatus = granted ? .authorized : .denied
            }
            
            return granted
        } catch {
            print("❌ Error requesting notification authorization: \(error)")
            await MainActor.run {
                authorizationStatus = .denied
            }
            return false
        }
    }
    
    func scheduleExpirationNotifications(for coupons: [Coupon]) {
        clearCouponNotifications { [weak self] in
            self?.performScheduling(for: coupons)
        }
    }
    
    private func clearCouponNotifications(completion: @escaping () -> Void) {
        center.getPendingNotificationRequests { [weak self] requests in
            let ids = requests
                .map(\.identifier)
                .filter { id in
                    id.hasPrefix("daily-") ||
                    id.hasPrefix("specific-day-") ||
                    id.hasPrefix("expiration-") ||
                    id.hasPrefix("monthly-")
                }
            
            if !ids.isEmpty {
                self?.center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            
            completion()
        }
    }
    
    private func performScheduling(for coupons: [Coupon]) {
        let calendar = Calendar.current
        let now = Date()
        
        for coupon in coupons {
            guard let expirationDate = coupon.expirationDate,
                  expirationDate > now,
                  !coupon.isExpired,
                  !coupon.isFullyUsed,
                  coupon.status == "פעיל" else { 
                //print("⏭️ Skipping coupon \(coupon.id) (\(coupon.company)) - expired or fully used")
                continue 
            }
            
            let daysUntilExpiration = calendar.dateComponents([.day], from: now, to: expirationDate).day ?? 0
            
            // Schedule monthly notification (30 days before)
            if daysUntilExpiration == 30 {
                print("🗓️ Scheduling monthly notification for coupon \(coupon.id)")
                scheduleMonthlyNotification(for: coupon, expirationDate: expirationDate)
            }
            
            // Schedule daily notifications for the last week (7 days before) - EVERY DAY
            if daysUntilExpiration <= 7 && daysUntilExpiration >= 1 {
                print("⏰ Scheduling daily notifications for coupon \(coupon.id) for all remaining days (\(daysUntilExpiration) days left)")
                // Schedule notifications for each remaining day
                for dayNumber in 1...daysUntilExpiration {
                    scheduleSpecificDayNotification(for: coupon, daysLeft: dayNumber, expirationDate: expirationDate)
                }
            }
            
            // Schedule expiration day notification
            if daysUntilExpiration == 0 {
                print("🚨 Scheduling expiration day notification for coupon \(coupon.id)")
                scheduleExpirationDayNotification(for: coupon, expirationDate: expirationDate)
            }
        }
        
        
    }
    
    private func scheduleMonthlyNotification(for coupon: Coupon, expirationDate: Date) {
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "he_IL")
        monthFormatter.dateFormat = "MMMM"
        let monthName = monthFormatter.string(from: expirationDate)
        
        let content = makeNotificationContent(
            body: "הקופון של \(coupon.company) יפוג תוקף ב\(monthName). כדאי לנצל אותו עד \(coupon.formattedExpirationDate)",
            userInfo: ["couponId": coupon.id, "type": "monthly"]
        )
        
        // Get global settings for monthly notification time
        let monthlyHour = globalSettings.monthlyNotificationHour
        let monthlyMinute = globalSettings.monthlyNotificationMinute
        
        // Schedule for next notification time
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = monthlyHour
        components.minute = monthlyMinute
        
        if let scheduledDate = Calendar.current.date(from: components),
           scheduledDate < Date() {
            // If the time today has passed, schedule for tomorrow
            components.day! += 1
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "monthly-\(coupon.id)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling monthly notification: \(error)")
            } else {
                print("✅ Scheduled monthly notification for coupon \(coupon.id) at \(String(format: "%02d:%02d", monthlyHour, monthlyMinute))")
            }
        }
    }
    
    private func scheduleDailyNotifications(for coupon: Coupon, daysLeft: Int, expirationDate: Date) {
        let daysText: String
        switch daysLeft {
        case 1:
            daysText = "מחר"
        case 2:
            daysText = "נשארו יומיים"
        case 3:
            daysText = "נשארו 3 ימים"
        default:
            daysText = "נשארו \(daysLeft) ימים"
        }
        
        let content = makeNotificationContent(
            body: "הקופון של \(coupon.company) יפוג תוקף \(daysText). לחץ כדי לצפות בפרטים",
            userInfo: ["couponId": coupon.id, "type": "daily"]
        )
        
        // Schedule for 10 AM the next morning - EVERY morning leading up to expiration
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate the notification date: tomorrow morning at 10 AM
        var notificationComponents = calendar.dateComponents([.year, .month, .day], from: now)
        notificationComponents.day! += 1
        notificationComponents.hour = 10
        notificationComponents.minute = 0
        
        // Ensure we don't schedule past the expiration date
        if let notificationDate = calendar.date(from: notificationComponents),
           notificationDate <= expirationDate {
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: notificationComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: "daily-\(coupon.id)-\(daysLeft)",
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("❌ Error scheduling daily notification: \(error)")
                } else {
                    print("✅ Successfully scheduled daily notification for coupon \(coupon.id) (\(daysLeft) days left) for \(notificationDate)")
                }
            }
        } else {
            print("⚠️ Skipping notification for coupon \(coupon.id) - would be scheduled after expiration")
        }
    }
    
    private func scheduleSpecificDayNotification(for coupon: Coupon, daysLeft: Int, expirationDate: Date) {
        let daysText: String
        switch daysLeft {
        case 1:
            daysText = "מחר"
        case 2:
            daysText = "נשארו יומיים"
        case 3:
            daysText = "נשארו 3 ימים"
        default:
            daysText = "נשארו \(daysLeft) ימים"
        }
        
        let content = makeNotificationContent(
            body: "הקופון של \(coupon.company) יפוג תוקף \(daysText). לחץ כדי לצפות בפרטים",
            userInfo: ["couponId": coupon.id, "type": "specific_day"]
        )
        
        // Get global settings for notification time
        let notificationHour = globalSettings.dailyNotificationHour
        let notificationMinute = globalSettings.dailyNotificationMinute
        
        // Calculate notification date based on days left
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysLeft, to: expirationDate) ?? Date()
        
        var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        components.hour = notificationHour
        components.minute = notificationMinute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "specific-day-\(coupon.id)-\(daysLeft)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling specific day notification for coupon \(coupon.id): \(error)")
            } else {
                print("✅ Scheduled specific day notification for coupon \(coupon.id) (\(daysLeft) days left) for \(String(format: "%02d:%02d", notificationHour, notificationMinute))")
            }
        }
    }
    
    private func scheduleExpirationDayNotification(for coupon: Coupon, expirationDate: Date) {
        let content = makeNotificationContent(
            body: "הקופון של \(coupon.company) פג תוקף היום! לחץ כדי לצפות בפרטים",
            userInfo: ["couponId": coupon.id, "type": "expiration"]
        )
        
        // Get global settings for expiration day notification time
        let expirationHour = globalSettings.expirationDayHour
        let expirationMinute = globalSettings.expirationDayMinute
        
        // Schedule for configured time on the expiration date
        var components = Calendar.current.dateComponents([.year, .month, .day], from: expirationDate)
        components.hour = expirationHour
        components.minute = expirationMinute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "expiration-\(coupon.id)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling expiration notification: \(error)")
            } else {
                print("✅ Successfully scheduled expiration day notification for coupon \(coupon.id) at \(String(format: "%02d:%02d", expirationHour, expirationMinute))")
            }
        }
    }
    
    func updateNotifications(for coupons: [Coupon]) {
        guard authorizationStatus == .authorized else { 
            print("❌ Cannot update notifications - authorization status: \(authorizationStatus)")
            return 
        }
        scheduleExpirationNotifications(for: coupons)
    }
    
    // Add test notification functionality
    func scheduleTestNotification() {
        guard authorizationStatus == .authorized else { 
            print("❌ Cannot send test notification - not authorized")
            return 
        }
        
        let content = makeNotificationContent(
            body: "מערכת ההתראות פועלת כראוי! זה בדיקה לוודא שהכל עובד",
            userInfo: ["type": "test"]
        )
        
        // Schedule for 5 seconds from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-notification-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling test notification: \(error)")
            } else {
                print("✅ Test notification scheduled - should appear in 5 seconds")
            }
        }
    }
    
    // Check pending notifications
    func debugPendingNotifications() {
        center.getPendingNotificationRequests { requests in
            print("🔍 Currently scheduled notifications: \(requests.count)")
            for request in requests {
                print("   - ID: \(request.identifier)")
                print("   - Title: \(request.content.title)")
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    let nextDate = trigger.nextTriggerDate() ?? Date()
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    formatter.locale = Locale(identifier: "he_IL")
                    print("   - Scheduled for: \(formatter.string(from: nextDate))")
                } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    print("   - Scheduled in: \(trigger.timeInterval) seconds")
                }
                print("   ---")
            }
        }
    }
    
    
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String, type == "monthly_summary" {
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
            completionHandler()
            return
        }
        
        if let couponId = userInfo["couponId"] as? Int {
            // Navigate to coupon detail view
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToCouponDetail"),
                object: nil,
                userInfo: ["couponId": couponId]
            )
        }
        
        completionHandler()
    }
}
