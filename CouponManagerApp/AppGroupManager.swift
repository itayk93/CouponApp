import Foundation
import WidgetKit

class AppGroupManager {
    static let shared = AppGroupManager()
    
    private let appGroupIdentifier = "group.com.itaykarkason.CouponManagerApp"
    private let userDefaultsKey = "SharedCouponData"
    private let companiesKey = "SharedCompaniesData"
    
    private init() {}
    
    var sharedUserDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
    
    func saveCouponsToSharedContainer(_ coupons: [Coupon]) {
        guard let sharedDefaults = sharedUserDefaults else {
            print("❌ Failed to get shared user defaults")
            return
        }
        
        let widgetCoupons = coupons.map { coupon in
            AppGroupManager.WidgetCoupon(
                id: coupon.id,
                code: coupon.code,
                description: coupon.description,
                value: coupon.value,
                cost: coupon.cost,
                company: coupon.company,
                expiration: coupon.expiration,
                dateAdded: coupon.dateAdded,
                usedValue: coupon.usedValue,
                status: coupon.status,
                isOneTime: coupon.isOneTime,
                userId: coupon.userId,
                showInWidget: coupon.showInWidget
            )
        }
        
        if let data = try? JSONEncoder().encode(widgetCoupons) {
            sharedDefaults.set(data, forKey: userDefaultsKey)
            sharedDefaults.synchronize()
            print("✅ Saved \(widgetCoupons.count) coupons to shared container")
            
            // Verify the save
            if let savedData = sharedDefaults.data(forKey: userDefaultsKey),
               let savedCoupons = try? JSONDecoder().decode([WidgetCoupon].self, from: savedData) {
                print("✅ Verified: \(savedCoupons.count) coupons in shared container")
                let widgetCount = savedCoupons.filter { $0.showInWidget == true }.count
                print("✅ Widget coupons (showInWidget=true): \(widgetCount)")
            } else {
                print("❌ Failed to verify saved data")
            }
            
            // Trigger widget timeline refresh
            refreshWidgetTimelines()
        } else {
            print("❌ Failed to encode coupons")
        }
    }
    
    func saveCompaniesToSharedContainer(_ companies: [Company]) {
        guard let sharedDefaults = sharedUserDefaults else { return }
        
        let widgetCompanies = companies.map { company in
            AppGroupManager.WidgetCompany(
                id: company.id,
                name: company.name,
                imagePath: company.imagePath,
                companyCount: Int64(company.companyCount)
            )
        }
        
        if let data = try? JSONEncoder().encode(widgetCompanies) {
            sharedDefaults.set(data, forKey: companiesKey)
        }
    }
    
    func getCouponsFromSharedContainer() -> [AppGroupManager.WidgetCoupon] {
        guard let sharedDefaults = sharedUserDefaults,
              let data = sharedDefaults.data(forKey: userDefaultsKey),
              let coupons = try? JSONDecoder().decode([AppGroupManager.WidgetCoupon].self, from: data) else {
            return []
        }
        return coupons
    }
    
    func getCompaniesFromSharedContainer() -> [AppGroupManager.WidgetCompany] {
        guard let sharedDefaults = sharedUserDefaults,
              let data = sharedDefaults.data(forKey: companiesKey),
              let companies = try? JSONDecoder().decode([AppGroupManager.WidgetCompany].self, from: data) else {
            return []
        }
        return companies
    }
    
    func saveUserTokenToSharedContainer(_ token: String) {
        guard let sharedDefaults = sharedUserDefaults else { return }
        sharedDefaults.set(token, forKey: "userToken")
    }
    
    func getCurrentUserFromSharedContainer() -> User? {
        guard let sharedDefaults = sharedUserDefaults,
              let data = sharedDefaults.data(forKey: "lastLoggedInUser"),
              let simpleUser = try? JSONDecoder().decode(SimpleUser.self, from: data) else {
            return nil
        }
        
        return User(
            id: simpleUser.id,
            email: simpleUser.email,
            password: nil,
            firstName: simpleUser.username.components(separatedBy: " ").first,
            lastName: simpleUser.username.components(separatedBy: " ").count > 1 ? simpleUser.username.components(separatedBy: " ").dropFirst().joined(separator: " ") : nil,
            age: nil,
            gender: nil,
            region: nil,
            isConfirmed: true,
            isAdmin: false,
            slots: 0,
            slotsAutomaticCoupons: 0,
            createdAt: nil,
            profileDescription: nil,
            profileImage: nil,
            couponsSoldCount: 0,
            isDeleted: false,
            dismissedExpiringAlertAt: nil,
            dismissedMessageId: nil,
            googleId: nil,
            newsletterSubscription: false,
            telegramMonthlySummary: false,
            newsletterImage: nil,
            showWhatsappBanner: false,
            faceIdEnabled: nil
        )
    }
    
    func saveCurrentUserToSharedContainer(_ user: User) {
        print("🔐 APP: saveCurrentUserToSharedContainer called for user ID: \(user.id)")
        print("🔐 APP: App group identifier: \(appGroupIdentifier)")
        print("🔐 APP: User details: email=\(user.email), firstName=\(user.firstName ?? "nil"), lastName=\(user.lastName ?? "nil")")
        
        guard let sharedDefaults = sharedUserDefaults else {
            print("❌ APP: Failed to get shared user defaults for user save")
            print("❌ APP: This could be due to missing app group entitlements or incorrect group identifier")
            return
        }
        
        print("🔐 APP: SharedUserDefaults acquired successfully")
        print("🔐 APP: Suite name: \(appGroupIdentifier)")
        
        // Create username from firstName + lastName or fallback to email
        let username = [user.firstName, user.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
            .isEmpty ? user.email : [user.firstName, user.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        let simpleUser = AppGroupManager.SimpleUser(
            id: user.id,
            username: username,
            email: user.email
        )
        
        print("🔐 APP: Created SimpleUser: id=\(simpleUser.id), username='\(simpleUser.username)', email='\(simpleUser.email)'")
        
        do {
            let data = try JSONEncoder().encode(simpleUser)
            print("🔐 APP: Successfully encoded user data (\(data.count) bytes)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔐 APP: User JSON data: \(jsonString)")
            }
            
            // Try to save
            print("🔐 APP: Attempting to save to shared container with key 'lastLoggedInUser'...")
            sharedDefaults.set(data, forKey: "lastLoggedInUser")
            
            // Force synchronize
            print("🔐 APP: Synchronizing shared container...")
            let syncResult = sharedDefaults.synchronize()
            print("🔐 APP: Synchronize result: \(syncResult)")
            
            print("✅ APP: Saved user to shared container: \(simpleUser.username) (ID: \(simpleUser.id))")
            
            // Wait a moment and verify the save
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔐 APP: Verifying save after delay...")
                if let savedData = sharedDefaults.data(forKey: "lastLoggedInUser") {
                    print("✅ APP: Found saved data (\(savedData.count) bytes)")
                    if let savedUser = try? JSONDecoder().decode(SimpleUser.self, from: savedData) {
                        print("✅ APP: Verified user save: \(savedUser.username) (ID: \(savedUser.id))")
                    } else {
                        print("❌ APP: Found data but failed to decode")
                    }
                } else {
                    print("❌ APP: No data found after save - this indicates a problem!")
                }
                
                // Show all keys in container for debugging
                let allKeys = sharedDefaults.dictionaryRepresentation().keys.sorted()
                print("🔐 APP: All keys in shared container after save (\(allKeys.count) total): \(allKeys)")
                
                // Also show some values for debugging
                for key in allKeys {
                    let value = sharedDefaults.object(forKey: key)
                    if key == "lastLoggedInUser" {
                        if let data = value as? Data {
                            print("   📍 \(key): Data(\(data.count) bytes)")
                        } else {
                            print("   📍 \(key): \(value ?? "nil") (type: \(type(of: value)))")
                        }
                    } else {
                        print("   📋 \(key): \(type(of: value))")
                    }
                }
            }
            
            // Force refresh widget timelines after saving user
            print("🔄 APP: Triggering widget refresh after user save...")
            refreshWidgetTimelines()
            
        } catch {
            print("❌ APP: Failed to encode user data: \(error)")
        }
    }
    
    // MARK: - Widget Management
    
    func refreshWidgetTimelines() {
        print("🔄 Refreshing widget timelines...")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// Models for widget data sharing
extension AppGroupManager {
    struct WidgetCoupon: Codable, Identifiable {
        let id: Int
        let code: String
        let description: String?
        let value: Double
        let cost: Double
        let company: String
        let expiration: String?
        let dateAdded: String
        let usedValue: Double
        let status: String
        let isOneTime: Bool
        let userId: Int
        let showInWidget: Bool?
        
        var remainingValue: Double {
            return value - usedValue
        }
        
        var isExpired: Bool {
            guard let expirationString = expiration,
                  let expirationDate = ISO8601DateFormatter().date(from: expirationString + "T00:00:00Z") else {
                return false
            }
            return expirationDate < Date()
        }
        
        var isFullyUsed: Bool {
            return usedValue >= value
        }
        
        var expirationDate: Date? {
            guard let expirationString = expiration else { return nil }
            return ISO8601DateFormatter().date(from: expirationString + "T00:00:00Z")
        }
    }

    struct WidgetCompany: Codable, Identifiable {
        let id: Int
        let name: String
        let imagePath: String
        let companyCount: Int64
    }

    struct SimpleUser: Codable {
        let id: Int
        let username: String
        let email: String
    }
}