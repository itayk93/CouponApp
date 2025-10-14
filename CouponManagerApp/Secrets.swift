//
//  Secrets.swift
//  CouponManagerApp
//
//  Secure configuration manager that reads values from Info.plist
//  These values are loaded from Config.xcconfig file during build time
//

import Foundation

enum Secrets {
    static let supabaseURL: String = {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
            fatalError("SUPABASE_URL not set in Info.plist. Make sure Config.xcconfig is properly configured.")
        }
        // Remove escape characters used in xcconfig
        return url.replacingOccurrences(of: "$()", with: "")
    }()
    
    static let supabaseAnonKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            fatalError("SUPABASE_ANON_KEY not set in Info.plist. Make sure Config.xcconfig is properly configured.")
        }
        return key
    }()
    
    static let openAIAPIKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String else {
            fatalError("OPENAI_API_KEY not set in Info.plist. Make sure Config.xcconfig is properly configured.")
        }
        return key
    }()
    
    static let pythonServerURL: String = {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "PYTHON_SERVER_URL") as? String else {
            fatalError("PYTHON_SERVER_URL not set in Info.plist. Make sure Config.xcconfig is properly configured.")
        }
        // Remove escape characters used in xcconfig
        return url.replacingOccurrences(of: "$()", with: "")
    }()
    
    static let notificationsSupabaseURL: String = {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "NOTIFICATIONS_SUPABASE_URL") as? String else {
            fatalError("NOTIFICATIONS_SUPABASE_URL not set in Info.plist. Make sure Config.xcconfig is properly configured.")
        }
        // Remove escape characters used in xcconfig
        return url.replacingOccurrences(of: "$()", with: "")
    }()
    
    static let notificationsSupabaseAnonKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "NOTIFICATIONS_SUPABASE_ANON_KEY") as? String else {
            fatalError("NOTIFICATIONS_SUPABASE_ANON_KEY not set in Info.plist. Make sure Config.xcconfig is properly configured.")
        }
        return key
    }()
}