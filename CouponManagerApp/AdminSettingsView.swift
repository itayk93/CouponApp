//
//  AdminSettingsView.swift
//  CouponManagerApp
//
//  מסך הגדרות אדמין לניהול הגדרות התראות
//

import SwiftUI

struct AdminSettingsView: View {
    let user: User
    let onBack: () -> Void
    
    @StateObject private var globalSettings = GlobalNotificationSettings.shared
    @State private var testMessage: String = ""
    @State private var showingAlert = false
    
    private let primaryBlue = Color.blue
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    notificationTimingSection
                    
                    testSection
                    
                    currentSettingsSection
                    
                    pendingNotificationsSection
                }
                .padding()
            }
            .navigationTitle("הגדרות אדמין")
            .navigationBarTitleDisplayMode(.large)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("חזור") {
                        onBack()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "gear.badge")
                .font(.system(size: 50))
                .foregroundColor(primaryBlue)
            
            Text("הגדרות מנהל")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("הגדרות אלו משפיעות על כל המשתמשים במערכת")
                .font(.subheadline)
                .foregroundColor(.red)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("כל ההתראות במערכת יישלחו בזמנים שתגדיר כאן")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var notificationTimingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("⏰ הגדרות זמני התראות")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Daily notifications (for coupons expiring in 1-7 days)
            VStack(alignment: .leading, spacing: 8) {
                Text("התראות יומיות (קופונים שפגים בשבוע הקרוב)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("שעה:")
                    Picker("שעה", selection: $globalSettings.dailyNotificationHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 60, height: 100)
                    
                    Text("דקה:")
                    Picker("דקה", selection: $globalSettings.dailyNotificationMinute) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 60, height: 100)
                }
                
                Text("זמן נוכחי: \(globalSettings.dailyTimeString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 2)
            
            // Monthly notifications
            VStack(alignment: .leading, spacing: 8) {
                Text("התראות חודשיות (30 ימים לפני תפוגה)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("שעה:")
                    Picker("שעה", selection: $globalSettings.monthlyNotificationHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 60, height: 100)
                    
                    Text("דקה:")
                    Picker("דקה", selection: $globalSettings.monthlyNotificationMinute) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 60, height: 100)
                }
                
                Text("זמן נוכחי: \(globalSettings.monthlyTimeString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 2)
            
            // Expiration day notifications
            VStack(alignment: .leading, spacing: 8) {
                Text("התראות יום תפוגה")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("שעה:")
                    Picker("שעה", selection: $globalSettings.expirationDayHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 60, height: 100)
                    
                    Text("דקה:")
                    Picker("דקה", selection: $globalSettings.expirationDayMinute) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 60, height: 100)
                }
                
                Text("זמן נוכחי: \(globalSettings.expirationTimeString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 2)
            
            Button("💾 שמור הגדרות") {
                saveSettings()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(primaryBlue)
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var testSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🧪 בדיקות התראות")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Button("שלח התראת בדיקה עכשיו") {
                    NotificationManager.shared.scheduleTestNotification()
                    testMessage = "התראת בדיקה נשלחה! תגיע תוך 5 שניות"
                    showingAlert = true
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(10)
                
                
                Button("מחק את כל ההתראות") {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    testMessage = "כל ההתראות הממתינות נמחקו"
                    showingAlert = true
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("הודעה", isPresented: $showingAlert) {
            Button("אישור") { }
        } message: {
            Text(testMessage)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private var currentSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 הגדרות נוכחיות")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("התראות יומיות:")
                    Spacer()
                    Text(globalSettings.dailyTimeString)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryBlue)
                }
                
                HStack {
                    Text("התראות חודשיות:")
                    Spacer()
                    Text(globalSettings.monthlyTimeString)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryBlue)
                }
                
                HStack {
                    Text("התראות יום תפוגה:")
                    Spacer()
                    Text(globalSettings.expirationTimeString)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryBlue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var pendingNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📋 מידע נוסף")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("🌍 השפעה גלובלית:")
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                Text("• הגדרות אלו משפיעות על כל המשתמשים במערכת")
                Text("• כל ההתראות החדשות יישלחו בזמנים שתגדיר")
                Text("• התראות קיימות יישארו בזמנים הישנים עד לעדכון הבא")
                Text("• השינויים נשמרים מקומית ויעברו לכל המכשירים בעדכון הבא")
                Text("• אחראי לוודא שהזמנים מתאימים לכל המשתמשים!")
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func saveSettings() {
        globalSettings.saveSettings()
        testMessage = "ההגדרות הגלובליות נשמרו בהצלחה! ✅\nכל המשתמשים במערכת יקבלו התראות בזמנים החדשים"
        showingAlert = true
    }
    
    
}


#Preview {
    AdminSettingsView(user: User(
        id: 1,
        email: "admin@test.com",
        password: nil,
        firstName: "אדמין",
        lastName: "טסט",
        age: 30,
        gender: "male",
        region: nil,
        isConfirmed: true,
        isAdmin: true,
        slots: 5,
        slotsAutomaticCoupons: 50,
        createdAt: nil,
        profileDescription: nil,
        profileImage: nil,
        couponsSoldCount: 0,
        isDeleted: false,
        dismissedExpiringAlertAt: nil,
        dismissedMessageId: nil,
        googleId: nil,
        newsletterSubscription: true,
        telegramMonthlySummary: true,
        newsletterImage: nil,
        showWhatsappBanner: false,
        faceIdEnabled: false,
        pushToken: nil
    )) {
        print("Back pressed")
    }
}