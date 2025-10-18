import Foundation

class WidgetAPIClient {
    static let shared = WidgetAPIClient()
    
    private let appGroupIdentifier = "group.com.itaykarkason.CouponManagerApp"
    
    private init() {}
    
    // MARK: - Public Methods
    
    // NEW: Get statistics - active coupons count and total remaining value (like main app)
    func getCouponStatistics() async throws -> (activeCouponsCount: Int, totalValue: Double) {
        print("📊 getCouponStatistics called")
        
        guard let userId = getCurrentUserId() else {
            print("❌ No user ID found for statistics")
            throw APIError.notAuthenticated
        }
        
        // Fetch ALL coupons for user (not just active ones)
        let urlString = "\(SupabaseConfig.url)/rest/v1/coupon?user_id=eq.\(userId)&select=status,value,used_value,is_for_sale,exclude_saving,is_one_time"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        guard let coupons = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw APIError.invalidResponse
        }
        
        var activeCouponsCount = 0
        var totalRemainingValue = 0.0
        
        for couponData in coupons {
            let status = couponData["status"] as? String ?? ""
            let value = couponData["value"] as? Double ?? 0.0
            let usedValue = couponData["used_value"] as? Double ?? 0.0
            let isForSale = couponData["is_for_sale"] as? Bool ?? false
            let excludeSaving = couponData["exclude_saving"] as? Bool ?? false
            let isOneTime = couponData["is_one_time"] as? Bool ?? false
            
            // Count active coupons
            if status == "פעיל" {
                activeCouponsCount += 1
            }
            
            // Calculate total remaining value (same logic as main app - exclude one-time coupons)
            if !isForSale && !excludeSaving && !isOneTime {
                let remaining = max(value - usedValue, 0.0)
                totalRemainingValue += remaining
            }
        }
        
        print("📊 Statistics: \(activeCouponsCount) active coupons, ₪\(totalRemainingValue) total value")
        return (activeCouponsCount, totalRemainingValue)
    }
    
    // NEW: Get only coupons marked for widget display
    func getWidgetCoupons() async throws -> [WidgetCoupon] {
        print("🎯 getWidgetCoupons called")
        
        guard let userId = getCurrentUserId() else {
            print("❌ No user ID found for widget coupons")
            throw APIError.notAuthenticated
        }
        
        // Fetch only coupons with show_in_widget=true
        let selectCols = [
            "id","code","description","value","cost","company","expiration",
            "date_added","used_value","status","is_one_time","user_id","show_in_widget"
        ].joined(separator: ",")
        
        let urlString = "\(SupabaseConfig.url)/rest/v1/coupon?user_id=eq.\(userId)&show_in_widget=eq.true&select=\(selectCols)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let coupons = try decoder.decode([WidgetCoupon].self, from: data)
        
        print("🎯 Found \(coupons.count) coupons marked for widget display")
        for (index, coupon) in coupons.enumerated() {
            print("   [\(index + 1)] ID:\(coupon.id) | \(coupon.company) | showInWidget:\(coupon.showInWidget ?? false)")
        }
        
        return coupons
    }
    
    func getCoupons() async throws -> [WidgetCoupon] {
        print("🎯 WIDGET API: getCoupons called")
        
        // Try to get from shared container first
        print("🎯 WIDGET API: Checking shared container...")
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ WIDGET API: Failed to get UserDefaults for app group: \(appGroupIdentifier)")
            throw APIError.invalidResponse
        }
        
        print("🎯 WIDGET API: UserDefaults created successfully")
        
        guard let data = sharedDefaults.data(forKey: "SharedCouponData") else {
            print("❌ WIDGET API: No data found for key 'SharedCouponData'")
            print("🎯 WIDGET API: Available keys in shared container: \(sharedDefaults.dictionaryRepresentation().keys.sorted())")
            throw APIError.invalidResponse
        }
        
        
        // Try to decode as AppGroupManager.WidgetCoupon first (correct format)
        do {
            print("🎯 WIDGET API: Attempting to decode shared data...")
            
            // Define a temporary struct that matches AppGroupManager.WidgetCoupon
            struct SharedCoupon: Codable {
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
                let widgetDisplayOrder: Int?
                
                var remainingValue: Double {
                    return value - usedValue
                }
            }
            
            let sharedCoupons = try JSONDecoder().decode([SharedCoupon].self, from: data)
            
            // Convert to WidgetCoupon format
            let widgetCoupons = sharedCoupons.map { shared in
                WidgetCoupon(
                    id: shared.id,
                    code: shared.code,
                    description: shared.description,
                    value: shared.value,
                    cost: shared.cost,
                    company: shared.company,
                    expiration: shared.expiration,
                    dateAdded: shared.dateAdded,
                    usedValue: shared.usedValue,
                    status: shared.status,
                    isOneTime: shared.isOneTime,
                    userId: shared.userId,
                    showInWidget: shared.showInWidget,
                    widgetDisplayOrder: shared.widgetDisplayOrder
                )
            }
            
            print("📊 WIDGET API: Converted \(widgetCoupons.count) coupons to widget format")
            
            // Debug the first few coupons
            let activeCoupons = widgetCoupons.filter { $0.status == "פעיל" }
            let widgetEnabledCoupons = widgetCoupons.filter { $0.showInWidget == true }
            
            print("📊 WIDGET API: Analysis:")
            print("   - Total coupons: \(widgetCoupons.count)")
            print("   - Active coupons: \(activeCoupons.count)")
            print("   - Widget-enabled coupons: \(widgetEnabledCoupons.count)")
            
            for (index, coupon) in widgetEnabledCoupons.enumerated() {
                print("   🎯 Widget Coupon [\(index + 1)]: ID=\(coupon.id) | Company=\(coupon.company) | Status=\(coupon.status) | ShowInWidget=\(coupon.showInWidget ?? false)")
            }
            
            return widgetCoupons
            
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
            }
            throw error
        }
    }
    
    func getCompanies() async throws -> [WidgetCompany] {
        print("🎯 getCompanies called")
        
        // Try to get from shared container first
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let data = sharedDefaults.data(forKey: "SharedCompaniesData") {
            print("✅ Found companies data in shared container, attempting to decode...")
            
            do {
                // Define a temporary struct that matches AppGroupManager.WidgetCompany
                struct SharedCompany: Codable {
                    let id: Int
                    let name: String
                    let imagePath: String
                    let companyCount: Int64
                }
                
                let sharedCompanies = try JSONDecoder().decode([SharedCompany].self, from: data)
                print("✅ Successfully decoded \(sharedCompanies.count) companies from shared container")
                
                // Convert to WidgetCompany format
                let widgetCompanies = sharedCompanies.map { shared in
                    WidgetCompany(
                        id: shared.id,
                        name: shared.name,
                        imagePath: shared.imagePath,
                        companyCount: shared.companyCount
                    )
                }
                
                if !widgetCompanies.isEmpty {
                    return widgetCompanies
                } else {
                    print("⚠️ Shared container has 0 companies, falling back to network fetch...")
                }
            } catch {
                print("❌ Failed to decode companies from shared container: \(error)")
                print("⚠️ Falling back to network fetch...")
            }
        } else {
            print("⚠️ No companies data found in shared container")
        }
        
        print("⚠️ No companies in shared container, fetching from network...")
        // Fallback to network request if no shared data
        return try await fetchCompaniesFromNetwork()
    }
    
    // MARK: - Private Network Methods
    
    private func fetchCouponsFromNetwork() async throws -> [WidgetCoupon] {
        print("🔍 fetchCouponsFromNetwork started...")
        
        guard let userId = getCurrentUserId() else {
            print("❌ No user ID found - user not authenticated")
            throw APIError.notAuthenticated
        }
        
        print("✅ User ID found: \(userId)")
        
        // First try the RPC function, fallback to direct query if it doesn't exist
        do {
            print("📡 Attempting to fetch coupons via RPC...")
            let coupons = try await fetchCouponsViaRPC(userId: userId)
            print("✅ Successfully fetched \(coupons.count) coupons via RPC")
            
            if let firstCoupon = coupons.first {
                print("📝 Sample coupon: company=\(firstCoupon.company), value=\(firstCoupon.value), remaining=\(firstCoupon.remainingValue)")
            }
            
            return coupons
        } catch let rpcError {
            print("⚠️ RPC fetch failed with error: \(rpcError)")
            print("📡 Falling back to direct query...")
            
            do {
                let coupons = try await fetchCouponsDirect(userId: userId)
                print("✅ Successfully fetched \(coupons.count) coupons via direct query")
                
                if let firstCoupon = coupons.first {
                    print("📝 Sample coupon: company=\(firstCoupon.company), value=\(firstCoupon.value), remaining=\(firstCoupon.remainingValue)")
                }
                
                return coupons
            } catch let directError {
                print("❌ Direct query also failed with error: \(directError)")
                throw directError
            }
        }
    }

    private func fetchCouponsViaRPC(userId: Int) async throws -> [WidgetCoupon] {
        print("🔧 fetchCouponsViaRPC called for userId: \(userId)")
        
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/rpc/get_widget_coupons") else {
            print("❌ Invalid RPC URL")
            throw APIError.invalidURL
        }
        
        print("📍 RPC URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters = ["p_user_id": userId]
        request.httpBody = try JSONEncoder().encode(parameters)
        
        print("📍 RPC parameters: \(parameters)")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 RPC response status: \(httpResponse.statusCode)")
        }
        
        // 🔍 Print raw JSON response for debugging
        if let rawString = String(data: data, encoding: .utf8) {
            print("📄 Raw RPC response (first 500 chars): \(rawString.prefix(500))")
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ RPC request failed")
            if let rawString = String(data: data, encoding: .utf8) {
                print("📄 RPC error response: \(rawString)")
            }
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        // ✅ REMOVED: decoder.keyDecodingStrategy = .convertFromSnakeCase
        // We use explicit CodingKeys in WidgetCoupon instead
        decoder.dateDecodingStrategy = .iso8601
        
        let coupons = try decoder.decode([WidgetCoupon].self, from: data)
        
        print("✅ Successfully decoded \(coupons.count) coupons")
        for (index, coupon) in coupons.enumerated() {
            print("   [\(index + 1)] ID:\(coupon.id) | \(coupon.company) | showInWidget:\(coupon.showInWidget ?? false)")
        }
        
        return coupons
    }
    
    private func fetchCouponsDirect(userId: Int) async throws -> [WidgetCoupon] {
        print("🔧 fetchCouponsDirect started for userId: \(userId)")
        
        let encodedUserId = String(userId)
        
        // Fetch only ACTIVE coupons for widgets (as per user requirement)
        let selectCols = [
            "id","code","description","value","cost","company","expiration",
            "date_added","used_value","status","is_one_time","user_id","show_in_widget"
        ].joined(separator: ",")
        let urlString = "\(SupabaseConfig.url)/rest/v1/coupon?user_id=eq.\(encodedUserId)&status=eq.פעיל&select=\(selectCols)"
        
        print("📍 Request URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        print("📍 Request headers:")
        print("   - Authorization: Bearer \(SupabaseConfig.anonKey.prefix(20))...")
        print("   - apikey: \(SupabaseConfig.anonKey.prefix(20))...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Response status code: \(httpResponse.statusCode)")
            }
            
            print("📊 Response data size: \(data.count) bytes")
            if let rawString = String(data: data, encoding: .utf8) {
                print("📄 Raw response (first 2000 chars): \(rawString.prefix(2000))")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Response is not HTTPURLResponse")
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                print("❌ Invalid status code: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Server error message: \(errorString)")
                }
                throw APIError.invalidResponse
            }
            
            print("✅ Valid response received, attempting to decode...")
            
            let decoder = JSONDecoder()
            // ✅ REMOVED: decoder.keyDecodingStrategy = .convertFromSnakeCase
            // We use explicit CodingKeys in WidgetCoupon instead
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let coupons = try decoder.decode([WidgetCoupon].self, from: data)
                print("✅ Successfully decoded \(coupons.count) coupons")
                
                // הדפס פרטים על כל קופון
                for (index, coupon) in coupons.enumerated() {
                    print("   [\(index + 1)] ID:\(coupon.id) | \(coupon.company) | Value:₪\(coupon.value) | Remaining:₪\(coupon.remainingValue) | Status:\(coupon.status) | ShowInWidget:\(coupon.showInWidget ?? false)")
                }
                
                return coupons
            } catch {
                print("❌ JSON decoding failed: \(error)")
                print("❌ Decoding error details: \(error.localizedDescription)")
                
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                    print("📄 JSON structure: \(json)")
                }
                
                throw error
            }
        } catch {
            print("❌ Network request failed: \(error)")
            throw error
        }
    }

    private func fetchCompaniesFromNetwork() async throws -> [WidgetCompany] {
        print("🔧 fetchCompaniesFromNetwork started...")
        
        // Use the secure RPC function for companies
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/rpc/get_widget_companies") else {
            print("❌ Invalid companies RPC URL")
            throw APIError.invalidURL
        }
        
        print("📍 Companies RPC URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // No parameters needed for companies
        request.httpBody = try JSONEncoder().encode([String: String]())

        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Companies RPC response status: \(httpResponse.statusCode)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Companies RPC request failed")
            if let rawString = String(data: data, encoding: .utf8) {
                print("📄 Companies error response: \(rawString)")
            }
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let companies = try decoder.decode([WidgetCompany].self, from: data)
        print("✅ Successfully fetched \(companies.count) companies")
        
        return companies
    }
    
    // MARK: - User ID Methods
    
    func getCurrentUserId() -> Int? {
        print("🎯 WIDGET API: getCurrentUserId called")
        
        // First try shared container
        if let userId = getUserIdFromSharedContainer() {
            print("✅ WIDGET API: Found user ID in shared container: \(userId)")
            return userId
        }
        
        // Fallback to standard UserDefaults
        print("⚠️ WIDGET API: No user in shared container, trying standard UserDefaults")
        if let userId = getUserIdFromStandardDefaults() {
            return userId
        }
        
        print("❌ WIDGET API: No user found in either location")
        return nil
    }
    
    private func getUserIdFromSharedContainer() -> Int? {
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ WIDGET API: Failed to get UserDefaults for app group: \(appGroupIdentifier)")
            return nil
        }
        
        print("🎯 WIDGET API: UserDefaults created for user check")
        print("🎯 WIDGET API: App group identifier: \(appGroupIdentifier)")
        
        // Force synchronization
        sharedDefaults.synchronize()
        print("🎯 WIDGET API: UserDefaults synchronized")
        
        // Let's check all keys and their values for debugging
        let allKeys = sharedDefaults.dictionaryRepresentation()
        for (key, value) in allKeys.sorted(by: { $0.key < $1.key }) {
            if key == "lastLoggedInUser" {
                if let data = value as? Data {
                    if let jsonString = String(data: data, encoding: .utf8) {
                    }
                } else {
                }
            } else {
            }
        }
        
        guard let userData = sharedDefaults.data(forKey: "lastLoggedInUser") else {
            print("❌ WIDGET API: No user data found for key 'lastLoggedInUser' in shared container")
            return nil
        }
        
        
        do {
            // Define a struct that matches AppGroupManager.SimpleUser exactly
            struct AppGroupSimpleUser: Codable {
                let id: Int
                let username: String
                let email: String
            }
            
            let user = try JSONDecoder().decode(AppGroupSimpleUser.self, from: userData)
            print("✅ WIDGET API: Successfully decoded user ID from shared container: \(user.id) (\(user.username))")
            return user.id
        } catch {
            print("❌ WIDGET API: Failed to decode user data from shared container: \(error)")
            if let jsonString = String(data: userData, encoding: .utf8) {
                print("📄 WIDGET API: Raw user data: \(jsonString)")
            }
            return nil
        }
    }
    
    private func getUserIdFromStandardDefaults() -> Int? {
        print("🎯 WIDGET API: getUserIdFromStandardDefaults called")
        
        let standardDefaults = UserDefaults.standard
        
        guard let userData = standardDefaults.data(forKey: "lastLoggedInUser") else {
            print("❌ WIDGET API: No user data found for key 'lastLoggedInUser' in standard UserDefaults")
            return nil
        }
        
        print("✅ WIDGET API: Found \(userData.count) bytes of user data in standard UserDefaults")
        
        do {
            // First try to decode as AppGroupManager.SimpleUser
            struct AppGroupSimpleUser: Codable {
                let id: Int
                let username: String
                let email: String
            }
            
            let user = try JSONDecoder().decode(AppGroupSimpleUser.self, from: userData)
            print("✅ WIDGET API: Successfully decoded user ID from standard UserDefaults: \(user.id) (\(user.username))")
            
            // Since we found the user in standard UserDefaults, try to copy it to shared container
            print("🔄 WIDGET API: Attempting to copy user data to shared container...")
            if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                sharedDefaults.set(userData, forKey: "lastLoggedInUser")
                sharedDefaults.synchronize()
                print("✅ WIDGET API: Copied user data to shared container")
            }
            
            return user.id
        } catch {
            print("❌ WIDGET API: Failed to decode user data from standard UserDefaults: \(error)")
            if let jsonString = String(data: userData, encoding: .utf8) {
                print("📄 WIDGET API: Raw user data: \(jsonString)")
            }
            
            // Try to decode as full User struct (for backwards compatibility)
            do {
                struct FullUser: Codable {
                    let id: Int
                    let email: String
                    let firstName: String?
                    let lastName: String?
                }
                
                let fullUser = try JSONDecoder().decode(FullUser.self, from: userData)
                print("✅ WIDGET API: Successfully decoded full user from standard UserDefaults: \(fullUser.id)")
                
                // Convert to SimpleUser and save to shared container
                let username = [fullUser.firstName, fullUser.lastName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    .isEmpty ? fullUser.email : [fullUser.firstName, fullUser.lastName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                struct SimpleUser: Codable {
                    let id: Int
                    let username: String
                    let email: String
                }
                
                let simpleUser = SimpleUser(id: fullUser.id, username: username, email: fullUser.email)
                
                if let simpleUserData = try? JSONEncoder().encode(simpleUser),
                   let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                    sharedDefaults.set(simpleUserData, forKey: "lastLoggedInUser")
                    sharedDefaults.synchronize()
                    print("✅ WIDGET API: Converted and saved full user to shared container as SimpleUser")
                }
                
                return fullUser.id
            } catch {
                print("❌ WIDGET API: Failed to decode as full User struct either: \(error)")
                return nil
            }
        }
    }
}

// MARK: - API Errors

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case notAuthenticated
    case serverError(Int)
}
