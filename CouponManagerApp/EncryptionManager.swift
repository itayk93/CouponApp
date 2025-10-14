//
//  EncryptionManager.swift
//  CouponManagerApp
//
//  Created by itay karkason on 20/09/2025.
//

import Foundation
import CryptoKit
import CommonCrypto

class EncryptionManager {
    // המפתח האמיתי מהשרת - זהה לפרויקט המקורי
    private static let encryptionKey = "iKWLJAq-F_BoMip2duhM3-QUPNtxRrefQ0TeaxXQc0E="
    
    static func decryptString(_ encryptedString: String) -> String? {
        // בדוק אם המחרוזת מוצפנת (מתחילה ב-gAAAAA)
        guard encryptedString.starts(with: "gAAAAA") else {
            // אם לא מוצפנת, החזר כמו שהיא
            print("🔓 String not encrypted (doesn't start with gAAAAA): \(String(encryptedString.prefix(20)))...")
            return encryptedString
        }
        
        print("🔐 Attempting to decrypt: \(String(encryptedString.prefix(50)))...")
        let result = fernetDecrypt(encryptedString)
        if let result = result {
            //print("✅ Decryption successful: \(String(result.prefix(50)))...")
        } else {
            print("❌ Decryption failed for: \(String(encryptedString.prefix(50)))...")
        }
        return result
    }
    
    static func encryptString(_ plainString: String) -> String {
        guard let encrypted = fernetEncrypt(plainString) else {
            return plainString
        }
        return encrypted
    }
    
    // MARK: - Fernet Implementation - תיקון מלא
    
    private static func fernetDecrypt(_ encryptedString: String) -> String? {
        print("🔍 Starting Fernet decryption...")
        
        // פענוח Base64 URL-safe
        var base64String = encryptedString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // הוסף padding אם נדרש
        let paddingLength = 4 - (base64String.count % 4)
        if paddingLength < 4 {
            base64String += String(repeating: "=", count: paddingLength)
        }
        
        guard let encryptedData = Data(base64Encoded: base64String) else {
            print("❌ Failed to decode base64: \(encryptedString)")
            return nil
        }
        
        print("📊 Encrypted data length: \(encryptedData.count)")
        
        // וודא שהמידע מספיק ארוך עבור Fernet: version(1) + timestamp(8) + iv(16) + ciphertext + hmac(32)
        guard encryptedData.count >= 57 else {
            print("❌ Data too short for Fernet: \(encryptedData.count)")
            return nil
        }
        
        // פרק את מבנה Fernet
        let version = encryptedData[0]
        guard version == 0x80 else {
            print("❌ Invalid Fernet version: 0x\(String(format: "%02x", version))")
            return nil
        }
        
        let timestamp = encryptedData[1..<9]
        let iv = encryptedData[9..<25]
        let hmac = encryptedData.suffix(32)
        let ciphertext = encryptedData[25..<(encryptedData.count-32)]
        
        print("🔑 IV: \(iv.count) bytes, Ciphertext: \(ciphertext.count) bytes, HMAC: \(hmac.count) bytes")
        
        // קבל את המפתח הבסיסי - המפתח עצמו הוא URL-safe base64
        var keyBase64 = encryptionKey
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // הוסף padding למפתח אם נדרש
        let keyPaddingLength = 4 - (keyBase64.count % 4)
        if keyPaddingLength < 4 {
            keyBase64 += String(repeating: "=", count: keyPaddingLength)
        }
        
        guard let keyData = Data(base64Encoded: keyBase64),
              keyData.count == 32 else {
            print("❌ Invalid encryption key length. Expected 32 bytes, got \(Data(base64Encoded: keyBase64)?.count ?? 0)")
            print("🔍 Original key: \(encryptionKey)")
            print("🔍 Converted key: \(keyBase64)")
            return nil
        }
        
        print("✅ Key loaded successfully: 32 bytes")
        
        // חלק את המפתח כמו ב-Fernet האמיתי: 16 bytes ראשונים לSigning, 16 אחרונים לEncryption
        let signingKey = keyData[0..<16]     // 16 bytes ראשונים לHMAC
        let encryptionKey = keyData[16..<32] // 16 bytes אחרונים לAES
        
        //print("🔑 Signing key: \(signingKey.count) bytes")
        //print("🔑 Encryption key: \(encryptionKey.count) bytes")
        
        // בדוק HMAC-SHA256 עם מפתח הSigning בלבד (לא כל המפתח!)
        let message = encryptedData[0..<(encryptedData.count-32)]
        let computedHmac = HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: signingKey))
        
        guard Data(computedHmac) == hmac else {
            print("❌ HMAC verification failed")
            print("🔍 Expected HMAC: \(hmac.map { String(format: "%02x", $0) }.joined())")
            print("🔍 Computed HMAC: \(Data(computedHmac).map { String(format: "%02x", $0) }.joined())")
            return nil
        }
        
        print("✅ HMAC verification passed")
        
        // פענח באמצעות AES-128-CBC עם מפתח הEncryption בלבד (16 bytes אחרונים)
        let decryptedData = decryptAES128CBC(data: Data(ciphertext), key: Data(encryptionKey), iv: Data(iv))
        
        guard let decryptedData = decryptedData,
              let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            print("❌ AES decryption failed or invalid UTF-8")
            return nil
        }
        
        return decryptedString
    }
    
    private static func fernetEncrypt(_ plainString: String) -> String? {
        guard let plainData = plainString.data(using: .utf8) else {
            print("❌ Invalid input data for encryption")
            return nil
        }
        
        // קבל את המפתח - המפתח עצמו הוא URL-safe base64
        var keyBase64 = encryptionKey
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // הוסף padding למפתח אם נדרש
        let keyPaddingLength = 4 - (keyBase64.count % 4)
        if keyPaddingLength < 4 {
            keyBase64 += String(repeating: "=", count: keyPaddingLength)
        }
        
        guard let keyData = Data(base64Encoded: keyBase64),
              keyData.count == 32 else {
            print("❌ Invalid encryption key for encryption")
            return nil
        }
        
        // חלק את המפתח כמו ב-Fernet האמיתי
        let signingKey = keyData[0..<16]     // 16 bytes ראשונים לHMAC
        let encryptionKey = keyData[16..<32] // 16 bytes אחרונים לAES
        
        // יצר IV אקראי
        var iv = Data(count: 16)
        let result = iv.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 16, $0.bindMemory(to: UInt8.self).baseAddress!)
        }
        guard result == errSecSuccess else {
            print("❌ Failed to generate random IV")
            return nil
        }
        
        // הצפן באמצעות AES-128-CBC עם מפתח הEncryption בלבד
        guard let ciphertext = encryptAES128CBC(data: plainData, key: Data(encryptionKey), iv: iv) else {
            print("❌ AES encryption failed")
            return nil
        }
        
        // בנה מבנה Fernet
        var fernetData = Data()
        fernetData.append(0x80) // version
        
        // timestamp (8 bytes) - big endian
        let timestamp = UInt64(Date().timeIntervalSince1970)
        withUnsafeBytes(of: timestamp.bigEndian) { fernetData.append(contentsOf: $0) }
        
        fernetData.append(iv)
        fernetData.append(ciphertext)
        
        // HMAC עם מפתח הSigning בלבד (לא כל המפתח!)
        let hmac = HMAC<SHA256>.authenticationCode(for: fernetData, using: SymmetricKey(data: signingKey))
        fernetData.append(Data(hmac))
        
        // המר ל-URL-safe base64
        let base64String = fernetData.base64EncodedString()
        return base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
    
    // MARK: - AES Helper Functions
    
    private static func decryptAES128CBC(data: Data, key: Data, iv: Data) -> Data? {
        // ודא שהמפתח הוא בדיוק 16 בתים עבור AES-128
        guard key.count == 16 else {
            print("❌ AES key must be exactly 16 bytes, got \(key.count)")
            return nil
        }
        
        let bufferSize = data.count + kCCBlockSizeAES128
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var numBytesDecrypted: size_t = 0
        
        let cryptStatus = data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                iv.withUnsafeBytes { ivBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.bindMemory(to: UInt8.self).baseAddress,
                        key.count, // AES-128 key length (16 bytes)
                        ivBytes.bindMemory(to: UInt8.self).baseAddress,
                        dataBytes.bindMemory(to: UInt8.self).baseAddress,
                        data.count,
                        buffer,
                        bufferSize,
                        &numBytesDecrypted
                    )
                }
            }
        }
        
        guard cryptStatus == kCCSuccess else {
            print("❌ CCCrypt decryption failed with status: \(cryptStatus)")
            return nil
        }
        
        return Data(bytes: buffer, count: numBytesDecrypted)
    }
    
    private static func encryptAES128CBC(data: Data, key: Data, iv: Data) -> Data? {
        // ודא שהמפתח הוא בדיוק 16 בתים עבור AES-128
        guard key.count == 16 else {
            print("❌ AES key must be exactly 16 bytes, got \(key.count)")
            return nil
        }
        
        let bufferSize = data.count + kCCBlockSizeAES128
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var numBytesEncrypted: size_t = 0
        
        let cryptStatus = data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                iv.withUnsafeBytes { ivBytes in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.bindMemory(to: UInt8.self).baseAddress,
                        key.count, // AES-128 key length (16 bytes)
                        ivBytes.bindMemory(to: UInt8.self).baseAddress,
                        dataBytes.bindMemory(to: UInt8.self).baseAddress,
                        data.count,
                        buffer,
                        bufferSize,
                        &numBytesEncrypted
                    )
                }
            }
        }
        
        guard cryptStatus == kCCSuccess else {
            print("❌ CCCrypt encryption failed with status: \(cryptStatus)")
            return nil
        }
        return Data(bytes: buffer, count: numBytesEncrypted)
    }
}

// MARK: - Usage Example and Testing

extension EncryptionManager {
    static func testEncryptionDecryption() {
        print("🧪 Testing encryption/decryption...")
        
        let testString = "This is a test string for encryption"
        print("📝 Original: \(testString)")
        
        // Test encryption
        let encrypted = encryptString(testString)
        print("🔐 Encrypted: \(encrypted)")
        
        // Test decryption
        let decrypted = decryptString(encrypted)
        print("🔓 Decrypted: \(decrypted ?? "nil")")
        
        if decrypted == testString {
            print("✅ Test passed!")
        } else {
            print("❌ Test failed!")
        }
    }
}
