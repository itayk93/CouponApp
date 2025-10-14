//
//  CouponModels.swift
//  CouponManagerApp
//
//  מודלים עבור מערכת הקופונים
//

import Foundation

// MARK: - Coupon Model
struct Coupon: Codable, Identifiable, Equatable {
    let id: Int
    let code: String
    let description: String?
    let value: Double
    let cost: Double
    let company: String
    let expiration: String?
    let source: String?
    let buyMeCouponUrl: String?
    let straussCouponUrl: String?
    let xgiftcardCouponUrl: String?
    let xtraCouponUrl: String?
    let dateAdded: String
    let usedValue: Double
    let status: String
    let isAvailable: Bool
    let isForSale: Bool
    let isOneTime: Bool
    let purpose: String?
    let excludeSaving: Bool
    let autoDownloadDetails: String?
    let userId: Int
    let cvv: String?
    let cardExp: String?
    var showInWidget: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, code, description, value, cost, company, expiration, source, status, purpose, cvv
        case buyMeCouponUrl = "buyme_coupon_url"
        case straussCouponUrl = "strauss_coupon_url"
        case xgiftcardCouponUrl = "xgiftcard_coupon_url"
        case xtraCouponUrl = "xtra_coupon_url"
        case dateAdded = "date_added"
        case usedValue = "used_value"
        case isAvailable = "is_available"
        case isForSale = "is_for_sale"
        case isOneTime = "is_one_time"
        case excludeSaving = "exclude_saving"
        case autoDownloadDetails = "auto_download_details"
        case userId = "user_id"
        case cardExp = "card_exp"
        case showInWidget = "show_in_widget"
    }
    
    // Memberwise initializer
    init(
        id: Int,
        code: String,
        description: String?,
        value: Double,
        cost: Double,
        company: String,
        expiration: String?,
        source: String?,
        buyMeCouponUrl: String?,
        straussCouponUrl: String?,
        xgiftcardCouponUrl: String?,
        xtraCouponUrl: String?,
        dateAdded: String,
        usedValue: Double,
        status: String,
        isAvailable: Bool,
        isForSale: Bool,
        isOneTime: Bool,
        purpose: String?,
        excludeSaving: Bool,
        autoDownloadDetails: String?,
        userId: Int,
        cvv: String?,
        cardExp: String?,
        showInWidget: Bool? = nil
    ) {
        self.id = id
        self.code = code
        self.description = description
        self.value = value
        self.cost = cost
        self.company = company
        self.expiration = expiration
        self.source = source
        self.buyMeCouponUrl = buyMeCouponUrl
        self.straussCouponUrl = straussCouponUrl
        self.xgiftcardCouponUrl = xgiftcardCouponUrl
        self.xtraCouponUrl = xtraCouponUrl
        self.dateAdded = dateAdded
        self.usedValue = usedValue
        self.status = status
        self.isAvailable = isAvailable
        self.isForSale = isForSale
        self.isOneTime = isOneTime
        self.purpose = purpose
        self.excludeSaving = excludeSaving
        self.autoDownloadDetails = autoDownloadDetails
        self.userId = userId
        self.cvv = cvv
        self.cardExp = cardExp
        self.showInWidget = showInWidget
    }
    
    // Custom decoder to handle usedValue as both String and Double
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        code = try container.decode(String.self, forKey: .code)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        value = try container.decode(Double.self, forKey: .value)
        cost = try container.decode(Double.self, forKey: .cost)
        company = try container.decode(String.self, forKey: .company)
        expiration = try container.decodeIfPresent(String.self, forKey: .expiration)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        buyMeCouponUrl = try container.decodeIfPresent(String.self, forKey: .buyMeCouponUrl)
        straussCouponUrl = try container.decodeIfPresent(String.self, forKey: .straussCouponUrl)
        xgiftcardCouponUrl = try container.decodeIfPresent(String.self, forKey: .xgiftcardCouponUrl)
        xtraCouponUrl = try container.decodeIfPresent(String.self, forKey: .xtraCouponUrl)
        dateAdded = try container.decode(String.self, forKey: .dateAdded)
        
        // Handle usedValue as Double, Int, or String
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
        
        status = try container.decode(String.self, forKey: .status)
        
        // Handle boolean fields as Bool or Int (0/1)
        if let boolValue = try? container.decode(Bool.self, forKey: .isAvailable) {
            isAvailable = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isAvailable) {
            isAvailable = intValue != 0
        } else {
            isAvailable = true
        }
        
        if let boolValue = try? container.decode(Bool.self, forKey: .isForSale) {
            isForSale = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isForSale) {
            isForSale = intValue != 0
        } else {
            isForSale = false
        }
        
        if let boolValue = try? container.decode(Bool.self, forKey: .isOneTime) {
            isOneTime = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isOneTime) {
            isOneTime = intValue != 0
        } else {
            isOneTime = false
        }
        
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose)
        
        if let boolValue = try? container.decode(Bool.self, forKey: .excludeSaving) {
            excludeSaving = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .excludeSaving) {
            excludeSaving = intValue != 0
        } else {
            excludeSaving = false
        }
        
        autoDownloadDetails = try container.decodeIfPresent(String.self, forKey: .autoDownloadDetails)
        
        // Handle user_id as Int (with fallback)
        if let intValue = try? container.decode(Int.self, forKey: .userId) {
            userId = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .userId),
                  let intValue = Int(stringValue) {
            userId = intValue
        } else {
            userId = 0
        }
        
        cvv = try container.decodeIfPresent(String.self, forKey: .cvv)
        cardExp = try container.decodeIfPresent(String.self, forKey: .cardExp)
        
        // Handle show_in_widget as Bool or Int (0/1)
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .showInWidget) {
            showInWidget = boolValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .showInWidget) {
            showInWidget = intValue != 0
        } else {
            showInWidget = nil
        }
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(code, forKey: .code)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(value, forKey: .value)
        try container.encode(cost, forKey: .cost)
        try container.encode(company, forKey: .company)
        try container.encodeIfPresent(expiration, forKey: .expiration)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(buyMeCouponUrl, forKey: .buyMeCouponUrl)
        try container.encodeIfPresent(straussCouponUrl, forKey: .straussCouponUrl)
        try container.encodeIfPresent(xgiftcardCouponUrl, forKey: .xgiftcardCouponUrl)
        try container.encodeIfPresent(xtraCouponUrl, forKey: .xtraCouponUrl)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(usedValue, forKey: .usedValue)
        try container.encode(status, forKey: .status)
        try container.encode(isAvailable, forKey: .isAvailable)
        try container.encode(isForSale, forKey: .isForSale)
        try container.encode(isOneTime, forKey: .isOneTime)
        try container.encodeIfPresent(purpose, forKey: .purpose)
        try container.encode(excludeSaving, forKey: .excludeSaving)
        try container.encodeIfPresent(autoDownloadDetails, forKey: .autoDownloadDetails)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(cvv, forKey: .cvv)
        try container.encodeIfPresent(cardExp, forKey: .cardExp)
        try container.encodeIfPresent(showInWidget, forKey: .showInWidget)
    }
    
    // Equatable conformance
    static func == (lhs: Coupon, rhs: Coupon) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Computed properties
    var remainingValue: Double {
        return value - usedValue
    }
    
    var usagePercentage: Double {
        guard value > 0 else { return 0 }
        return (usedValue / value) * 100
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
    
    var statusColor: String {
        if isExpired { return "red" }
        if isFullyUsed { return "gray" }
        if status == "פעיל" { return "green" }
        return "orange"
    }
    
    var expirationDate: Date? {
        guard let expirationString = expiration else { return nil }
        return ISO8601DateFormatter().date(from: expirationString + "T00:00:00Z")
    }
    
    var formattedExpirationDate: String {
        guard let date = expirationDate else { return "ללא תפוגה" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "he_IL")
        return formatter.string(from: date)
    }
    
    // Decrypted properties
    var decryptedCode: String {
        #if !WIDGET_EXTENSION
        return EncryptionManager.decryptString(code) ?? code
        #else
        return code
        #endif
    }
    
    var decryptedDescription: String? {
        #if !WIDGET_EXTENSION
        guard let desc = description else { return nil }
        return EncryptionManager.decryptString(desc)
        #else
        return description
        #endif
    }
    
    var decryptedCvv: String? {
        #if !WIDGET_EXTENSION
        guard let cvvValue = cvv else { return nil }
        return EncryptionManager.decryptString(cvvValue)
        #else
        return cvv
        #endif
    }
}

// MARK: - Company Model
struct Company: Codable, Identifiable {
    let id: Int
    let name: String
    let imagePath: String
    let companyCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case imagePath = "image_path"
        case companyCount = "company_count"
    }
    
    var logoURL: String {
        // Assuming logos are served from your website
        return "https://www.couponmasteril.com/static/company_logos/\(imagePath)"
    }
}

// MARK: - Coupon Usage Model
struct CouponUsage: Codable, Identifiable {
    let id: Int
    let couponId: Int
    let usedAmount: Double
    let timestamp: String
    let action: String?
    let details: String?
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, action, details
        case couponId = "coupon_id"
        case usedAmount = "used_amount"
    }
    
    var date: Date? {
        return ISO8601DateFormatter().date(from: timestamp)
    }
    
    var formattedDate: String {
        guard let date = date else { return "תאריך לא ידוע" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "he_IL")
        return formatter.string(from: date)
    }
}

// MARK: - Coupon Request Model
struct CouponRequest: Codable, Identifiable {
    let id: Int
    let company: String
    let otherCompany: String?
    let code: String?
    let value: Double
    let cost: Double
    let description: String?
    let userId: Int
    let dateRequested: String
    let fulfilled: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, company, code, value, cost, description, fulfilled
        case otherCompany = "other_company"
        case userId = "user_id"
        case dateRequested = "date_requested"
    }
}

// MARK: - API Response Wrappers
struct CouponsResponse: Codable {
    let coupons: [Coupon]
    let total: Int
    let page: Int
    let perPage: Int
    
    enum CodingKeys: String, CodingKey {
        case coupons, total, page
        case perPage = "per_page"
    }
}

struct CompaniesResponse: Codable {
    let companies: [Company]
}

// MARK: - Coupon Creation/Update Models
struct CouponCreateRequest: Codable {
    var code: String
    var description: String?
    var value: Double
    var cost: Double
    var company: String
    var expiration: String?
    var source: String?
    var buyMeCouponUrl: String?
    var straussCouponUrl: String?
    var xgiftcardCouponUrl: String?
    var xtraCouponUrl: String?
    var isForSale: Bool
    var isOneTime: Bool
    var purpose: String?
    var autoDownloadDetails: String?
    
    enum CodingKeys: String, CodingKey {
        case code, description, value, cost, company, expiration, source, purpose
        case buyMeCouponUrl = "buyme_coupon_url"
        case straussCouponUrl = "strauss_coupon_url"
        case xgiftcardCouponUrl = "xgiftcard_coupon_url"
        case xtraCouponUrl = "xtra_coupon_url"
        case isForSale = "is_for_sale"
        case isOneTime = "is_one_time"
        case autoDownloadDetails = "auto_download_details"
    }
}

struct CouponUsageRequest: Codable {
    let usedAmount: Double
    let action: String?
    let details: String?
    
    enum CodingKeys: String, CodingKey {
        case action, details
        case usedAmount = "used_amount"
    }
}

// MARK: - Filter Options
enum CouponFilter: String, CaseIterable {
    case all = "all"
    case active = "active"
    case expired = "expired"
    case fullyUsed = "fully_used"
    case forSale = "for_sale"
    
    var displayName: String {
        switch self {
        case .all: return "הכל"
        case .active: return "פעילים"
        case .expired: return "פגי תוקף"
        case .fullyUsed: return "מנוצלים לחלוטין"
        case .forSale: return "למכירה"
        }
    }
}

enum CouponSort: String, CaseIterable {
    case dateAdded = "date_added"
    case expiration = "expiration"
    case value = "value"
    case remainingValue = "remaining_value"
    case company = "company"
    
    var displayName: String {
        switch self {
        case .dateAdded: return "תאריך הוספה"
        case .expiration: return "תאריך תפוגה"
        case .value: return "ערך"
        case .remainingValue: return "ערך נותר"
        case .company: return "חברה"
        }
    }
}

// MARK: - Company Usage Statistics
struct CompanyUsageStats: Codable, Identifiable {
    let company: String
    let totalCount: Int
    let paidCount: Int
    let freeCount: Int
    let totalSpent: Double
    
    var id: String { company }
    
    enum CodingKeys: String, CodingKey {
        case company
        case totalCount = "total_count"
        case paidCount = "paid_count"
        case freeCount = "free_count"
        case totalSpent = "total_spent"
    }
}

// MARK: - Transaction Row Model (for consolidated history)
struct TransactionRow: Codable, Identifiable {
    let sourceTable: String
    let id: Int?
    let couponId: Int
    let timestamp: String?
    let transactionAmount: Double
    let details: String?
    let action: String?
    
    var transactionId: String {
        return "\(sourceTable)_\(id ?? 0)_\(couponId)"
    }
    
    enum CodingKeys: String, CodingKey {
        case sourceTable = "source_table"
        case id
        case couponId = "coupon_id"
        case timestamp = "transaction_timestamp"
        case transactionAmount = "transaction_amount"
        case details
        case action
    }
}
