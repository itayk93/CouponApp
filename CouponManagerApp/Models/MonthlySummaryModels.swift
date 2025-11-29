import Foundation

struct MonthlySummaryModel: Codable, Identifiable {
    let id: String
    let month: Int
    let year: Int
    let monthName: String
    let style: String
    let summaryText: String
    let stats: MonthlyStats
    let generatedAt: Date
    let ctaLinks: [MonthlySummaryCTA]?
    
    enum CodingKeys: String, CodingKey {
        case id = "summary_id"
        case month, year, style, stats
        case monthName = "month_name_he"
        case summaryText = "summary_text"
        case generatedAt = "generated_at"
        case ctaLinks = "cta_links"
    }
    
    var monthYearKey: String {
        "\(year)-\(String(format: "%02d", month))"
    }
}

struct MonthlySummaryCTA: Codable, Identifiable {
    let title: String
    let url: URL?
    let deeplink: URL?
    
    enum CodingKeys: String, CodingKey {
        case title
        case url
        case deeplink = "deeplink_url"
    }
    
    var id: String { "\(title)-\(url?.absoluteString ?? deeplink?.absoluteString ?? UUID().uuidString)" }
}

struct MonthlyStats: Codable {
    let newCouponsCount: Int
    let usedNewCouponsCount: Int
    let totalSavings: Double
    let totalActiveValue: Double
    let usagePercentage: Double
    let popularCompanies: [MonthlyCompanyUsage]
    let expiringNextMonth: Int
    let expiringCompanies: [String]
    let couponsChange: Int
    let savingsChange: Double
    
    enum CodingKeys: String, CodingKey {
        case newCouponsCount = "new_coupons_count"
        case usedNewCouponsCount = "used_new_coupons_count"
        case totalSavings = "total_savings"
        case totalActiveValue = "total_active_value"
        case usagePercentage = "usage_percentage"
        case popularCompanies = "popular_companies"
        case expiringNextMonth = "expiring_next_month"
        case expiringCompanies = "expiring_companies"
        case couponsChange = "coupons_change"
        case savingsChange = "savings_change"
    }
}

struct MonthlyCompanyUsage: Codable, Identifiable {
    let name: String
    let usageCount: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case usageCount = "usage_count"
    }
    
    var id: String { name }
}

struct MonthlySummaryListItem: Codable, Identifiable {
    let id: String
    let month: Int
    let year: Int
    let monthName: String
    let style: String
    let generatedAt: Date
    let isRead: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id = "summary_id"
        case month, year, style
        case monthName = "month_name_he"
        case generatedAt = "generated_at"
        case isRead = "read"
    }
}

struct MonthlySummaryTrigger: Codable, Identifiable {
    let summaryId: String?
    let month: Int
    let year: Int
    let style: String?
    
    var id: String { summaryId ?? "\(year)-\(month)" }
}
