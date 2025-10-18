import Foundation

// Shared models for widget (these should match the main app models)

struct WidgetCoupon: Codable, Identifiable {
    let id: Int
    let code: String
    let description: String?
    let value: Double
    let cost: Double
    let company: String
    let expiration: String?
    let dateAdded: String?
    let usedValue: Double
    let status: String
    let isOneTime: Bool
    let userId: Int
    var showInWidget: Bool?
    var widgetDisplayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, code, description, value, cost, company, expiration, status
        case dateAdded = "date_added"
        case usedValue = "used_value"
        case isOneTime = "is_one_time"
        case userId = "user_id"
        case showInWidget = "show_in_widget"
        case widgetDisplayOrder = "widget_display_order"
    }
    
    // Memberwise initializer
    init(id: Int, code: String, description: String?, value: Double, cost: Double, company: String, expiration: String?, dateAdded: String?, usedValue: Double, status: String, isOneTime: Bool, userId: Int, showInWidget: Bool?, widgetDisplayOrder: Int? = nil) {
        self.id = id
        self.code = code
        self.description = description
        self.value = value
        self.cost = cost
        self.company = company
        self.expiration = expiration
        self.dateAdded = dateAdded
        self.usedValue = usedValue
        self.status = status
        self.isOneTime = isOneTime
        self.userId = userId
        self.showInWidget = showInWidget
        self.widgetDisplayOrder = widgetDisplayOrder
    }
    
    // Custom decoder to handle various type mismatches from API
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields - basic types
        id = try container.decode(Int.self, forKey: .id)
        code = try container.decode(String.self, forKey: .code)
        company = try container.decode(String.self, forKey: .company)
        status = try container.decode(String.self, forKey: .status)
        
        print("🔍 Decoding coupon ID:\(id), company:\(company)")
        
        // Optional string fields
        description = try container.decodeIfPresent(String.self, forKey: .description)
        expiration = try container.decodeIfPresent(String.self, forKey: .expiration)
        dateAdded = try container.decodeIfPresent(String.self, forKey: .dateAdded)
        
        // Handle value as Double or Int
        if let doubleValue = try? container.decode(Double.self, forKey: .value) {
            value = doubleValue
        } else if let intValue = try? container.decode(Int.self, forKey: .value) {
            value = Double(intValue)
        } else {
            value = 0.0
        }
        
        // Handle cost as Double or Int
        if let doubleValue = try? container.decode(Double.self, forKey: .cost) {
            cost = doubleValue
        } else if let intValue = try? container.decode(Int.self, forKey: .cost) {
            cost = Double(intValue)
        } else {
            cost = 0.0
        }
        
        // Handle used_value as Double, Int, or String
        if let doubleValue = try? container.decode(Double.self, forKey: .usedValue) {
            usedValue = doubleValue
        } else if let intValue = try? container.decode(Int.self, forKey: .usedValue) {
            usedValue = Double(intValue)
        } else if let stringValue = try? container.decode(String.self, forKey: .usedValue),
                  let doubleValue = Double(stringValue) {
            usedValue = doubleValue
        } else {
            usedValue = 0.0
        }
        
        // Handle is_one_time as Bool or Int (0/1)
        if let boolValue = try? container.decode(Bool.self, forKey: .isOneTime) {
            isOneTime = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isOneTime) {
            isOneTime = intValue != 0
        } else {
            isOneTime = false
        }
        
        // Handle user_id as Int (with fallback)
        if let intValue = try? container.decode(Int.self, forKey: .userId) {
            userId = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .userId),
                  let intValue = Int(stringValue) {
            userId = intValue
        } else {
            userId = 0
        }
        
        // Handle show_in_widget as Bool or Int (0/1) - WITH DETAILED LOGGING
        print("🔍 Raw show_in_widget value check for ID:\(id)...")
        
        // First, try to see what's actually in the JSON
        if let rawValue = try? container.decodeIfPresent(String.self, forKey: .showInWidget) {
            print("   📝 Found as String: '\(rawValue)'")
        }
        if let rawValue = try? container.decodeIfPresent(Int.self, forKey: .showInWidget) {
            print("   📝 Found as Int: \(rawValue)")
        }
        if let rawValue = try? container.decodeIfPresent(Bool.self, forKey: .showInWidget) {
            print("   📝 Found as Bool: \(rawValue)")
        }
        
        // Now decode it properly
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .showInWidget) {
            showInWidget = boolValue
            print("   ✅ Decoded as Bool: \(boolValue)")
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .showInWidget) {
            showInWidget = intValue != 0
            print("   ✅ Decoded as Int(\(intValue)) -> Bool: \(intValue != 0)")
        } else {
            showInWidget = false
            print("   ⚠️ No value found, defaulting to false")
        }
        
        print("   🎯 FINAL showInWidget value: \(showInWidget ?? false)")
        
        // Handle widget_display_order
        widgetDisplayOrder = try container.decodeIfPresent(Int.self, forKey: .widgetDisplayOrder)
        print("   🔢 WIDGET ORDER for ID:\(id) - Raw: \(widgetDisplayOrder ?? -1), Final: \(widgetDisplayOrder ?? 999)")
    }
    
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
    let companyCount: Int64  // שינוי מ-Int ל-Int64 עבור BIGINT
}

// *** תיקון כפילות השם: SimpleUser שונה ל-WidgetSimpleUser ***
struct WidgetSimpleUser: Codable {
    let id: Int
    let username: String
    let email: String
}

// This struct must match AppGroupManager.SimpleUser exactly
struct SharedSimpleUser: Codable {
    let id: Int
    let username: String
    let email: String
}

struct WidgetCouponsResponse: Codable {
    let coupons: [WidgetCoupon]
    let total: Int
    let page: Int
    let perPage: Int
    
    enum CodingKeys: String, CodingKey {
        case coupons, total, page
        case perPage = "per_page"
    }
}

struct WidgetCompaniesResponse: Codable {
    let companies: [WidgetCompany]
}
