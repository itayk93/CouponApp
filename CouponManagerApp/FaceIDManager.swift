//
//  FaceIDManager.swift
//  CouponManagerApp
//
//  מנהל זיהוי פנים
//

import Foundation
import LocalAuthentication
import Combine

class FaceIDManager: ObservableObject {
    static let shared = FaceIDManager()
    
    @Published var isFaceIDEnabled = false
    @Published var isFaceIDAvailable = false
    
    private init() {
        checkFaceIDAvailability()
    }
    
    // MARK: - Face ID Availability
    func checkFaceIDAvailability() {
        let context = LAContext()
        var error: NSError?
        
        isFaceIDAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if let error = error {
            print("Face ID availability error: \(error.localizedDescription)")
        }
        
        print("Face ID available: \(isFaceIDAvailable)")
    }
    
    // MARK: - Authenticate with Face ID
    func authenticateWithFaceID(reason: String = "אמת את זהותך") async -> Bool {
        let context = LAContext()
        
        do {
            let result = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            return result
        } catch {
            print("Face ID authentication error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Get biometric type
    func getBiometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }
    
    // MARK: - User preferences
    func enableFaceID(for userId: Int) async -> Bool {
        // First authenticate with Face ID
        let authenticated = await authenticateWithFaceID(reason: "אמת את זהותך כדי להפעיל זיהוי פנים")
        
        if authenticated {
            // Save preference to server
            await saveFaceIDPreference(userId: userId, enabled: true)
            
            // Save locally
            UserDefaults.standard.set(true, forKey: "faceID_enabled_\(userId)")
            isFaceIDEnabled = true
            return true
        }
        
        return false
    }
    
    func disableFaceID(for userId: Int) async {
        // Save preference to server
        await saveFaceIDPreference(userId: userId, enabled: false)
        
        // Remove local preference
        UserDefaults.standard.removeObject(forKey: "faceID_enabled_\(userId)")
        isFaceIDEnabled = false
    }
    
    func isFaceIDEnabled(for userId: Int) -> Bool {
        return UserDefaults.standard.bool(forKey: "faceID_enabled_\(userId)")
    }
    
    // MARK: - Server Communication
    private func saveFaceIDPreference(userId: Int, enabled: Bool) async {
        // TODO: Implement API call to save Face ID preference
        // This will update the face_id_enabled column in the users table
        
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/users?id=eq.\(userId)") else {
            print("❌ Invalid URL for Face ID preference update")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let body = ["face_id_enabled": enabled]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                    print("✅ Face ID preference saved successfully")
                } else {
                    print("❌ Failed to save Face ID preference: \(httpResponse.statusCode)")
                    if let responseData = String(data: data, encoding: .utf8) {
                        print("Response: \(responseData)")
                    }
                }
            }
        } catch {
            print("❌ Error saving Face ID preference: \(error.localizedDescription)")
        }
    }
    
    func loadFaceIDPreference(for userId: Int) async {
        // Try to load from server first
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/users?id=eq.\(userId)&select=face_id_enabled") else {
            print("❌ Invalid URL for Face ID preference fetch")
            // Fallback to UserDefaults
            isFaceIDEnabled = UserDefaults.standard.bool(forKey: "faceID_enabled_\(userId)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let userRecord = json.first,
               let faceIdEnabled = userRecord["face_id_enabled"] as? Bool {
                
                DispatchQueue.main.async {
                    self.isFaceIDEnabled = faceIdEnabled
                    // Also sync with UserDefaults
                    UserDefaults.standard.set(faceIdEnabled, forKey: "faceID_enabled_\(userId)")
                }
                print("✅ Loaded Face ID preference from server: \(faceIdEnabled)")
            } else {
                // Fallback to UserDefaults if server doesn't have the data
                DispatchQueue.main.async {
                    self.isFaceIDEnabled = UserDefaults.standard.bool(forKey: "faceID_enabled_\(userId)")
                }
                print("⚠️ Face ID preference not found on server, using local default")
            }
        } catch {
            print("❌ Error loading Face ID preference: \(error.localizedDescription)")
            // Fallback to UserDefaults
            DispatchQueue.main.async {
                self.isFaceIDEnabled = UserDefaults.standard.bool(forKey: "faceID_enabled_\(userId)")
            }
        }
    }
}

// MARK: - Biometric Type Enum
enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
    
    var displayName: String {
        switch self {
        case .none:
            return "לא זמין"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        }
    }
    
    var iconName: String {
        switch self {
        case .none:
            return "xmark.circle"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        }
    }
}