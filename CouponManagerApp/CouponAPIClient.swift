//
//  CouponAPIClient.swift
//  CouponManagerApp
//
//  API Client עבור מערכת הקופונים
//

import Foundation
import Combine

class CouponAPIClient: ObservableObject {
    private let baseURL = SupabaseConfig.url
    private let apiKey = SupabaseConfig.anonKey
    
    // MARK: - User Management
    private func getCurrentUser() -> User? {
        // Try to get user from AppGroup first (shared with widget)
        if let user = AppGroupManager.shared.getCurrentUserFromSharedContainer() {
            return user
        }
        
        // Fallback: try to get from UserDefaults
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            return user
        }
        
        return nil
    }
    
    // MARK: - Fetch User Coupons
    
    // Fetch ALL user coupons without pagination limits
    func fetchAllUserCoupons(userId: Int, completion: @escaping (Result<[Coupon], Error>) -> Void) {
        // Remove limit and offset to get ALL coupons
        let urlString = "\(baseURL)/rest/v1/coupon?user_id=eq.\(userId)&select=*&order=date_added.desc"
        AppLogger.log("📡 Supabase query (ALL coupons): \(urlString)")
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(URLError(.badServerResponse)))
                }
                return
            }
            
            if let _ = String(data: data, encoding: .utf8) { }
            
            do {
                let coupons = try JSONDecoder().decode([Coupon].self, from: data)
                DispatchQueue.main.async {
                    completion(.success(coupons))
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ Failed to decode ALL coupons: \(error)")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // Original paginated method (kept for compatibility)
    func fetchUserCoupons(userId: Int, page: Int = 0, pageSize: Int = 50, completion: @escaping (Result<[Coupon], Error>) -> Void) {
        let offset = page * pageSize
        let urlString = "\(baseURL)/rest/v1/coupon?user_id=eq.\(userId)&select=*&order=date_added.desc&limit=\(pageSize)&offset=\(offset)"
        AppLogger.log("📡 Supabase query (paginated coupons): \(urlString)")
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        print("🎫 Fetching coupons for user \(userId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(URLError(.badServerResponse)))
                }
                return
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📨 Coupons response: \(String(jsonString.prefix(200)))...")
            }
            
            do {
                let coupons = try JSONDecoder().decode([Coupon].self, from: data)
                DispatchQueue.main.async {
                    print("✅ Loaded \(coupons.count) coupons")
                    completion(.success(coupons))
                }
            } catch {
                print("❌ Coupon decode error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Fetch User Total Value
    func fetchUserTotalValue(userId: Int, completion: @escaping (Result<Double, Error>) -> Void) {
        // Try direct aggregation query first (more reliable than RPC)
        let urlString = "\(baseURL)/rest/v1/coupon?user_id=eq.\(userId)&select=value,used_value,is_for_sale,exclude_saving,is_one_time"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(URLError(.badServerResponse)))
                }
                return
            }
            
            do {
                // Parse as array of coupon summary objects
                if let coupons = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    var totalRemaining: Double = 0.0
                    
                    for couponData in coupons {
                        let value = couponData["value"] as? Double ?? 0.0
                        let usedValue = couponData["used_value"] as? Double ?? 0.0
                        let isForSale = couponData["is_for_sale"] as? Bool ?? false
                        let excludeSaving = couponData["exclude_saving"] as? Bool ?? false
                        let isOneTime = couponData["is_one_time"] as? Bool ?? false
                        
                        // Apply same filtering as web and iOS - exclude one-time coupons
                        if !isForSale && !excludeSaving && !isOneTime {
                            let remaining = max(value - usedValue, 0.0)
                            totalRemaining += remaining
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success(totalRemaining))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(URLError(.cannotParseResponse)))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Fetch Companies
    func fetchCompanies(completion: @escaping (Result<[Company], Error>) -> Void) {
        let urlString = "\(baseURL)/rest/v1/companies?select=*&order=company_count.desc"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(URLError(.badServerResponse)))
                }
                return
            }
            
            do {
                let companies = try JSONDecoder().decode([Company].self, from: data)
                DispatchQueue.main.async {
                    completion(.success(companies))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Fetch Company Usage Statistics
    func fetchCompanyUsageStats(userId: Int, completion: @escaping (Result<[CompanyUsageStats], Error>) -> Void) {
        // This will execute a raw SQL query via PostgREST to get company usage statistics
        
        let urlString = "\(baseURL)/rest/v1/rpc/get_company_usage_stats"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        let requestBody = ["user_id": userId]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(URLError(.badServerResponse)))
                }
                return
            }
            
            do {
                // Primary: Expect an array response
                let stats = try JSONDecoder().decode([CompanyUsageStats].self, from: data)
                DispatchQueue.main.async { completion(.success(stats)) }
            } catch {
                // Friendly fallback: handle PostgREST function-not-found error by returning an empty array
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let code = obj["code"] as? String, code == "PGRST202" {
                    DispatchQueue.main.async { completion(.success([])) }
                    return
                }
                // Fallbacks for alternate shapes
                // 1) Wrapper object: { "stats": [ ... ] } or { "data": [ ... ] }
                struct StatsWrapper: Codable { let stats: [CompanyUsageStats]?; let data: [CompanyUsageStats]? }
                // 2) Dictionary keyed by company: { "CompanyName": { total_count, ... }, ... }
                struct StatsPayload: Codable {
                    let total_count: Int
                    let paid_count: Int
                    let free_count: Int
                    let total_spent: Double
                }
                let decoder = JSONDecoder()
                // Try wrapper
                if let wrapper = try? decoder.decode(StatsWrapper.self, from: data),
                   let wrapped = wrapper.stats ?? wrapper.data {
                    DispatchQueue.main.async { completion(.success(wrapped)) }
                    return
                }
                // Try dictionary keyed by company
                if let dict = try? decoder.decode([String: StatsPayload].self, from: data) {
                    let mapped: [CompanyUsageStats] = dict.map { key, value in
                        CompanyUsageStats(
                            company: key,
                            totalCount: value.total_count,
                            paidCount: value.paid_count,
                            freeCount: value.free_count,
                            totalSpent: value.total_spent
                        )
                    }
                    // Keep order deterministic by totalCount desc, then company name
                    let sorted = mapped.sorted { lhs, rhs in
                        if lhs.totalCount == rhs.totalCount { return lhs.company < rhs.company }
                        return lhs.totalCount > rhs.totalCount
                    }
                    DispatchQueue.main.async { completion(.success(sorted)) }
                    return
                }
                // If all decodes failed, include raw payload for debugging
                let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                let enrichedError = NSError(
                    domain: "CouponAPI",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to decode company usage stats. Raw: \(raw)"]
                )
                DispatchQueue.main.async { completion(.failure(enrichedError)) }
            }
        }.resume()
    }
    
    // MARK: - Create Coupon
    func createCoupon(_ couponRequest: CouponCreateRequest, userId: Int, completion: @escaping (Result<Coupon, Error>) -> Void) {
        // First generate a unique random ID
        generateUniqueCouponId { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let randomId):
                self.createCouponWithId(randomId, couponRequest, userId: userId, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Generate Unique Coupon ID
    private func generateUniqueCouponId(completion: @escaping (Result<Int, Error>) -> Void) {
        let maxAttempts = 100
        tryGenerateUniqueId(attempt: 0, maxAttempts: maxAttempts, completion: completion)
    }
    
    private func tryGenerateUniqueId(attempt: Int, maxAttempts: Int, completion: @escaping (Result<Int, Error>) -> Void) {
        guard attempt < maxAttempts else {
            completion(.failure(NSError(domain: "CouponAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not generate unique coupon ID after maximum attempts"])))
            return
        }
        
        // Generate random ID between 1000 and 10000 (same as Python version)
        let randomId = Int.random(in: 1000...10000)
        
        // Check if this ID already exists
        checkIfCouponIdExists(randomId) { [weak self] exists in
            guard let self = self else { return }
            
            if exists {
                // ID exists, try again
                self.tryGenerateUniqueId(attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
            } else {
                // ID is unique, use it
                completion(.success(randomId))
            }
        }
    }
    
    private func checkIfCouponIdExists(_ id: Int, completion: @escaping (Bool) -> Void) {
        let urlString = "\(baseURL)/rest/v1/coupon?id=eq.\(id)&select=id"
        
        guard let url = URL(string: urlString) else {
            completion(false) // Assume doesn't exist if we can't check
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error checking coupon ID existence: \(error)")
                completion(false) // Assume doesn't exist on error
                return
            }
            
            guard let data = data else {
                completion(false)
                return
            }
            
            do {
                let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                let exists = !(jsonArray?.isEmpty ?? true)
                print("🔍 Checking ID \(id): exists = \(exists)")
                completion(exists)
            } catch {
                print("❌ Error parsing coupon ID check response: \(error)")
                completion(false)
            }
        }.resume()
    }
    
    private func createCouponWithId(_ couponId: Int, _ couponRequest: CouponCreateRequest, userId: Int, completion: @escaping (Result<Coupon, Error>) -> Void) {
        let urlString = "\(baseURL)/rest/v1/coupon"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        do {
            // Create a mutable copy of the coupon request to apply encryption
            var encryptedRequest = couponRequest
            
            // Encrypt sensitive fields before storing to database
            encryptedRequest.code = EncryptionManager.encryptString(couponRequest.code)
            if let description = couponRequest.description {
                encryptedRequest.description = EncryptionManager.encryptString(description)
            }
            // Encrypt card details if provided
            if let cvv = couponRequest.cvv, !cvv.isEmpty {
                encryptedRequest.cvv = EncryptionManager.encryptString(cvv)
            }
            if let exp = couponRequest.cardExp, !exp.isEmpty {
                encryptedRequest.cardExp = EncryptionManager.encryptString(exp)
            }
            
            // Encrypt URL fields
            if let buyMeUrl = couponRequest.buyMeCouponUrl, !buyMeUrl.isEmpty {
                encryptedRequest.buyMeCouponUrl = EncryptionManager.encryptString(buyMeUrl)
            }
            if let straussUrl = couponRequest.straussCouponUrl, !straussUrl.isEmpty {
                encryptedRequest.straussCouponUrl = EncryptionManager.encryptString(straussUrl)
            }
            if let xgiftcardUrl = couponRequest.xgiftcardCouponUrl, !xgiftcardUrl.isEmpty {
                encryptedRequest.xgiftcardCouponUrl = EncryptionManager.encryptString(xgiftcardUrl)
            }
            if let xtraUrl = couponRequest.xtraCouponUrl, !xtraUrl.isEmpty {
                encryptedRequest.xtraCouponUrl = EncryptionManager.encryptString(xtraUrl)
            }
            
            print("🔐 Encrypting coupon data before database insertion...")
            print("🔍 Original code: \(String(couponRequest.code.prefix(10)))...")
            print("🔐 Encrypted code: \(String(encryptedRequest.code.prefix(20)))...")
            
            var requestData = try JSONEncoder().encode(encryptedRequest)
            
            // Add user_id and random ID to the request
            guard let couponDict = try JSONSerialization.jsonObject(with: requestData) as? [String: Any] else {
                completion(.failure(NSError(domain: "CouponAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse coupon request"])))
                return
            }
            
            var mutableCouponDict = couponDict
            mutableCouponDict["id"] = couponId
            mutableCouponDict["user_id"] = userId
            mutableCouponDict["date_added"] = ISO8601DateFormatter().string(from: Date())
            mutableCouponDict["used_value"] = 0.0  // Default used value to 0
            mutableCouponDict["status"] = "פעיל"   // Default status
            mutableCouponDict["is_available"] = true  // Default availability
            
            print("🎫 Creating coupon with random ID: \(couponId) (Security: Using random ID instead of sequential for better security)")
            
            requestData = try JSONSerialization.data(withJSONObject: mutableCouponDict)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = requestData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let data = data else {
                    DispatchQueue.main.async {
                        completion(.failure(URLError(.badServerResponse)))
                    }
                    return
                }
                
                // Debug: Print raw response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📨 Create coupon response: \(String(jsonString.prefix(500)))...")
                }
                
                do {
                    // First try to decode as array of coupons (success case)
                    let coupons = try JSONDecoder().decode([Coupon].self, from: data)
                    if let coupon = coupons.first {
                        print("✅ Successfully created coupon with ID: \(coupon.id)")
                        // After creating a coupon, mirror the web: create an initial recharge row
                        self.upsertInitialRechargeTransaction(couponId: coupon.id, value: coupon.value) { upsertResult in
                            switch upsertResult {
                            case .success:
                                print("✅ Initial recharge transaction recorded for coupon \(coupon.id)")
                                DispatchQueue.main.async { completion(.success(coupon)) }
                            case .failure(let err):
                                print("❌ Failed to record initial recharge transaction: \(err)")
                                // Still return the created coupon to the UI
                                DispatchQueue.main.async { completion(.success(coupon)) }
                            }
                        }
                    } else {
                        print("❌ No coupon returned from server")
                        DispatchQueue.main.async {
                            completion(.failure(URLError(.cannotParseResponse)))
                        }
                    }
                } catch {
                    print("❌ Coupon creation decode error: \(error)")
                    
                    // Try to decode as error response
                    do {
                        let errorResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        if let message = errorResponse?["message"] as? String {
                            let errorDescription = "Database error: \(message)"
                            print("❌ Server error: \(errorDescription)")
                            DispatchQueue.main.async {
                                completion(.failure(NSError(domain: "CouponAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: errorDescription])))
                            }
                        } else {
                            DispatchQueue.main.async {
                                completion(.failure(error))
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Upsert initial recharge transaction (balance row)
    // Creates or updates the initial balance row in coupon_transaction, similar to Flask add_coupon_transaction
    func upsertInitialRechargeTransaction(couponId: Int, value: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        // 1) Try to update existing 'Initial' or 'ManualEntry' record
        guard let patchURL = URL(string: "\(baseURL)/rest/v1/coupon_transaction?coupon_id=eq.\(couponId)&source=eq.User&reference_number=in.(Initial,ManualEntry)") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var patchRequest = URLRequest(url: patchURL)
        patchRequest.httpMethod = "PATCH"
        patchRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        patchRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        patchRequest.setValue(apiKey, forHTTPHeaderField: "apikey")
        // Ask server to return updated rows so we know if something was matched
        patchRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let patchBody: [String: Any] = [
            "recharge_amount": value
        ]
        patchRequest.httpBody = try? JSONSerialization.data(withJSONObject: patchBody)

        URLSession.shared.dataTask(with: patchRequest) { data, response, error in
            if let error = error {
                // On error, try fallback to insert
                print("⚠️ Patch initial transaction failed (will try insert): \(error)")
                self.insertInitialRechargeTransaction(couponId: couponId, value: value, completion: completion)
                return
            }

            guard let data = data else {
                self.insertInitialRechargeTransaction(couponId: couponId, value: value, completion: completion)
                return
            }

            // If any rows were returned, update succeeded
            if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], arr.count > 0 {
                completion(.success(()))
                return
            }

            // No existing row, insert a new one
            self.insertInitialRechargeTransaction(couponId: couponId, value: value, completion: completion)
        }.resume()
    }

    private func insertInitialRechargeTransaction(couponId: Int, value: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let postURL = URL(string: "\(baseURL)/rest/v1/coupon_transaction") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var postRequest = URLRequest(url: postURL)
        postRequest.httpMethod = "POST"
        postRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        postRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        postRequest.setValue(apiKey, forHTTPHeaderField: "apikey")
        postRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let nowISO = ISO8601DateFormatter().string(from: Date())
        let body: [String: Any] = [
            "coupon_id": couponId,
            "transaction_date": nowISO,
            "recharge_amount": value,
            "usage_amount": 0.0,
            "location": "הטענה ראשונית",
            "reference_number": "Initial",
            "source": "User"
        ]
        postRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: postRequest) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }

    // MARK: - Update Coupon
    func updateCoupon(couponId: Int, data: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "\(baseURL)/rest/v1/coupon?id=eq.\(couponId)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        guard let requestData = try? JSONSerialization.data(withJSONObject: data) else {
            completion(.failure(NSError(domain: "CouponAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize update data"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.httpBody = requestData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let message = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "CouponAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(message)"])))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }.resume()
    }
    
    // MARK: - Update Coupon Usage
    // Reads current used_value, increments locally, PATCHes numeric value, then logs usage with reason
    func updateCouponUsage(couponId: Int, usageRequest: CouponUsageRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        // 1) Fetch current used_value
        let fetchURLString = "\(baseURL)/rest/v1/coupon?id=eq.\(couponId)&select=used_value&limit=1"
        guard let fetchURL = URL(string: fetchURLString) else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var fetchReq = URLRequest(url: fetchURL)
        fetchReq.httpMethod = "GET"
        fetchReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        fetchReq.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        fetchReq.setValue(apiKey, forHTTPHeaderField: "apikey")

        URLSession.shared.dataTask(with: fetchReq) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(URLError(.badServerResponse))) }
                return
            }
            do {
                // Expect an array with one object containing used_value
                var currentUsed: Double = 0.0
                if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let obj = arr.first {
                    if let dv = obj["used_value"] as? Double {
                        currentUsed = dv
                    } else if let iv = obj["used_value"] as? Int {
                        currentUsed = Double(iv)
                    } else if let sv = obj["used_value"] as? String, let dv = Double(sv) {
                        currentUsed = dv
                    }
                }

                let newUsed = currentUsed + usageRequest.usedAmount

                // 2) PATCH numeric used_value
                let patchURLString = "\(self.baseURL)/rest/v1/coupon?id=eq.\(couponId)"
                guard let patchURL = URL(string: patchURLString) else {
                    DispatchQueue.main.async { completion(.failure(URLError(.badURL))) }
                    return
                }
                var patchReq = URLRequest(url: patchURL)
                patchReq.httpMethod = "PATCH"
                patchReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                patchReq.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
                patchReq.setValue(self.apiKey, forHTTPHeaderField: "apikey")
                let payload: [String: Any] = ["used_value": newUsed]
                patchReq.httpBody = try JSONSerialization.data(withJSONObject: payload)

                URLSession.shared.dataTask(with: patchReq) { _, _, patchErr in
                    if let patchErr = patchErr {
                        DispatchQueue.main.async { completion(.failure(patchErr)) }
                        return
                    }
                    // 3) Create usage record with explicit reason in details
                    var usageWithReason = usageRequest
                    // Normalize details: prepend fixed reason and keep user's detail if present
                    let baseReason = "עודכן באפליקציה"
                    if let extra = usageRequest.details?.trimmingCharacters(in: .whitespacesAndNewlines), !extra.isEmpty {
                        usageWithReason = CouponUsageRequest(usedAmount: usageRequest.usedAmount, action: "שימוש ידני", details: "\(baseReason) - \(extra)")
                    } else {
                        usageWithReason = CouponUsageRequest(usedAmount: usageRequest.usedAmount, action: "שימוש ידני", details: baseReason)
                    }
                    self.createCouponUsage(couponId: couponId, usageRequest: usageWithReason) { _ in
                        DispatchQueue.main.async { completion(.success(())) }
                    }
                }.resume()
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
    
    // MARK: - Create Coupon Usage Record
    private func createCouponUsage(couponId: Int, usageRequest: CouponUsageRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "\(baseURL)/rest/v1/coupon_usage"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        let usageData = [
            "coupon_id": couponId,
            "used_amount": usageRequest.usedAmount,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            // Align with web app semantics: Hebrew action for manual entry
            "action": usageRequest.action ?? "שימוש ידני",
            "details": usageRequest.details ?? "עודכן באפליקציה"
        ] as [String : Any]
        
        guard let requestData = try? JSONSerialization.data(withJSONObject: usageData) else {
            completion(.failure(NSError(domain: "CouponAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize usage data"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.httpBody = requestData
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }.resume()
    }
    
    // MARK: - Delete Coupon
    func deleteCoupon(couponId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "\(baseURL)/rest/v1/coupon?id=eq.\(couponId)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }.resume()
    }
    
    // MARK: - Fetch Coupon Usage History
    func fetchCouponUsageHistory(couponId: Int, completion: @escaping (Result<[CouponUsage], Error>) -> Void) {
        let urlString = "\(baseURL)/rest/v1/coupon_usage?coupon_id=eq.\(couponId)&select=*&order=timestamp.desc"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(URLError(.badServerResponse)))
                }
                return
            }
            
            do {
                let usages = try JSONDecoder().decode([CouponUsage].self, from: data)
                DispatchQueue.main.async {
                    completion(.success(usages))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Mark Coupon as Used
    func markCouponAsUsed(couponId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "\(baseURL)/rest/v1/rpc/mark_coupon_as_used_rpc"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        let parameters = ["p_coupon_id": couponId]
        
        guard let requestData = try? JSONSerialization.data(withJSONObject: parameters) else {
            completion(.failure(NSError(domain: "CouponAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize RPC parameters"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.httpBody = requestData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let message = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown RPC error"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "CouponAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server RPC error: \(message)"])))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }.resume()
    }
    
    // MARK: - Update last_company_view timestamp
    func updateLastCompanyView(for companyName: String, userId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "\(baseURL)/rest/v1/coupon?company=eq.\(companyName)&user_id=eq.\(userId)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        let updateData = [
            "last_company_view": ISO8601DateFormatter().string(from: Date())
        ]
        
        guard let requestData = try? JSONSerialization.data(withJSONObject: updateData) else {
            completion(.failure(NSError(domain: "CouponAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize update data"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.httpBody = requestData
        
        print("🕒 Updating last_company_view for company: \(companyName), user: \(userId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            DispatchQueue.main.async {
                print("✅ Successfully updated last_company_view for \(companyName)")
                completion(.success(()))
            }
        }.resume()
    }
    
    // MARK: - Update last_detail_view timestamp
    func updateLastDetailView(for couponId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "\(baseURL)/rest/v1/coupon?id=eq.\(couponId)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        let updateData = [
            "last_detail_view": ISO8601DateFormatter().string(from: Date())
        ]
        
        guard let requestData = try? JSONSerialization.data(withJSONObject: updateData) else {
            completion(.failure(NSError(domain: "CouponAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize update data"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.httpBody = requestData
        
        print("🕒 Updating last_detail_view for coupon ID: \(couponId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            DispatchQueue.main.async {
                print("✅ Successfully updated last_detail_view for coupon \(couponId)")
                completion(.success(()))
            }
        }.resume()
    }
    
    // MARK: - Fetch Consolidated Transaction Rows
    func fetchConsolidatedTransactionRows(couponId: Int, completion: @escaping (Result<[TransactionRow], Error>) -> Void) {
        // Call the Supabase RPC function `get_consolidated_transactions`
        let urlString = "\(baseURL)/rest/v1/rpc/get_consolidated_transactions"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        // Set the parameters for the RPC call
        let parameters = ["coupon_id_param": couponId]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("🔄 Calling Supabase RPC 'get_consolidated_transactions' for coupon \(couponId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ RPC call failed with network error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response from server.")
                DispatchQueue.main.async {
                    completion(.failure(URLError(.badServerResponse)))
                }
                return
            }
            
            guard let data = data else {
                print("❌ No data received from RPC call")
                DispatchQueue.main.async {
                    completion(.failure(URLError(.badServerResponse)))
                }
                return
            }
            
            // Check for non-successful HTTP status codes
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                print("❌ RPC call failed with status [\(httpResponse.statusCode)]: \(errorMessage)")
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "SupabaseAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                }
                return
            }
            
            // Debug: Print raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Raw RPC response data: \(jsonString.prefix(1000))")
            }
            
            do {
                let rows = try JSONDecoder().decode([TransactionRow].self, from: data)
                DispatchQueue.main.async {
                    print("✅ Successfully fetched \(rows.count) consolidated transaction rows from Supabase RPC")
                    completion(.success(rows))
                }
            } catch {
                print("❌ Failed to decode RPC response: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Test Random ID Generation
    func testRandomIdGeneration() {
        print("🧪 Testing random ID generation...")
        
        generateUniqueCouponId { result in
            switch result {
            case .success(let randomId):
                print("✅ Generated unique random ID: \(randomId)")
                
                // Test that it's in the expected range
                if randomId >= 1000 && randomId <= 10000 {
                    print("✅ ID is in valid range (1000-10000)")
                } else {
                    print("❌ ID \(randomId) is outside valid range (1000-10000)")
                }
                
            case .failure(let error):
                print("❌ Failed to generate random ID: \(error.localizedDescription)")
            }
        }
    }
}
