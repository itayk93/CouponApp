import Foundation

final class MonthlySummaryCache {
    static let shared = MonthlySummaryCache()
    
    private let defaults: UserDefaults
    private let summaryKey = "MonthlySummaryCache"
    private let listKey = "MonthlySummaryListCache"
    private let pendingKey = "PendingMonthlySummary"
    private let cacheTTL: TimeInterval = 60 * 60 * 24 // 24 hours
    
    private struct SummaryEntry: Codable {
        let summary: MonthlySummaryModel
        let savedAt: Date
    }
    
    private struct ListEntry: Codable {
        let items: [MonthlySummaryListItem]
        let savedAt: Date
    }
    
    init(userDefaults: UserDefaults = AppGroupManager.shared.sharedUserDefaults ?? .standard) {
        self.defaults = userDefaults
    }
    
    func cachedSummary(month: Int, year: Int) -> MonthlySummaryModel? {
        let key = "\(year)-\(month)"
        var map = loadSummaryMap()
        guard let entry = map[key] else { return nil }
        
        if Date().timeIntervalSince(entry.savedAt) >= cacheTTL {
            map.removeValue(forKey: key)
            saveSummaryMap(map)
            return nil
        }
        
        return entry.summary
    }
    
    func save(summary: MonthlySummaryModel) {
        var map = loadSummaryMap()
        map["\(summary.year)-\(summary.month)"] = SummaryEntry(summary: summary, savedAt: Date())
        saveSummaryMap(map)
    }
    
    func cachedList() -> [MonthlySummaryListItem]? {
        guard let data = defaults.data(forKey: listKey),
              let entry = try? JSONDecoder().decode(ListEntry.self, from: data) else {
            return nil
        }
        
        guard Date().timeIntervalSince(entry.savedAt) < cacheTTL else {
            defaults.removeObject(forKey: listKey)
            return nil
        }
        
        return entry.items
    }
    
    func save(list: [MonthlySummaryListItem]) {
        let entry = ListEntry(items: list, savedAt: Date())
        if let data = try? JSONEncoder().encode(entry) {
            defaults.set(data, forKey: listKey)
        }
    }
    
    func savePending(trigger: MonthlySummaryTrigger) {
        if let data = try? JSONEncoder().encode(trigger) {
            defaults.set(data, forKey: pendingKey)
        }
    }
    
    func consumePending() -> MonthlySummaryTrigger? {
        guard let data = defaults.data(forKey: pendingKey),
              let trigger = try? JSONDecoder().decode(MonthlySummaryTrigger.self, from: data) else {
            return nil
        }
        
        defaults.removeObject(forKey: pendingKey)
        return trigger
    }
    
    func seedDemoSummaryIfNeeded() {
        let demoId = "demo-2025-11"
        let month = 11
        let year = 2025
        let key = "\(year)-\(month)"
        
        var map = loadSummaryMap()
        if map[key] != nil { return }
        
        let demoStats = MonthlyStats(
            newCouponsCount: 18,
            usedNewCouponsCount: 12,
            totalSavings: 1240,
            totalActiveValue: 2150,
            usagePercentage: 68,
            popularCompanies: [
                MonthlyCompanyUsage(name: "שופרסל", usageCount: 5),
                MonthlyCompanyUsage(name: "קפה ג׳ו", usageCount: 3),
                MonthlyCompanyUsage(name: "אמריקן איגל", usageCount: 2)
            ],
            expiringNextMonth: 4,
            expiringCompanies: ["HM", "ACE", "Yelo"],
            couponsChange: 3,
            savingsChange: 180
        )
        
        let demoSummary = MonthlySummaryModel(
            id: demoId,
            month: month,
            year: year,
            monthName: "נובמבר",
            style: "friendly",
            summaryText: "📆 סיכום נובמבר: חסכת יפה! ניצלת את רוב הקופונים החדשים, נשאר לך ערך פעיל גבוה לחודש הבא, ויש עוד כמה קופונים שתפוגתם קרובה.",
            stats: demoStats,
            generatedAt: ISO8601DateFormatter().date(from: "2025-12-01T10:00:00Z") ?? Date(),
            ctaLinks: nil
        )
        
        map[key] = SummaryEntry(summary: demoSummary, savedAt: Date())
        saveSummaryMap(map)
        
        var list = cacheListWithoutExpiry()
        let listItem = MonthlySummaryListItem(
            id: demoId,
            month: month,
            year: year,
            monthName: "נובמבר",
            style: "friendly",
            generatedAt: demoSummary.generatedAt,
            isRead: false
        )
        if !list.contains(where: { $0.id == demoId }) {
            list.insert(listItem, at: 0)
            save(list: list)
        }
    }
    
    private func cacheListWithoutExpiry() -> [MonthlySummaryListItem] {
        guard let data = defaults.data(forKey: listKey),
              let entry = try? JSONDecoder().decode(ListEntry.self, from: data) else {
            return []
        }
        return entry.items
    }
    
    private func loadSummaryMap() -> [String: SummaryEntry] {
        guard let data = defaults.data(forKey: summaryKey),
              let map = try? JSONDecoder().decode([String: SummaryEntry].self, from: data) else {
            return [:]
        }
        return map
    }
    
    private func saveSummaryMap(_ map: [String: SummaryEntry]) {
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: summaryKey)
        }
    }
}
