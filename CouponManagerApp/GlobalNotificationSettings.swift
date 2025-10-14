//
//  GlobalNotificationSettings.swift
//  CouponManagerApp
//
//  ניהול הגדרות התראות גלובליות לכל המערכת
//

import Foundation
import Combine

class GlobalNotificationSettings: ObservableObject {
    static let shared = GlobalNotificationSettings()
    
    private init() {
        loadSettings()
    }
    
    // Default times
    @Published var dailyNotificationHour: Int = 20
    @Published var dailyNotificationMinute: Int = 14
    @Published var monthlyNotificationHour: Int = 10
    @Published var monthlyNotificationMinute: Int = 0
    @Published var expirationDayHour: Int = 10
    @Published var expirationDayMinute: Int = 0
    
    // Keys for UserDefaults
    private let dailyHourKey = "global_daily_notification_hour"
    private let dailyMinuteKey = "global_daily_notification_minute"
    private let monthlyHourKey = "global_monthly_notification_hour"
    private let monthlyMinuteKey = "global_monthly_notification_minute"
    private let expirationHourKey = "global_expiration_day_hour"
    private let expirationMinuteKey = "global_expiration_day_minute"
    
    func saveSettings() {
        // Save locally first (for immediate UI update)
        UserDefaults.standard.set(dailyNotificationHour, forKey: dailyHourKey)
        UserDefaults.standard.set(dailyNotificationMinute, forKey: dailyMinuteKey)
        UserDefaults.standard.set(monthlyNotificationHour, forKey: monthlyHourKey)
        UserDefaults.standard.set(monthlyNotificationMinute, forKey: monthlyMinuteKey)
        UserDefaults.standard.set(expirationDayHour, forKey: expirationHourKey)
        UserDefaults.standard.set(expirationDayMinute, forKey: expirationMinuteKey)
        
        print("🌍 Global notification settings saved locally:")
        print("   Daily: \(String(format: "%02d:%02d", dailyNotificationHour, dailyNotificationMinute))")
        print("   Monthly: \(String(format: "%02d:%02d", monthlyNotificationHour, monthlyNotificationMinute))")
        print("   Expiration: \(String(format: "%02d:%02d", expirationDayHour, expirationDayMinute))")
        
        // Save to database for server-side cron job
        saveSettingsToDatabase()
        
        // Notify all notification managers to update their schedules
        NotificationCenter.default.post(name: .globalNotificationSettingsChanged, object: nil)
    }
    
    private func saveSettingsToDatabase() {
        Task {
            do {
                let supabaseUrl = URL(string: Secrets.notificationsSupabaseURL)!
                let supabaseKey = Secrets.notificationsSupabaseAnonKey
                
                var request = URLRequest(url: supabaseUrl.appendingPathComponent("rest/v1/notification_settings"))
                request.httpMethod = "POST"
                request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
                
                let settings = [
                    "daily_notification_hour": dailyNotificationHour,
                    "daily_notification_minute": dailyNotificationMinute,
                    "monthly_notification_hour": monthlyNotificationHour,
                    "monthly_notification_minute": monthlyNotificationMinute,
                    "expiration_day_hour": expirationDayHour,
                    "expiration_day_minute": expirationDayMinute
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: settings)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                        print("✅ Settings saved to database successfully")
                    } else {
                        print("⚠️ Settings save returned status: \(httpResponse.statusCode)")
                        // Try updating instead of inserting
                        await updateSettingsInDatabase()
                    }
                }
                
            } catch {
                print("❌ Error saving settings to database: \(error)")
            }
        }
    }
    
    private func updateSettingsInDatabase() async {
        do {
            let supabaseUrl = URL(string: Secrets.notificationsSupabaseURL)!
            let supabaseKey = Secrets.notificationsSupabaseAnonKey
            
            var request = URLRequest(url: supabaseUrl.appendingPathComponent("rest/v1/notification_settings?id=eq.1"))
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let settings = [
                "daily_notification_hour": dailyNotificationHour,
                "daily_notification_minute": dailyNotificationMinute,
                "monthly_notification_hour": monthlyNotificationHour,
                "monthly_notification_minute": monthlyNotificationMinute,
                "expiration_day_hour": expirationDayHour,
                "expiration_day_minute": expirationDayMinute
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: settings)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 || httpResponse.statusCode == 200 {
                    print("✅ Settings updated in database successfully")
                } else {
                    print("❌ Failed to update settings in database: \(httpResponse.statusCode)")
                }
            }
            
        } catch {
            print("❌ Error updating settings in database: \(error)")
        }
    }
    
    private func loadSettings() {
        dailyNotificationHour = UserDefaults.standard.object(forKey: dailyHourKey) as? Int ?? 20
        dailyNotificationMinute = UserDefaults.standard.object(forKey: dailyMinuteKey) as? Int ?? 14
        monthlyNotificationHour = UserDefaults.standard.object(forKey: monthlyHourKey) as? Int ?? 10
        monthlyNotificationMinute = UserDefaults.standard.object(forKey: monthlyMinuteKey) as? Int ?? 0
        expirationDayHour = UserDefaults.standard.object(forKey: expirationHourKey) as? Int ?? 10
        expirationDayMinute = UserDefaults.standard.object(forKey: expirationMinuteKey) as? Int ?? 0
        
        print("🌍 Global notification settings loaded:")
        print("   Daily: \(String(format: "%02d:%02d", dailyNotificationHour, dailyNotificationMinute))")
        print("   Monthly: \(String(format: "%02d:%02d", monthlyNotificationHour, monthlyNotificationMinute))")
        print("   Expiration: \(String(format: "%02d:%02d", expirationDayHour, expirationDayMinute))")
    }
    
    // Get formatted time strings
    var dailyTimeString: String {
        String(format: "%02d:%02d", dailyNotificationHour, dailyNotificationMinute)
    }
    
    var monthlyTimeString: String {
        String(format: "%02d:%02d", monthlyNotificationHour, monthlyNotificationMinute)
    }
    
    var expirationTimeString: String {
        String(format: "%02d:%02d", expirationDayHour, expirationDayMinute)
    }
}

// Notification name for settings changes
extension Notification.Name {
    static let globalNotificationSettingsChanged = Notification.Name("globalNotificationSettingsChanged")
}