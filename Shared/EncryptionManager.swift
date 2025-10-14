import Foundation
import CryptoKit
import CommonCrypto

public class EncryptionManager {
    // The real key from the server - same as the original project
    private static let encryptionKey = "iKWLJAq-F_BoMip2duhM3-QUPNtxRrefQ0TeaxXQc0E="
    
    public static func decryptString(_ encryptedString: String) -> String? {
        // Check if the string is encrypted (starts with gAAAAA)
        guard encryptedString.starts(with: "gAAAAA") else {
            // If not encrypted, return as is
            print("🔓 String not encrypted (doesn't start with gAAAAA): \(String(encryptedString.prefix(20)))...")
            return encryptedString
        }
        
        print("🔐 Attempting to decrypt: \(String(encryptedString.prefix(50)))...")
        let result = fernetDecrypt(encryptedString)
        if let result = result {
            print("✅ Decryption successful: \(String(result.prefix(50)))...")
        } else {
            print("❌ Decryption failed for: \(String(encryptedString.prefix(50)))...")
        }
        return result
    }
    
    // MARK: - Fernet Implementation
    
    private static func fernetDecrypt(_ encryptedString: String) -> String? {
        // URL-safe Base64 decoding
        var base64String = encryptedString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let paddingLength = 4 - (base64String.count % 4)
        if paddingLength < 4 {
            base64String += String(repeating: "=", count: paddingLength)
        }
        
        guard let encryptedData = Data(base64Encoded: base64String) else {
            print("❌ Failed to decode base64: \(encryptedString)")
            return nil
        }
        
        // Verify the data is long enough for Fernet format
        guard encryptedData.count >= 57 else {
            print("❌ Data too short for Fernet: \(encryptedData.count)")
            return nil
        }
        
        // Parse Fernet structure
        let version = encryptedData[0]
        guard version == 0x80 else {
            print("❌ Invalid Fernet version: 0x\(String(format: "%02x", version))")
            return nil
        }
        
        let iv = encryptedData[9..<25]
        let hmac = encryptedData.suffix(32)
        let ciphertext = encryptedData[25..<(encryptedData.count-32)]
        
        // Get the base key - the key itself is URL-safe base64
        var keyBase64 = encryptionKey
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding to the key if needed
        let keyPaddingLength = 4 - (keyBase64.count % 4)
        if keyPaddingLength < 4 {
            keyBase64 += String(repeating: "=", count: keyPaddingLength)
        }
        
        guard let keyData = Data(base64Encoded: keyBase64),
              keyData.count == 32 else {
            print("❌ Invalid encryption key length. Expected 32 bytes, got \(Data(base64Encoded: keyBase64)?.count ?? 0)")
            return nil
        }
        
        // Decrypt the ciphertext
        guard let decryptedData = decryptAES128CBC(data: ciphertext, key: keyData, iv: iv) else {
            print("❌ Failed to decrypt data")
            return nil
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
    
    private static func decryptAES128CBC(data: Data, key: Data, iv: Data) -> Data? {
        // Ensure the key is exactly 16 bytes for AES-128
        guard key.count == 16 else {
            print("❌ AES key must be exactly 16 bytes, got \(key.count)")
            return nil
        }
        
        var decryptedData = Data(count: data.count + kCCBlockSizeAES128)
        var numBytesDecrypted: size_t = 0
        
        let cryptStatus = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                data.withUnsafeBytes { dataBytes in
                    decryptedData.withUnsafeMutableBytes { decryptedBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, key.count,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress, data.count,
                            decryptedBytes.baseAddress, decryptedData.count,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }
        
        if cryptStatus == kCCSuccess {
            decryptedData.count = numBytesDecrypted
            return decryptedData
        }
        
        print("❌ Decryption failed with status: \(cryptStatus)")
        return nil
    }
}
