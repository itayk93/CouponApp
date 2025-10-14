//
//  PasswordManager.swift
//  CouponManagerApp
//
//  Compatible with Werkzeug password hashing from Flask
//

import Foundation
import CryptoKit
import CommonCrypto

class PasswordManager {
    
    /**
     * בדיקת סיסמה מול hash שנוצר ב-Werkzeug (Flask)
     * תואם לפונקציה check_password_hash של Werkzeug
     */
    static func checkPassword(_ password: String, againstHash storedHash: String?) -> Bool {
        guard let storedHash = storedHash, !storedHash.isEmpty else {
            print("❌ No stored hash provided")
            return false
        }
        
        print("🔍 Checking password against hash: \(String(storedHash.prefix(50)))...")
        print("🔍 Full hash: \(storedHash)")
        
        // Werkzeug משתמש בפורמט: method$salt$hash
        let components = storedHash.components(separatedBy: "$")
        
        print("🔍 Hash components count: \(components.count)")
        for (i, component) in components.enumerated() {
            print("   [\(i)]: \(component)")
        }
        
        guard components.count >= 3 else {
            print("❌ Invalid hash format - expected method$salt$hash, got \(components.count) components")
            return false
        }
        
        let method = components[0]
        print("🔐 Hash method: \(method)")
        
        // Check if method contains pbkdf2
        if method.contains("pbkdf2") {
            return checkPBKDF2Password(password, components: components)
        } else if method.contains("scrypt") {
            return checkScryptPassword(password, components: components)
        } else {
            print("❌ Unsupported hash method: \(method)")
            return false
        }
    }
    
    /**
     * בדיקת PBKDF2 - תואם ל-Werkzeug
     * פורמט: pbkdf2:sha256:iterations$salt$hash
     */
    private static func checkPBKDF2Password(_ password: String, components: [String]) -> Bool {
        print("🔍 Raw components: \(components)")
        
        // הפורמט הוא: method$salt$hash
        // כאשר method הוא pbkdf2:sha256:600000
        guard components.count >= 3 else {
            print("❌ Invalid PBKDF2 format - need at least 3 components, got \(components.count)")
            return false
        }
        
        let method = components[0]  // pbkdf2:sha256:600000
        let salt = components[1]    // LogSzowhx7bMhOOz
        let expectedHash = components[2]  // fa8710516ca4e3ee751e562d50df997657546e184bce5df7151bcef3e035a373
        
        print("📋 PBKDF2 details:")
        print("   Full method: \(method)")
        print("   Salt: \(salt)")
        print("   Expected hash: \(expectedHash)")
        print("   Password length: \(password.count)")
        print("   Password: '\(password)'")
        
        // Parse method (pbkdf2:sha256:600000)
        let methodParts = method.components(separatedBy: ":")
        guard methodParts.count == 3,
              methodParts[0] == "pbkdf2",
              methodParts[1] == "sha256",
              let iterations = Int(methodParts[2]) else {
            print("❌ Invalid PBKDF2 method format: \(method)")
            print("   Method parts: \(methodParts)")
            return false
        }
        
        print("🔄 Using \(iterations) iterations")
        
        // Convert salt and password to data
        guard let saltData = salt.data(using: .utf8),
              let passwordData = password.data(using: .utf8) else {
            print("❌ Failed to convert password/salt to data")
            return false
        }
        
        print("🧂 Salt bytes: \(saltData.map { String(format: "%02x", $0) }.joined())")
        print("🔤 Password bytes: \(passwordData.map { String(format: "%02x", $0) }.joined())")
        
        // Generate hash using PBKDF2
        let derivedKey = PBKDF2.deriveKey(
            password: passwordData,
            salt: saltData,
            iterations: iterations,
            keyLength: 32  // SHA256 = 32 bytes
        )
        
        // Convert to hex string (lowercase, like Werkzeug)
        let generatedHash = derivedKey.map { String(format: "%02x", $0) }.joined()
        
        print("🔑 Generated hash: \(generatedHash)")
        print("🎯 Expected hash:  \(expectedHash)")
        print("📏 Generated length: \(generatedHash.count)")
        print("📏 Expected length:  \(expectedHash.count)")
        
        let isMatch = generatedHash.lowercased() == expectedHash.lowercased()
        print(isMatch ? "✅ Password matches!" : "❌ Password doesn't match")
        
        // Additional debugging
        if !isMatch {
            print("🔍 First 10 chars comparison:")
            let genPrefix = String(generatedHash.prefix(10))
            let expPrefix = String(expectedHash.prefix(10))
            print("   Generated: \(genPrefix)")
            print("   Expected:  \(expPrefix)")
            print("   Match: \(genPrefix == expPrefix)")
        }
        
        return isMatch
    }
    
    /**
     * בדיקת Scrypt - תואם ל-Werkzeug
     */
    private static func checkScryptPassword(_ password: String, components: [String]) -> Bool {
        // Scrypt הוא מורכב יותר ב-iOS - נטפל בזה אם נתקל
        print("⚠️ Scrypt verification not implemented yet")
        return false
    }
}

/**
 * PBKDF2 Implementation תואם ל-Werkzeug
 */
struct PBKDF2 {
    static func deriveKey(password: Data, salt: Data, iterations: Int, keyLength: Int) -> Data {
        var derivedKey = Data(count: keyLength)
        
        let status = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),                    // Algorithm
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,  // Password
                        password.count,                                  // Password length
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,     // Salt
                        salt.count,                                      // Salt length
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),   // PRF
                        UInt32(iterations),                              // Iterations
                        derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress,  // Derived key
                        keyLength                                        // Derived key length
                    )
                }
            }
        }
        
        guard status == kCCSuccess else {
            print("❌ PBKDF2 derivation failed with status: \(status)")
            return Data()
        }
        
        return derivedKey
    }
}