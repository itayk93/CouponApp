//
//  SavingsReportView.swift
//  CouponManagerApp
//
//  על מה חסכת - דוח חיסכון מפורט כמו באתר המקורי
//

import SwiftUI
import Charts

struct SavingsReportView: View {
    let user: User
    let coupons: [Coupon]
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeframe: TimeframeFilter = .allTime
    // Month/Year selectors – align with the web app controls
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    // Custom date range selection (opened via calendar icon)
    @State private var showDateRangePicker = false
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var showMonthlySavings = true
    @State private var showMonthlyRemaining = false
    // Loading state + precomputed datasets to make the dashboard instant
    @State private var isLoading = true
    @State private var loadingProgress: Double = 0
    @State private var loadingMessage: String = ""
    // Monthly datasets (kept for potential future use)
    @State private var monthlySavingsPoints: [(date: Date, value: Double)] = []
    @State private var cumulativeSavingsPoints: [(date: Date, value: Double)] = []
    @State private var monthlyRemainingPoints: [(date: Date, value: Double)] = []
    // Yearly datasets (used for RTL charts)
    @State private var yearlySavingsPoints: [(date: Date, value: Double)] = []
    @State private var yearlyCumulativePoints: [(date: Date, value: Double)] = []
    @State private var yearlyRemainingPoints: [(date: Date, value: Double)] = []
    // New series for clarified charts
    @State private var yearlyHoldingsCumulativePoints: [(date: Date, value: Double)] = []
    @State private var yearlyNetCumulativePoints: [(date: Date, value: Double)] = []
    // Tooltip selection for usage chart
    @State private var usageSelection: (date: Date, value: Double)? = nil
    @State private var precomputedCategorySavings: [CategorySavings] = []
    @State private var precomputedCompanySavingsAllTime: [CompanySavings] = []
    @State private var precomputedCompanySavingsThisYear: [CompanySavings] = []
    @State private var precomputedCompanySavingsThisMonth: [CompanySavings] = []
    // Tooltip selections for pie charts
    @State private var selectedCategoryTip: (name: String, value: Double, percent: Double)? = nil
    @State private var selectedCompanyTip: (name: String, value: Double, percent: Double)? = nil
    // Precomputed tooltip caches so taps are instantaneous
    @State private var categoryTooltipCache: [String: (value: Double, percent: Double)] = [:]
    @State private var companyTooltipCache: [String: (value: Double, percent: Double, active: Int, used: Int, total: Int)] = [:]

    // Debounce recomputations when multiple controls change quickly
    @State private var recomputeWorkItem: DispatchWorkItem? = nil

    // Cached formatters to avoid per-render allocations
    private static let yearFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "he_IL")
        df.dateFormat = "yyyy"
        return df
    }()
    private static let expirationFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    // Right‑to‑left axis helpers using numeric mirroring
    private func rtlX(_ date: Date) -> Double {
        // Mirror around 0 so newer dates have smaller (more negative) values on the axis
        return -date.timeIntervalSinceReferenceDate
    }
    private func dateFromRTL(_ value: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: -value)
    }
    private var yearlyRTLDoman: ClosedRange<Double>? {
        guard let first = yearRange.first, let last = yearRange.last else { return nil }
        // Keep ascending order for Charts (lower ... upper)
        let lower = rtlX(last)   // newest → more negative → lower bound
        let upper = rtlX(first)  // oldest → less negative → upper bound
        return lower...upper
    }
    private var yearlyRTLTicks: [Double] { yearRange.map { rtlX($0) } }
    private func yearText(_ date: Date) -> String {
        SavingsReportView.yearFormatter.string(from: date)
    }
    
    // Computed properties for statistics
    private var filteredCoupons: [Coupon] {
        let calendar = Calendar.current
        return coupons.filter { coupon in
            guard let dateAdded = coupon.dateAddedAsDate else { return false }
            switch selectedTimeframe {
            case .allTime:
                return true
            case .thisMonth:
                // Robust range check for the selected month in local calendar
                let start = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) ?? Date()
                let endExclusive = calendar.date(byAdding: .month, value: 1, to: start) ?? start
                return dateAdded >= start && dateAdded < endExclusive
            case .thisYear:
                let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? Date()
                let endExclusive = calendar.date(byAdding: .year, value: 1, to: start) ?? start
                return dateAdded >= start && dateAdded < endExclusive
            case .customRange:
                let start = calendar.startOfDay(for: customStartDate)
                let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate)) ?? customEndDate
                return dateAdded >= start && dateAdded < endExclusive
            }
        }
    }

    // MARK: - Web‑like statistics (mirror Flask)
    private var newCouponsCount: Int { filteredCoupons.count }
    private var usedNewCouponsCount: Int { filteredCoupons.filter { $0.usedValue > 0 }.count }
    private var totalSavingsForPeriod: Double {
        // Nominal savings like site: active coupons only, value - cost, excluding flagged
        filteredCoupons
            .filter { $0.status == "פעיל" && !$0.excludeSaving }
            .map { max(0, $0.value - $0.cost) }
            .reduce(0, +)
    }
    private var averageSavingsPerNewCoupon: Double {
        guard newCouponsCount > 0 else { return 0 }
        return totalSavingsForPeriod / Double(newCouponsCount)
    }
    private var averageSavingsPercentPerNewCoupon: Double {
        let items = filteredCoupons.filter { !$0.excludeSaving && $0.value > 0 }
        guard !items.isEmpty else { return 0 }
        let totalPercent = items.reduce(0.0) { acc, c in
            let nominal = max(0, c.value - c.cost)
            let pct = (nominal / c.value) * 100.0
            return acc + pct
        }
        return totalPercent / Double(items.count)
    }
    private var totalActiveValue: Double {
        // Like site: value - used_value for non-for-sale and not excluded
        coupons
            .filter { !$0.isForSale && !$0.excludeSaving }
            .map { max(0, $0.value - $0.usedValue) }
            .reduce(0, +)
    }
    private var usageStats: (total: Int, fully: Int, partial: Int, unused: Int) {
        let total = filteredCoupons.count
        let fully = filteredCoupons.filter { $0.isFullyUsed }.count
        let partial = filteredCoupons.filter { $0.usedValue > 0 && !$0.isFullyUsed }.count
        let unused = max(0, total - fully - partial)
        return (total, fully, partial, unused)
    }
    private var popularCompanies: [(name: String, count: Int)] {
        // Approximate: number of used coupons per company in period
        var counts: [String: Int] = [:]
        for c in filteredCoupons where c.usedValue > 0 {
            counts[c.company, default: 0] += 1
        }
        // Create labeled tuples so we can sort/read by name/count clearly
        let arr: [(name: String, count: Int)] = counts.map { (name: $0.key, count: $0.value) }
        let sortedArr = arr.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.name < rhs.name
        }
        return Array(sortedArr.prefix(5))
    }
    private var comparisonStats: (couponsDelta: Int, savingsDelta: Double)? {
        // Compare to previous month/year depending on selection
        let cal = Calendar.current
        switch selectedTimeframe {
        case .thisMonth:
            var prevMonth = selectedMonth - 1
            var prevYear = selectedYear
            if prevMonth <= 0 { prevMonth = 12; prevYear -= 1 }
            let prev = coupons.filter { c in
                guard let d = c.dateAddedAsDate else { return false }
                let comps = cal.dateComponents([.month, .year], from: d)
                return comps.month == prevMonth && comps.year == prevYear
            }
            let prevCoupons = prev.count
            let prevSavings = prev
                .filter { $0.status == "פעיל" && !$0.excludeSaving }
                .map { max(0, $0.value - $0.cost) }
                .reduce(0, +)
            return (newCouponsCount - prevCoupons, totalSavingsForPeriod - prevSavings)
        case .thisYear:
            let prevYear = selectedYear - 1
            let prev = coupons.filter { c in
                guard let d = c.dateAddedAsDate else { return false }
                return cal.component(.year, from: d) == prevYear
            }
            let prevCoupons = prev.count
            let prevSavings = prev
                .filter { $0.status == "פעיל" && !$0.excludeSaving }
                .map { max(0, $0.value - $0.cost) }
                .reduce(0, +)
            return (newCouponsCount - prevCoupons, totalSavingsForPeriod - prevSavings)
        case .allTime, .customRange:
            return nil
        }
    }
    private var expiringNextMonth: Int {
        // Count active coupons expiring next calendar month
        let cal = Calendar.current
        var comps = DateComponents()
        comps.month = 1
        let baseDate: Date = {
            // Base off selected period’s first day for consistency with the website
            switch selectedTimeframe {
            case .thisMonth:
                return cal.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) ?? Date()
            case .thisYear, .allTime, .customRange:
                return Date()
            }
        }()
        let nextMonthDate = cal.date(byAdding: comps, to: baseDate) ?? Date()
        let targetMonth = cal.component(.month, from: nextMonthDate)
        let targetYear = cal.component(.year, from: nextMonthDate)
        return coupons.filter { c in
            guard c.status == "פעיל", let expStr = c.expiration else { return false }
            // expiration stored as YYYY-MM-DD
            guard let exp = SavingsReportView.expirationFormatter.date(from: expStr) else { return false }
            let m = cal.component(.month, from: exp)
            let y = cal.component(.year, from: exp)
            return m == targetMonth && y == targetYear && (c.value - c.usedValue) > 0
        }.count
    }
    
    private var companySavingsData: [CompanySavings] {
        // Prefer precomputed datasets to keep UI snappy
        switch selectedTimeframe {
        case .allTime:
            if !precomputedCompanySavingsAllTime.isEmpty { return precomputedCompanySavingsAllTime }
        case .thisYear:
            if !precomputedCompanySavingsThisYear.isEmpty { return precomputedCompanySavingsThisYear }
        case .thisMonth:
            if !precomputedCompanySavingsThisMonth.isEmpty { return precomputedCompanySavingsThisMonth }
        case .customRange:
            break
        }
        var companyDict: [String: CompanySavings] = [:]
        
        for coupon in filteredCoupons {
            // Use actual usage for the period to reflect what was really spent
            // rather than nominal (value - cost). This matches the user's
            // expectation of "how much did I use" this month/year.
            let savings: Double = coupon.usedValue
            
            let existing = companyDict[coupon.company] ?? CompanySavings(
                company: coupon.company,
                totalSavings: 0,
                totalValue: 0,
                activeCoupons: 0,
                usedCoupons: 0,
                totalCoupons: 0
            )
            
            companyDict[coupon.company] = CompanySavings(
                company: coupon.company,
                totalSavings: existing.totalSavings + savings,
                totalValue: existing.totalValue + coupon.remainingValue,
                activeCoupons: existing.activeCoupons + (!coupon.isExpired && !coupon.isFullyUsed ? 1 : 0),
                usedCoupons: existing.usedCoupons + (coupon.usedValue > 0 ? 1 : 0),
                totalCoupons: existing.totalCoupons + 1
            )
        }
        
        return Array(companyDict.values)
            .filter { $0.totalCoupons > 0 } // מציג את כל החברות שיש להן קופונים
            .sorted { 
                // מיון לפי חיסכון, ואז לפי ערך כולל, ואז לפי מספר קופונים
                if $0.totalSavings != $1.totalSavings {
                    return $0.totalSavings > $1.totalSavings
                }
                if $0.totalValue != $1.totalValue {
                    return $0.totalValue > $1.totalValue
                }
                return $0.totalCoupons > $1.totalCoupons
            }
    }
    
    // MARK: - Monthly Aggregations
    private var monthRange: [Date] {
        let cal = Calendar.current
        let dates = coupons.compactMap { $0.dateAddedAsDate }
        guard let minDate = dates.min(), let maxDate = dates.max() else { return [] }
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: minDate)),
              let end = cal.date(from: cal.dateComponents([.year, .month], from: maxDate)) else { return [] }
        var months: [Date] = []
        var cursor = start
        while cursor <= end {
            months.append(cursor)
            cursor = cal.date(byAdding: .month, value: 1, to: cursor) ?? cursor
            if months.count > 240 { break } // safety cap (20 years)
        }
        return months
    }

    // MARK: - Yearly Aggregations
    private var yearRange: [Date] {
        let cal = Calendar.current
        let dates = coupons.compactMap { $0.dateAddedAsDate }
        guard let minDate = dates.min(), let maxDate = dates.max() else { return [] }
        guard let start = cal.date(from: DateComponents(year: cal.component(.year, from: minDate), month: 1, day: 1)),
              let end = cal.date(from: DateComponents(year: cal.component(.year, from: maxDate), month: 1, day: 1)) else { return [] }
        var years: [Date] = []
        var cursor = start
        while cursor <= end {
            years.append(cursor)
            cursor = cal.date(byAdding: .year, value: 1, to: cursor) ?? cursor
            if years.count > 50 { break } // safety cap (50 years)
        }
        return years
    }

    private func yearKey(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy"
        return df.string(from: date)
    }
    
    private func monthKey(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "he_IL")
        df.dateFormat = "yyyy-MM"
        return df.string(from: date)
    }
    
    private var monthlySavings: [(date: Date, value: Double)] {
        // Nominal savings for coupons added each month
        var map: [String: Double] = [:]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM"
        let cal = Calendar.current
        for c in coupons {
            guard let d = c.dateAddedAsDate else { continue }
            let monthDate = cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
            let key = monthKey(monthDate)
            // Track actual usage recorded on each coupon (not nominal savings)
            map[key, default: 0] += c.usedValue
        }
        return monthRange.map { m in (m, map[monthKey(m)] ?? 0) }
    }

    private var cumulativeSavings: [(date: Date, value: Double)] {
        var running: Double = 0
        return monthlySavings.map { pair in
            running += pair.value
            return (pair.date, running)
        }
    }

    private var monthlyRemaining: [(date: Date, value: Double)] {
        // Approximation: for each month, sum remaining value of all coupons
        // that existed by that month (added on or before) and are not for sale
        let cal = Calendar.current
        var result: [(Date, Double)] = []
        for m in monthRange {
            let value = coupons
                .filter { !$0.isForSale }
                .filter { c in
                    guard let d = c.dateAddedAsDate else { return false }
                    let md = cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
                    return md <= m
                }
                .map { max(0, $0.value - $0.usedValue) }
                .reduce(0, +)
            result.append((m, value))
        }
        return result
    }

    private var yearlySavings: [(date: Date, value: Double)] {
        // Aggregate actual usage per year
        var map: [String: Double] = [:]
        let cal = Calendar.current
        for c in coupons {
            guard let d = c.dateAddedAsDate else { continue }
            let yearStart = cal.date(from: DateComponents(year: cal.component(.year, from: d), month: 1, day: 1)) ?? d
            map[yearKey(yearStart), default: 0] += c.usedValue
        }
        return yearRange.map { y in (y, map[yearKey(y)] ?? 0) }
    }

    private var yearlyCumulative: [(date: Date, value: Double)] {
        var running: Double = 0
        return yearlySavings.map { pair in
            running += pair.value
            return (pair.date, running)
        }
    }

    // Total face value of coupons held per year (by date added)
    private var yearlyHoldings: [(date: Date, value: Double)] {
        var map: [String: Double] = [:]
        let cal = Calendar.current
        for c in coupons {
            guard let d = c.dateAddedAsDate else { continue }
            let yearStart = cal.date(from: DateComponents(year: cal.component(.year, from: d), month: 1, day: 1)) ?? d
            map[yearKey(yearStart), default: 0] += max(0, c.value)
        }
        return yearRange.map { y in (y, map[yearKey(y)] ?? 0) }
    }

    private var yearlyHoldingsCumulative: [(date: Date, value: Double)] {
        var running: Double = 0
        return yearlyHoldings.map { pair in
            running += pair.value
            return (pair.date, running)
        }
    }

    // Net savings (value - cost) accumulated by year of acquisition
    private var yearlyNetSavings: [(date: Date, value: Double)] {
        var map: [String: Double] = [:]
        let cal = Calendar.current
        for c in coupons where !c.excludeSaving {
            guard let d = c.dateAddedAsDate else { continue }
            let yearStart = cal.date(from: DateComponents(year: cal.component(.year, from: d), month: 1, day: 1)) ?? d
            let net = max(0, c.value - c.cost)
            map[yearKey(yearStart), default: 0] += net
        }
        return yearRange.map { y in (y, map[yearKey(y)] ?? 0) }
    }

    private var yearlyNetCumulative: [(date: Date, value: Double)] {
        var running: Double = 0
        return yearlyNetSavings.map { pair in
            running += pair.value
            return (pair.date, running)
        }
    }

    private var yearlyRemaining: [(date: Date, value: Double)] {
        // Sum remaining value of coupons that exist by each year
        let cal = Calendar.current
        var result: [(Date, Double)] = []
        for y in yearRange {
            let value = coupons
                .filter { !$0.isForSale }
                .filter { c in
                    guard let d = c.dateAddedAsDate else { return false }
                    let yearStart = cal.date(from: DateComponents(year: cal.component(.year, from: d), month: 1, day: 1)) ?? d
                    return yearStart <= y
                }
                .map { max(0, $0.value - $0.usedValue) }
                .reduce(0, +)
            result.append((y, value))
        }
        return result
    }
    
    // Removed old modal statistics; keeping calculations inline in existing views.

    // MARK: - Categories mapping and savings
    enum CouponCategory: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case sports = "ספורט וכושר"
        case digitalGiftCards = "גיפטקארדים דיגיטליים"
        case restaurants = "מסעדות"
        case travelData = "חבילת גלישה בחו״ל"
        case gym = "חדר כושר"
        case pharm = "פארם"
        case home = "בית וריהוט"
        case fashion = "אופנה"
        case coffee = "קפה ומאפה"
        case other = "אחר"
    }

    private func companyCategory(_ name: String) -> CouponCategory {
        let lower = name.lowercased()
        // Dictionary of known mappings (extend as needed)
        let map: [String: CouponCategory] = [
            "buyme": .digitalGiftCards,
            "goodpharm": .pharm,
            "super-pharm": .pharm,
            "dream card": .digitalGiftCards,
            "xgift": .digitalGiftCards,
            "xtra": .digitalGiftCards,
            "freefit": .sports,
            "mega sport": .sports,
            "nike": .sports,
            "fox": .fashion,
            "fox home": .home,
            "carrefour": .restaurants, // groceries → treat as food related
            "wolt": .restaurants,
            "airalo": .travelData,
            "esim": .travelData,
            "ארקיע": .travelData,
            "אל על": .travelData,
            "קפה": .coffee,
            "עלית": .coffee,
            "laline": .pharm,
        ]
        for (key, cat) in map {
            if lower.contains(key) || name.contains(key) { return cat }
        }
        // Heuristics
        if lower.contains("sport") || lower.contains("fit") { return .sports }
        if lower.contains("pharm") || lower.contains("drug") { return .pharm }
        if lower.contains("gift") || lower.contains("card") { return .digitalGiftCards }
        if lower.contains("cafe") || lower.contains("coffee") { return .coffee }
        if lower.contains("wolt") || lower.contains("restaurant") || lower.contains("food") { return .restaurants }
        if lower.contains("air") || lower.contains("sim") || lower.contains("travel") { return .travelData }
        return .other
    }

    private struct CategorySavings { let category: CouponCategory; let totalSavings: Double }
    private var categorySavingsData: [CategorySavings] {
        var sums: [CouponCategory: Double] = [:]
        for c in filteredCoupons {
            let cat = companyCategory(c.company)
            // Count actual usage per period for category breakdowns
            let usage = c.usedValue
            sums[cat, default: 0] += usage
        }
        let arr = sums.map { CategorySavings(category: $0.key, totalSavings: $0.value) }
        return arr.sorted { $0.totalSavings > $1.totalSavings }
    }

    private func computeCategorySavings(from coupons: [Coupon]) -> [CategorySavings] {
        var sums: [CouponCategory: Double] = [:]
        for c in coupons {
            let cat = companyCategory(c.company)
            let usage = c.usedValue
            sums[cat, default: 0] += usage
        }
        let arr = sums.map { CategorySavings(category: $0.key, totalSavings: $0.value) }
        return arr.sorted { $0.totalSavings > $1.totalSavings }
    }

    // Breakdown of companies within a category for the current filtered period
    private func companiesBreakdown(for category: CouponCategory) -> [(company: String, value: Double)] {
        var map: [String: Double] = [:]
        for c in filteredCoupons {
            if companyCategory(c.company) == category {
                map[c.company, default: 0] += c.usedValue
            }
        }
        return map.map { ($0.key, $0.value) }.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                Group {
                    if isLoading {
                        VStack(spacing: 14) {
                            // Indeterminate spinner (keeps the page feeling alive while computing)
                            ProgressView()
                                .progressViewStyle(.circular)
                            // Determinate progress bar updated during precompute
                            ProgressView(value: loadingProgress, total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(.appBlue)
                                .frame(maxWidth: 360)
                            Text(loadingMessage.isEmpty ? "טוען נתונים..." : loadingMessage)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 420)
                    } else {
                        VStack(spacing: 20) {
                            // Date selector (month/year) similar to website
                            timeframeSelector

                            // Summary tiles
                            statisticsGrid

                            // Charts like in the screenshots (removed company bar chart per request)
                            savingsPercentByCategory
                            // Removed per request: hide company pie chart
                            // savingsPercentByCompany
                            cumulativeSavingsChart
                            usageOverTimeSection
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("על מה חסכת?")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("סגור") {
                        dismiss()
                    }
                }
            }
            // Date range picker sheet
            .sheet(isPresented: $showDateRangePicker) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Spacer()
                        Text("בחר טווח תאריכים")
                            .font(.headline)
                        Spacer()
                    }

                    // RTL layout: date on the right, label on the left
                    HStack(spacing: 12) {
                        DatePicker("", selection: $customStartDate, displayedComponents: .date)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("מתאריך")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    HStack(spacing: 12) {
                        DatePicker("", selection: $customEndDate, in: customStartDate...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("עד תאריך")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    HStack {
                        Spacer()
                        Button("אישור") {
                            if customEndDate < customStartDate {
                                // swap if selected in reverse order
                                let tmp = customStartDate
                                customStartDate = customEndDate
                                customEndDate = tmp
                            }
                            selectedTimeframe = .customRange
                            showDateRangePicker = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .environment(\.layoutDirection, .rightToLeft)
                .presentationDetents([.medium])
            }
            .onAppear {
                scheduleRecompute(context: "onAppear")
            }
            // Log and recompute when timeframe changes
            .onChange(of: selectedTimeframe) { _, _ in scheduleRecompute(context: "timeframeChanged") }
            .onChange(of: selectedMonth) { _, _ in scheduleRecompute(context: "monthChanged") }
            .onChange(of: selectedYear) { _, _ in scheduleRecompute(context: "yearChanged") }
            .onChange(of: customStartDate) { _, _ in if selectedTimeframe == .customRange { scheduleRecompute(context: "customStartChanged") } }
            .onChange(of: customEndDate) { _, _ in if selectedTimeframe == .customRange { scheduleRecompute(context: "customEndChanged") } }
        }
    }

    // MARK: - Debug Logging
    private func logBoth(_ message: String) {
        // Route through AppLogger only; avoids console spam unless explicitly enabled.
        AppLogger.log(message)
    }
    private func fmt2(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func logSavingsDebug(context: String) {
        // Print current timeframe selection (only if logging enabled)
        guard AppLogger.isEnabled else { return }
        let tf: String = {
            switch selectedTimeframe {
            case .allTime: return "allTime"
            case .thisYear: return "thisYear(\(selectedYear))"
            case .thisMonth: return "thisMonth(\(selectedMonth)/\(selectedYear))"
            case .customRange:
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                return "custom(\(df.string(from: customStartDate))...\(df.string(from: customEndDate)))"
            }
        }()

        logBoth("🧮 [SavingsDebug] context=\(context) timeframe=\(tf)")

        // Show how many coupons are considered after filtering
        logBoth("🧮 [SavingsDebug] filteredCoupons.count=\(filteredCoupons.count) out of total=\(coupons.count)")
        let nilDates = coupons.filter { $0.dateAddedAsDate == nil }.count
        if nilDates > 0 {
            logBoth("⚠️ [SavingsDebug] coupons with unparsable date_added=\(nilDates)")
            var shown = 0
            for c in coupons where c.dateAddedAsDate == nil {
                logBoth("   • unparsable date_added='\(c.dateAdded)' id=\(c.id)")
                shown += 1
                if shown >= 5 { break }
            }
        }

        // Recreate the inputs that feed the chart "קופונים פעילים ומנוצלים לפי חברה"
        var perCompany: [String: (active: Int, used: Int, total: Int, totalSavings: Double, totalValue: Double)] = [:]
        for c in filteredCoupons {
            var row = perCompany[c.company] ?? (0, 0, 0, 0, 0)
            row.total += 1
            if !c.isExpired && !c.isFullyUsed { row.active += 1 }
            if c.usedValue > 0 { row.used += 1 }
            row.totalSavings += c.usedValue
            row.totalValue += c.remainingValue
            perCompany[c.company] = row
        }
        // Dump a compact, deterministic listing sorted by name
        for (k, v) in perCompany.sorted(by: { $0.key < $1.key }) {
            logBoth("   • \(k): active=\(v.active), used=\(v.used), total=\(v.total), savings=\(Int(v.totalSavings)), remaining=\(Int(v.totalValue))")
        }
        if perCompany.isEmpty { AppLogger.log("   • No data for current timeframe") }

        // Note: The base data is fetched via Supabase REST from the `coupon` table.
        // The request URL (no pagination) is logged in CouponAPIClient.fetchAllUserCoupons.
        logBoth("🔎 [SavingsDebug] source=Supabase table 'coupon' → all user coupons; client applies timeframe filter above.")
    }

    // Debounced recomputation entry point
    private func scheduleRecompute(context: String) {
        logSavingsDebug(context: context)
        // Cancel any pending recompute to debounce rapid changes
        recomputeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.precomputeAll()
            self?.rebuildTooltipCaches()
        }
        recomputeWorkItem = work
        // Small delay smooths UI when user changes multiple controls quickly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    // MARK: - Timeframe Selector
    private var timeframeSelector: some View {
        VStack(spacing: 16) {
            // Align header to the right in RTL by using leading
            Text("בחר טווח זמן לניתוח")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Buttons centered with calendar pinned to the side
            ZStack {
                // Centered segmented buttons
                HStack(spacing: 12) {
                    ForEach([TimeframeFilter.thisMonth, .thisYear, .allTime], id: \.self) { timeframe in
                        Button(action: { selectedTimeframe = timeframe }) {
                            Text(timeframe.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedTimeframe == timeframe ? Color.appBlue : Color(.systemBackground))
                                .foregroundColor(selectedTimeframe == timeframe ? .white : .primary)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.appBlue.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Calendar pinned to leading side (RTL-aware layout places it visually left)
                HStack {
                    Button(action: { showDateRangePicker = true }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(10)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.appBlue.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("בחר טווח תאריכים")
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Stats Grid (like website)
    private var statisticsGrid: some View {
        // Use leading alignment so in RTL locales (Hebrew) the title appears on the right.
        VStack(alignment: .leading, spacing: 12) {
            Text("סיכום כללי")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MiniStatCard(title: "קופונים חדשים", value: "\(newCouponsCount)", description: selectedTimeframe == .thisYear ? "קופונים שנוספו השנה" : (selectedTimeframe == .thisMonth ? "קופונים שנוספו החודש" : "סה״כ קופונים"))
                MiniStatCard(title: "חיסכון כולל", value: "₪\(Int(totalSavingsForPeriod))", description: selectedTimeframe == .thisMonth ? "(כמה כסף חסכת החודש)" : (selectedTimeframe == .thisYear ? "חיסכון נומינלי מצטבר" : "חיסכון נומינלי"))
                MiniStatCard(title: "אחוז חיסכון", value: "\(Int(averageSavingsPercentPerNewCoupon))%", description: "אחוז חיסכון בממוצע לקופון")
                MiniStatCard(title: "ערך פעיל", value: "₪\(Int(totalActiveValue))", description: "ערך כולל בקופונים פעילים")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    // MARK: - Usage Card with stacked bar
    private var usageCard: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("ניצול קופונים")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .trailing)

            HStack {
                Text("\(usagePercentageString)%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.appBlue)
                Spacer()
                Text(selectedTimeframe == .thisYear ? "אחוז הקופונים שנוצלו במלואם השנה" : selectedTimeframe == .thisMonth ? "אחוז הקופונים שנוצלו במלואם החודש" : "אחוז הקופונים שנוצלו במלואם")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Stacked bar similar to the web page
            GeometryReader { geo in
                let total = max(1, usageStats.total)
                let fullyW = geo.size.width * CGFloat(usageStats.fully) / CGFloat(total)
                let partialW = geo.size.width * CGFloat(usageStats.partial) / CGFloat(total)
                let unusedW = geo.size.width * CGFloat(usageStats.unused) / CGFloat(total)
                HStack(spacing: 2) {
                    if usageStats.fully > 0 {
                        RoundedRectangle(cornerRadius: 4).fill(Color.green).frame(width: fullyW, height: 16)
                    }
                    if usageStats.partial > 0 {
                        RoundedRectangle(cornerRadius: 4).fill(Color.yellow.opacity(0.8)).frame(width: partialW, height: 16)
                    }
                    if usageStats.unused > 0 {
                        RoundedRectangle(cornerRadius: 4).fill(Color.red).frame(width: unusedW, height: 16)
                    }
                }
            }
            .frame(height: 16)

            HStack(spacing: 12) {
                LegendDot(color: .green, text: "\(usageStats.fully) נוצלו במלואם")
                LegendDot(color: .yellow, text: "\(usageStats.partial) נוצלו חלקית")
                LegendDot(color: .red, text: "\(usageStats.unused) לא נוצלו")
                Spacer()
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private var usagePercentageString: String {
        let pct = usageStats.total > 0 ? (Double(usageStats.fully) / Double(usageStats.total)) * 100 : 0
        return String(format: "%.0f", pct)
    }

    // MARK: - Popular companies list
    private var popularCompaniesCard: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("החברות הפופולריות")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if popularCompanies.isEmpty {
                Text(selectedTimeframe == .thisYear ? "אין נתוני שימוש השנה" : selectedTimeframe == .thisMonth ? "אין נתוני שימוש החודש" : "אין נתוני שימוש")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(popularCompanies.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text("\(item.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.appBlue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            Spacer(minLength: 8)
                            Text(item.name)
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                        .overlay(Divider(), alignment: .bottom)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    // MARK: - Comparison card
    private var comparisonCard: some View {
        Group {
            if let comp = comparisonStats {
                VStack(alignment: .trailing, spacing: 12) {
                    Text(selectedTimeframe == .thisYear ? "השוואה לשנה קודמת" : "השוואה לחודש קודם")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack {
                        Text("קופונים:")
                        Spacer()
                        Text("\(comp.couponsDelta >= 0 ? "+" : "")\(comp.couponsDelta)")
                            .foregroundColor(comp.couponsDelta > 0 ? .green : (comp.couponsDelta < 0 ? .red : .secondary))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .padding(.vertical, 4)
                    .overlay(Divider(), alignment: .bottom)

                    HStack {
                        Text("חיסכון:")
                        Spacer()
                        Text("₪\(comp.savingsDelta > 0 ? "+" : "")\(Int(comp.savingsDelta))")
                            .foregroundColor(comp.savingsDelta > 0 ? .green : (comp.savingsDelta < 0 ? .red : .secondary))
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
    }

    // MARK: - Alerts card
    private var alertsCard: some View {
        VStack(spacing: 10) {
            Text("התראות")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if expiringNextMonth > 0 {
                HStack {
                    Text("⚠️ \(expiringNextMonth) קופונים פגים תוקף החודש הבא!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.orange)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Button("צפה בקופונים") {
                        // Could navigate to coupons list with filter when available
                        dismiss()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.bordered)
                }
            } else {
                Text("אין התראות כרגע")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Companies Breakdown (Original Design)
    private var companiesBreakdownSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Color.appBlue)
                Spacer()
                Text("פירוט החיסכון לפי חברות")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            if companySavingsData.isEmpty {
                Text("אין נתונים להצגה")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(companySavingsData.prefix(10), id: \.company) { companyData in
                        CompanyBreakdownRow(companyData: companyData)
                    }
                }
            }
        }
    }

    // MARK: - Savings by Company Table (web‑like)
    private var companiesSavingsTable: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("פירוט החיסכון לפי חברות")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if companySavingsData.isEmpty {
                Text("אין נתונים להצגה")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                // Header row
                HStack {
                    Text("חברה").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("אחוז חיסכון").frame(width: 90, alignment: .center)
                    Text("סה\"כ חיסכון").frame(width: 110, alignment: .center)
                    Text("סה\"כ קופונים").frame(width: 90, alignment: .center)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Divider()

                LazyVStack(spacing: 10) {
                    ForEach(companySavingsData, id: \.company) { row in
                        HStack(alignment: .center) {
                            // Company name
                            Text(row.company)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            // Savings % per company (savings / (savings + remainingValue))
                            let denom = max(row.totalSavings + row.totalValue, 1)
                            let pct = (row.totalSavings / denom) * 100
                            Text("\(String(format: "%.1f", pct))%")
                                .frame(width: 90, alignment: .center)

                            // Total savings currency
                            Text("₪\(Int(row.totalSavings))")
                                .foregroundColor(.green)
                                .frame(width: 110, alignment: .center)

                            // Total coupons count
                            Text("\(row.totalCoupons)")
                                .frame(width: 90, alignment: .center)
                        }
                        .padding(.vertical, 6)
                        .background(Color(.systemBackground))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Charts Section  
    private var chartsSection: some View {
        VStack(spacing: 20) {
            // Active vs Used Coupons Chart (Bar Chart)
            activeVsUsedChart
            
            // Companies Distribution Chart 
            companiesDistributionChart
        }
    }
    
    // MARK: - Active vs Used Chart
    private var activeVsUsedChart: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Text("קופונים פעילים ומנוצלים לפי חברה")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(companySavingsData.prefix(6), id: \.company) { companyData in
                        BarMark(
                            x: .value("Company", companyData.company),
                            y: .value("Active", companyData.activeCoupons)
                        )
                        .foregroundStyle(Color.appBlue)
                        .opacity(0.8)
                        
                        BarMark(
                            x: .value("Company", companyData.company),
                            y: .value("Used", companyData.usedCoupons)
                        )
                        .foregroundStyle(.green)
                        .opacity(0.8)
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel() {
                            if let company = value.as(String.self) {
                                Text(company)
                                    .font(.caption)
                                    .rotationEffect(.degrees(-45))
                            }
                        }
                    }
                }
                .chartLegend(position: .top, alignment: .trailing) {
                    HStack {
                        Label("קופונים פעילים", systemImage: "square.fill")
                            .foregroundColor(Color.appBlue)
                        Label("קופונים מנוצלים", systemImage: "square.fill")
                            .foregroundColor(.green)
                    }
                    .font(.caption)
                }
            } else {
                // Fallback bar chart for iOS 15
                fallbackBarChart
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Fallback Bar Chart for iOS 15
    private var fallbackBarChart: some View {
        VStack(spacing: 8) {
            // Legend
            HStack {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.appBlue)
                        .frame(width: 12, height: 12)
                    Text("קופונים פעילים")
                        .font(.caption)
                }
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                    Text("קופונים מנוצלים")
                        .font(.caption)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Chart area
            VStack(spacing: 4) {
                ForEach(companySavingsData.prefix(6), id: \.company) { companyData in
                    HStack {
                        Text(companyData.company)
                            .font(.caption)
                            .frame(width: 80, alignment: .trailing)
                        
                        VStack(spacing: 2) {
                            // Active coupons bar
                            HStack {
                                Rectangle()
                                    .fill(Color.appBlue.opacity(0.8))
                                    .frame(width: CGFloat(companyData.activeCoupons * 8), height: 12)
                                Text("\(companyData.activeCoupons)")
                                    .font(.caption2)
                                    .foregroundColor(Color.appBlue)
                                Spacer()
                            }
                            
                            // Used coupons bar  
                            HStack {
                                Rectangle()
                                    .fill(Color.green.opacity(0.8))
                                    .frame(width: CGFloat(companyData.usedCoupons * 8), height: 12)
                                Text("\(companyData.usedCoupons)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }

    // MARK: - Companies Distribution Chart
    private var companiesDistributionChart: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                        Text("התפלגות שימוש בפועל לפי חברות")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(companySavingsData.prefix(8), id: \.company) { companyData in
                        SectorMark(
                            angle: .value("Savings", companyData.totalSavings),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Company", companyData.company))
                        .opacity(0.8)
                    }
                }
                .frame(height: 200)
                .chartLegend(position: .bottom, alignment: .center)
            } else {
                // Fallback pie chart for iOS 15
                fallbackPieChart
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    // MARK: - Percent Savings by Category (Pie)
    @State private var showCategoryTable = false
    @State private var categoryCompaniesTarget: CouponCategory? = nil
    private var savingsPercentByCategory: some View {
        VStack(spacing: 12) {
            HStack { Text("אחוז שימוש בפועל לפי קטגוריות").font(.headline).fontWeight(.semibold); Spacer(); Button(action: { showCategoryTable = true }) { Label("טבלה", systemImage: "tablecells").labelStyle(.titleAndIcon) }.buttonStyle(.bordered) }
            if #available(iOS 16.0, *) {
                Chart(precomputedCategorySavings, id: \.category.id) { row in
                    SectorMark(
                        angle: .value("Savings", row.totalSavings),
                        innerRadius: .ratio(0.55), angularInset: 1.5
                    )
                    .foregroundStyle(getCategoryColor(row.category))
                }
                .frame(height: 220)

                // Explicit legend (precomputed) below the chart
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(precomputedCategorySavings, id: \.category.id) { row in
                        HStack(spacing: 6) {
                            Circle().fill(getCategoryColor(row.category)).frame(width: 10, height: 10)
                            Text(row.category.rawValue)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text("דורש iOS 16 ומעלה להצגת גרף")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showCategoryTable) {
            let total = max(precomputedCategorySavings.reduce(0) { $0 + $1.totalSavings }, 1)
            VStack(alignment: .trailing, spacing: 12) {
                HStack { Spacer(); Text("טבלת אחוז שימוש לפי קטגוריות").font(.headline).fontWeight(.semibold) }
                // Force LTR for deterministic column order: [Percent | Value | Category]
                HStack {
                    Text("אחוז").frame(width: 80, alignment: .trailing)
                    Text("שווי").frame(width: 100, alignment: .trailing)
                    Text("קטגוריה").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .environment(\.layoutDirection, .leftToRight)
                .font(.caption)
                .foregroundColor(.secondary)
                Divider()
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 8) {
                        ForEach(precomputedCategorySavings, id: \.category.id) { row in
                            let pct = (row.totalSavings / total) * 100
                            // Match header order and force LTR so the category appears visually on the right
                            HStack {
                                Text("\(String(format: "%.1f", pct))%").frame(width: 80, alignment: .trailing)
                                Text(currency(row.totalSavings)).frame(width: 100, alignment: .trailing)
                                Text(row.category.rawValue).frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .environment(\.layoutDirection, .leftToRight)
                            .padding(.vertical, 2)
                            .overlay(Divider(), alignment: .bottom)
                            .contentShape(Rectangle())
                            .onTapGesture { categoryCompaniesTarget = row.category }
                        }
                    }
                }
            }
            .padding()
            .environment(\.layoutDirection, .rightToLeft)
            .presentationDetents([.medium, .large])
            // Drilldown: companies within the selected category
            .sheet(isPresented: Binding(get: { categoryCompaniesTarget != nil }, set: { if !$0 { categoryCompaniesTarget = nil } })) {
                VStack(alignment: .trailing, spacing: 12) {
                    if let target = categoryCompaniesTarget {
                        let rows = companiesBreakdown(for: target)
                        let totalCat = max(rows.reduce(0) { $0 + $1.value }, 1)
                        // Align title to the right in RTL
                        Text("פירוט חברות — \(target.rawValue)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // Header: [Percent | Value | Company]
                        HStack {
                            Text("אחוז").frame(width: 80, alignment: .trailing)
                            Text("שווי").frame(width: 100, alignment: .trailing)
                            Text("חברה").frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        Divider()
                        ScrollView {
                            LazyVStack(alignment: .trailing, spacing: 8) {
                                ForEach(rows, id: \.company) { item in
                                    let pct = (item.value / totalCat) * 100
                                    HStack {
                                        Text(String(format: "%.1f%%", pct)).frame(width: 80, alignment: .trailing)
                                        Text(currency(item.value)).frame(width: 100, alignment: .trailing)
                                        Text(item.company).frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    .environment(\.layoutDirection, .leftToRight)
                                    .padding(.vertical, 2)
                                    .overlay(Divider(), alignment: .bottom)
                                }
                            }
                        }
                    }
                }
                .padding()
                .environment(\.layoutDirection, .rightToLeft)
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Savings Percent By Company (Pie)
    @State private var showCompanyTable = false
    private var savingsPercentByCompany: some View {
        VStack(spacing: 12) {
            HStack { Text("אחוז שימוש בפועל לפי חברה").font(.headline).fontWeight(.semibold); Spacer(); Button(action: { showCompanyTable = true }) { Label("טבלה", systemImage: "tablecells").labelStyle(.titleAndIcon) }.buttonStyle(.bordered) }
            if #available(iOS 16.0, *) {
                // Use a deterministic color palette by index for BOTH the chart and legend
                let companyRows = Array(companySavingsData.prefix(12).enumerated())
                Chart(companyRows, id: \.element.company) { index, row in
                    SectorMark(
                        angle: .value("Savings", row.totalSavings),
                        innerRadius: .ratio(0.55), angularInset: 1.5
                    )
                    .foregroundStyle(getCompanyColor(for: index))
                }
                .frame(height: 220)
                let rows = Array(companySavingsData.prefix(12).enumerated())
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(rows, id: \.element.company) { index, row in
                        HStack(spacing: 6) {
                            Circle().fill(getCompanyColor(for: index)).frame(width: 10, height: 10)
                            Text(row.company)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text("דורש iOS 16 ומעלה להצגת גרף")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showCompanyTable) {
            let total = max(companySavingsData.reduce(0) { $0 + $1.totalSavings }, 1)
            VStack(alignment: .trailing, spacing: 12) {
                HStack { Spacer(); Text("טבלת אחוז שימוש לפי חברה").font(.headline).fontWeight(.semibold) }
                // Force LTR for deterministic column order: [Percent | Value | Company]
                HStack {
                    Text("אחוז").frame(width: 80, alignment: .trailing)
                    Text("שווי").frame(width: 100, alignment: .trailing)
                    Text("חברה").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .environment(\.layoutDirection, .leftToRight)
                .font(.caption)
                .foregroundColor(.secondary)
                Divider()
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 8) {
                        ForEach(companySavingsData, id: \.company) { row in
                            let pct = (row.totalSavings / total) * 100
                            // Match header order and force LTR so the company appears visually on the right
                            HStack {
                                Text("\(String(format: "%.1f", pct))%").frame(width: 80, alignment: .trailing)
                                Text(currency(row.totalSavings)).frame(width: 100, alignment: .trailing)
                                Text(row.company).frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .environment(\.layoutDirection, .leftToRight)
                            .padding(.vertical, 2)
                            .overlay(Divider(), alignment: .bottom)
                        }
                    }
                }
            }
            .padding()
            .environment(\.layoutDirection, .rightToLeft)
            .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Helpers for formatting and table rows
    private func currency(_ v: Double) -> String { "₪" + fmt2(v) }
    private var holdingsTableRows: [(year: String, added: Double, cumulative: Double)] {
        switch selectedTimeframe {
        case .allTime:
            let perYear = yearlyHoldings
            let cum = yearlyHoldingsCumulative
            return zip(perYear, cum).map { (yearText($0.0.date), $0.0.value, $0.1.value) }
        case .thisYear:
            let map = aggregateHoldingsByMonth(in: selectedYear)
            var run = 0.0
            return map.map { label, value in run += value; return (label, value, run) }
        case .thisMonth:
            let map = aggregateHoldingsByWeekOfMonth(year: selectedYear, month: selectedMonth)
            var run = 0.0
            return map.map { label, value in run += value; return (label, value, run) }
        case .customRange:
            let map = aggregateHoldingsByMonth(in: selectedYear)
            var run = 0.0
            return map.map { label, value in run += value; return (label, value, run) }
        }
    }
    private var netTableRows: [(year: String, added: Double, cumulative: Double)] {
        switch selectedTimeframe {
        case .allTime:
            let perYear = yearlyNetSavings
            let cum = yearlyNetCumulative
            return zip(perYear, cum).map { (yearText($0.0.date), $0.0.value, $0.1.value) }
        case .thisYear:
            let map = aggregateNetByMonth(in: selectedYear)
            var run = 0.0
            return map.map { label, value in run += value; return (label, value, run) }
        case .thisMonth:
            let map = aggregateNetByWeekOfMonth(year: selectedYear, month: selectedMonth)
            var run = 0.0
            return map.map { label, value in run += value; return (label, value, run) }
        case .customRange:
            let map = aggregateNetByMonth(in: selectedYear)
            var run = 0.0
            return map.map { label, value in run += value; return (label, value, run) }
        }
    }

    // MARK: - Drilldown helpers
    private func holdingsByCompany(in year: Int) -> [(company: String, value: Double)] {
        var map: [String: Double] = [:]
        let cal = Calendar.current
        for c in coupons {
            guard let d = c.dateAddedAsDate else { continue }
            if cal.component(.year, from: d) == year {
                map[c.company, default: 0] += max(0, c.value)
            }
        }
        return map.map { ($0.key, $0.value) }.sorted { $0.value > $1.value }
    }
    private func netByCompany(in year: Int) -> [(company: String, value: Double)] {
        var map: [String: Double] = [:]
        let cal = Calendar.current
        for c in coupons where !c.excludeSaving {
            guard let d = c.dateAddedAsDate else { continue }
            if cal.component(.year, from: d) == year {
                let net = max(0, c.value - c.cost)
                map[c.company, default: 0] += net
            }
        }
        return map.map { ($0.key, $0.value) }.sorted { $0.value > $1.value }
    }

    private func holdingsDrillTitle(_ target: DrillTarget) -> String {
        switch target {
        case .year(let y): return "פירוט שווי לפי חברות — \(y)"
        case .month(let y, let m): return "פירוט שווי לפי חברות — \(monthLabel(m)) \(y)"
        case .week(let y, let m, let w): return "פירוט שווי לפי חברות — שבוע \(w) \(monthLabel(m)) \(y)"
        }
    }
    private func netDrillTitle(_ target: DrillTarget) -> String {
        switch target {
        case .year(let y): return "פירוט חיסכון נטו לפי חברות — \(y)"
        case .month(let y, let m): return "פירוט חיסכון נטו לפי חברות — \(monthLabel(m)) \(y)"
        case .week(let y, let m, let w): return "פירוט חיסכון נטו לפי חברות — שבוע \(w) \(monthLabel(m)) \(y)"
        }
    }
    private func couponsFor(target: DrillTarget) -> [Coupon] {
        let cal = Calendar.current
        switch target {
        case .year(let y):
            return coupons.compactMap { c in
                guard let d = c.dateAddedAsDate else { return nil }
                return cal.component(.year, from: d) == y ? c : nil
            }
        case .month(let y, let m):
            return coupons.compactMap { c in
                guard let d = c.dateAddedAsDate else { return nil }
                let comps = cal.dateComponents([.year, .month], from: d)
                return (comps.year == y && comps.month == m) ? c : nil
            }
        case .week(let y, let m, let w):
            return coupons.compactMap { c in
                guard let d = c.dateAddedAsDate else { return nil }
                let comps = cal.dateComponents([.year, .month, .weekOfMonth], from: d)
                return (comps.year == y && comps.month == m && comps.weekOfMonth == w) ? c : nil
            }
        }
    }

    private func holdingsByCompany(target: DrillTarget) -> [(company: String, value: Double)] {
        var map: [String: Double] = [:]
        for c in couponsFor(target: target) {
            map[c.company, default: 0] += max(0, c.value)
        }
        return map.map { ($0.key, $0.value) }.sorted { $0.value > $1.value }
    }

    private func netByCompany(target: DrillTarget) -> [(company: String, value: Double)] {
        var map: [String: Double] = [:]
        for c in couponsFor(target: target) where !c.excludeSaving {
            let net = max(0, c.value - c.cost)
            map[c.company, default: 0] += net
        }
        return map.map { ($0.key, $0.value) }.sorted { $0.value > $1.value }
    }

    // MARK: - Aggregations by period for current selection
    private func monthLabel(_ month: Int) -> String {
        let df = DateFormatter(); df.locale = Locale(identifier: "he_IL");
        let comps = DateComponents(year: selectedYear, month: month, day: 1)
        let d = Calendar.current.date(from: comps) ?? Date()
        df.dateFormat = "LLL"; return df.string(from: d)
    }
    private func aggregateHoldingsByMonth(in year: Int) -> [(String, Double)] {
        var sums = Array(repeating: 0.0, count: 12)
        for c in filteredCoupons {
            guard let d = c.dateAddedAsDate else { continue }
            if Calendar.current.component(.year, from: d) == year {
                let m = Calendar.current.component(.month, from: d)
                if (1...12).contains(m) { sums[m-1] += max(0, c.value) }
            }
        }
        return (1...12).map { (monthLabel($0), sums[$0-1]) }
    }
    private func aggregateNetByMonth(in year: Int) -> [(String, Double)] {
        var sums = Array(repeating: 0.0, count: 12)
        for c in filteredCoupons where !c.excludeSaving {
            guard let d = c.dateAddedAsDate else { continue }
            if Calendar.current.component(.year, from: d) == year {
                let m = Calendar.current.component(.month, from: d)
                if (1...12).contains(m) { sums[m-1] += max(0, c.value - c.cost) }
            }
        }
        return (1...12).map { (monthLabel($0), sums[$0-1]) }
    }
    private func aggregateHoldingsByWeekOfMonth(year: Int, month: Int) -> [(String, Double)] {
        var sums: [Int: Double] = [:]
        for c in filteredCoupons {
            guard let d = c.dateAddedAsDate else { continue }
            let comps = Calendar.current.dateComponents([.year, .month, .weekOfMonth], from: d)
            if comps.year == year && comps.month == month {
                let w = comps.weekOfMonth ?? 0
                sums[w, default: 0] += max(0, c.value)
            }
        }
        let maxW = (sums.keys.max() ?? 0)
        return (1...max(1, maxW)).map { ("שבוע \($0)", sums[$0] ?? 0) }
    }
    private func aggregateNetByWeekOfMonth(year: Int, month: Int) -> [(String, Double)] {
        var sums: [Int: Double] = [:]
        for c in coupons {
            guard let d = c.dateAddedAsDate else { continue }
            let comps = Calendar.current.dateComponents([.year, .month, .weekOfMonth], from: d)
            if comps.year == year && comps.month == month {
                let w = comps.weekOfMonth ?? 0
                if !c.excludeSaving { sums[w, default: 0] += max(0, c.value - c.cost) }
            }
        }
        let maxW = (sums.keys.max() ?? 0)
        return (1...max(1, maxW)).map { ("שבוע \($0)", sums[$0] ?? 0) }
    }
    private func firstColumnHeader() -> String {
        switch selectedTimeframe {
        case .allTime: return "שנה"
        case .thisYear, .customRange: return "חודש"
        case .thisMonth: return "שבוע"
        }
    }

    // MARK: - Cumulative Holdings Over Time
    @State private var showHoldingsTable = false
    private enum DrillTarget { case year(Int), month(year: Int, month: Int), week(year: Int, month: Int, week: Int) }
    @State private var holdingsDrillTarget: DrillTarget? = nil
    private var cumulativeSavingsChart: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("שווי קופונים מצטבר לאורך זמן")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showHoldingsTable = true }) {
                    Label("טבלה", systemImage: "tablecells")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
            }
            if #available(iOS 16.0, *) {
                if selectedTimeframe == .allTime, let domain = yearlyRTLDoman {
                    Chart(yearlyHoldingsCumulativePoints, id: \.date) { point in
                        AreaMark(
                            x: .value("Date", rtlX(point.date)),
                            y: .value("Cumulative", point.value)
                        )
                        .foregroundStyle(Color.purple.opacity(0.25).gradient)
                        
                        LineMark(
                            x: .value("Date", rtlX(point.date)),
                            y: .value("Cumulative", point.value)
                        )
                        .foregroundStyle(Color.purple)
                        .symbol(.circle)
                    }
                    .chartXScale(domain: domain)
                    .chartXAxis {
                        AxisMarks(values: yearlyRTLTicks) { val in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel() {
                                if let raw = val.as(Double.self) {
                                    Text(yearText(dateFromRTL(raw)))
                                }
                            }
                        }
                    }
                    .chartYAxis { AxisMarks(position: .trailing) }
                    .frame(height: 220)
                } else if selectedTimeframe == .allTime {
                    Chart(yearlyHoldingsCumulativePoints, id: \.date) { point in
                        AreaMark(
                            x: .value("Date", rtlX(point.date)),
                            y: .value("Cumulative", point.value)
                        )
                        .foregroundStyle(Color.purple.opacity(0.25).gradient)
                        
                        LineMark(
                            x: .value("Date", rtlX(point.date)),
                            y: .value("Cumulative", point.value)
                        )
                        .foregroundStyle(Color.purple)
                        .symbol(.circle)
                    }
                    .chartXAxis {
                        AxisMarks(values: yearlyRTLTicks) { val in
                            AxisGridLine(); AxisTick()
                            AxisValueLabel() {
                                if let raw = val.as(Double.self) { Text(yearText(dateFromRTL(raw))) }
                            }
                        }
                    }
                    .chartYAxis { AxisMarks(position: .trailing) }
                    .frame(height: 220)
                } else {
                    let data: [(String, Double)] = {
                        switch selectedTimeframe {
                        case .thisMonth: return aggregateHoldingsByWeekOfMonth(year: selectedYear, month: selectedMonth)
                        case .thisYear, .customRange: return aggregateHoldingsByMonth(in: selectedYear)
                        case .allTime: return []
                        }
                    }()
                    Chart(data, id: \.0) { item in
                        LineMark(
                            x: .value("Bucket", item.0),
                            y: .value("Holdings", item.1)
                        )
                        .foregroundStyle(Color.purple)
                        .symbol(.circle)
                    }
                    .frame(height: 220)
                }
            } else {
                Text("דורש iOS 16 ומעלה להצגת גרף")
                .foregroundColor(.secondary)
            }
        }
        // Make headers and layout RTL
        .environment(\.layoutDirection, SwiftUI.LayoutDirection.rightToLeft)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showHoldingsTable) {
            VStack(alignment: .trailing, spacing: 12) {
                HStack { Spacer(); Text("טבלת שווי קופונים מצטבר") .font(.headline) .fontWeight(.semibold) }
                // Force LTR inside the row to control column order.
                // Visual RTL: [Period | Yearly | Cumulative]
                HStack {
                    Text("מצטבר").frame(width: 120, alignment: .trailing)
                    Text("שנתי").frame(width: 100, alignment: .trailing)
                    Text(firstColumnHeader()).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .environment(\.layoutDirection, .leftToRight)
                .font(.caption)
                .foregroundColor(.secondary)
                Divider()
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 8) {
                        ForEach(Array(holdingsTableRows.enumerated()), id: \.offset) { idx, row in
                            // Force LTR for deterministic order matching header
                            HStack {
                                Text(currency(row.cumulative)).frame(width: 120, alignment: .trailing)
                                Text(currency(row.added)).frame(width: 100, alignment: .trailing)
                                Text(row.year).frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .environment(\.layoutDirection, .leftToRight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                switch selectedTimeframe {
                                case .allTime:
                                    if let y = Int(row.year) { holdingsDrillTarget = .year(y) }
                                case .thisYear, .customRange:
                                    holdingsDrillTarget = .month(year: selectedYear, month: idx + 1)
                                case .thisMonth:
                                    holdingsDrillTarget = .week(year: selectedYear, month: selectedMonth, week: idx + 1)
                                }
                            }
                            .padding(.vertical, 2)
                            .overlay(Divider(), alignment: .bottom)
                        }
                    }
                }
            }
            .padding()
            .environment(\.layoutDirection, .rightToLeft)
            .presentationDetents([.medium, .large])
            .sheet(isPresented: Binding(get: { holdingsDrillTarget != nil }, set: { if !$0 { holdingsDrillTarget = nil } })) {
                VStack(alignment: .trailing, spacing: 12) {
                    if let target = holdingsDrillTarget {
                        HStack { Spacer(); Text(holdingsDrillTitle(target)).font(.headline).fontWeight(.semibold) }
                        // Force table header to LTR so columns appear as: [Yearly | Company] visually right-aligned
                        HStack { 
                            Text("שנתי").frame(width: 120, alignment: .trailing)
                            Text("חברה").frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        Divider()
                        ScrollView {
                            LazyVStack(alignment: .trailing, spacing: 8) {
                                ForEach(holdingsByCompany(target: target), id: \.company) { row in
                                    // Force LTR: value column on the left, company column on the right
                                    HStack {
                                        Text(currency(row.value)).frame(width: 120, alignment: .trailing)
                                        Text(row.company).frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    .environment(\.layoutDirection, .leftToRight)
                                    .padding(.vertical, 2)
                                    .overlay(Divider(), alignment: .bottom)
                                }
                            }
                        }
                    }
                }
                .padding()
                .environment(\.layoutDirection, .rightToLeft)
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Net Savings Over Time (Cumulative)
    @State private var showNetTable = false
    @State private var netDrillTarget: DrillTarget? = nil
    private var usageOverTimeSection: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(spacing: 8) {
                Text("חיסכון נטו מצטבר לאורך זמן")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showNetTable = true }) {
                    Label("טבלה", systemImage: "tablecells")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
            }
            
            if #available(iOS 16.0, *) {
                // Tooltip state
                let _ = ()
                if selectedTimeframe == .allTime, let domain = yearlyRTLDoman {
                    Chart {
                        ForEach(yearlyNetCumulativePoints, id: \.date) { point in
                            LineMark(
                                x: .value("Date", rtlX(point.date)),
                                y: .value("NetSavings", point.value)
                            )
                            .foregroundStyle(Color.blue)
                            .symbol(.circle)
                        }
                        if let sel = usageSelection {
                            RuleMark(x: .value("Date", rtlX(sel.date)))
                                .foregroundStyle(Color.blue.opacity(0.4))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                                .annotation(position: .topTrailing) {
                                    Text("\(yearText(sel.date)) • ₪\(fmt2(sel.value))")
                                        .font(.caption2)
                                        .padding(6)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(6)
                                        .shadow(radius: 1)
                                }
                        }
                    }
                    .chartXScale(domain: domain)
                    .chartXAxis {
                        AxisMarks(values: yearlyRTLTicks) { val in
                            AxisGridLine(); AxisTick()
                            AxisValueLabel() {
                                if let raw = val.as(Double.self) { Text(yearText(dateFromRTL(raw))) }
                            }
                        }
                    }
                    .chartYAxis { AxisMarks(position: .trailing) }
                    .frame(height: 240)
                    .chartLegend(position: .bottom) { LegendDot(color: .blue, text: "חיסכון שנתי (ש״ח)") }
                    .overlay(alignment: .topTrailing) {
                        if let sel = usageSelection {
                            let txt = "\(yearText(sel.date)) • ₪\(fmt2(sel.value))"
                            Text(txt)
                                .font(.caption)
                                .padding(6)
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(6)
                                .shadow(radius: 1)
                                .padding(.trailing, 8)
                                .padding(.top, 8)
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            if let anchor = proxy.plotFrame {
                                                let xPos = value.location.x - geo[anchor].origin.x
                                                if let xVal: Double = proxy.value(atX: xPos) {
                                                    let tappedDate = dateFromRTL(xVal)
                                                    let nearest = yearlyNetCumulativePoints.min(by: { abs($0.date.timeIntervalSince1970 - tappedDate.timeIntervalSince1970) < abs($1.date.timeIntervalSince1970 - tappedDate.timeIntervalSince1970) })
                                                    if let pick = nearest {
                                                        AppLogger.log("📊 [NetSavingsTap] year=\(yearText(pick.date)) value=\(fmt2(pick.value))")
                                                        DispatchQueue.main.async { self.usageSelection = pick }
                                                    }
                                                }
                                            }
                                        }
                                        .onEnded { _ in }
                                )
                        }
                    }
                    .chartOverlay { proxy in
                        // Simple tap to log exact point
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { _ in }
                    }
                } else {
                    // Weekly or Monthly comparison (non-cumulative)
                    let data: [(String, Double)] = {
                        switch selectedTimeframe {
                        case .thisMonth: return aggregateNetByWeekOfMonth(year: selectedYear, month: selectedMonth)
                        case .thisYear, .customRange: return aggregateNetByMonth(in: selectedYear)
                        case .allTime: return []
                        }
                    }()
                    Chart(data, id: \.0) { item in
                        LineMark(
                            x: .value("Bucket", item.0),
                            y: .value("Net", item.1)
                        )
                        .foregroundStyle(Color.blue)
                        .symbol(.circle)
                    }
                    .frame(height: 240)
                }
            } else {
                Text("דורש iOS 16 ומעלה להצגת גרף")
                    .foregroundColor(.secondary)
            }
        }
        .environment(\.layoutDirection, SwiftUI.LayoutDirection.rightToLeft)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showNetTable) {
            VStack(alignment: .trailing, spacing: 12) {
                HStack { Spacer(); Text("טבלת חיסכון נטו מצטבר").font(.headline).fontWeight(.semibold) }
                // Force LTR inside the row to control column order.
                // Visual RTL: [Period | Yearly | Cumulative]
                HStack {
                    Text("מצטבר").frame(width: 120, alignment: .trailing)
                    Text("שנתי").frame(width: 100, alignment: .trailing)
                    Text(firstColumnHeader()).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .environment(\.layoutDirection, .leftToRight)
                .font(.caption)
                .foregroundColor(.secondary)
                Divider()
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 8) {
                        ForEach(Array(netTableRows.enumerated()), id: \.offset) { idx, row in
                            // Force LTR to match header order
                            HStack {
                                Text(currency(row.cumulative)).frame(width: 120, alignment: .trailing)
                                Text(currency(row.added)).frame(width: 100, alignment: .trailing)
                                Text(row.year).frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .environment(\.layoutDirection, .leftToRight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                switch selectedTimeframe {
                                case .allTime:
                                    if let y = Int(row.year) { netDrillTarget = .year(y) }
                                case .thisYear, .customRange:
                                    netDrillTarget = .month(year: selectedYear, month: idx + 1)
                                case .thisMonth:
                                    netDrillTarget = .week(year: selectedYear, month: selectedMonth, week: idx + 1)
                                }
                            }
                            .padding(.vertical, 2)
                            .overlay(Divider(), alignment: .bottom)
                        }
                    }
                }
            }
            .padding()
            .environment(\.layoutDirection, .rightToLeft)
            .presentationDetents([.medium, .large])
            .sheet(isPresented: Binding(get: { netDrillTarget != nil }, set: { if !$0 { netDrillTarget = nil } })) {
                VStack(alignment: .trailing, spacing: 12) {
                    if let target = netDrillTarget {
                        HStack { Spacer(); Text(netDrillTitle(target)).font(.headline).fontWeight(.semibold) }
                        // Force table header to LTR so columns appear as: [Yearly | Company] visually right-aligned
                        HStack { 
                            Text("שנתי").frame(width: 120, alignment: .trailing)
                            Text("חברה").frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        Divider()
                        ScrollView {
                            LazyVStack(alignment: .trailing, spacing: 8) {
                                ForEach(netByCompany(target: target), id: \.company) { row in
                                    // Force LTR: value column on the left, company column on the right
                                    HStack {
                                        Text(currency(row.value)).frame(width: 120, alignment: .trailing)
                                        Text(row.company).frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    .environment(\.layoutDirection, .leftToRight)
                                    .padding(.vertical, 2)
                                    .overlay(Divider(), alignment: .bottom)
                                }
                            }
                        }
                    }
                }
                .padding()
                .environment(\.layoutDirection, .rightToLeft)
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Fallback Pie Chart for iOS 15
    private var fallbackPieChart: some View {
        VStack(spacing: 12) {
            // Simple circular progress representation
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                    .frame(width: 150, height: 150)
                
                // Show top 4 companies as circle segments (approximation)
                ForEach(Array(companySavingsData.prefix(4).enumerated()), id: \.element.company) { index, companyData in
                    let percentage = companySavingsData.isEmpty ? 0 : companyData.totalSavings / companySavingsData.reduce(0) { $0 + $1.totalSavings }
                    let color = getCompanyColor(for: index)
                    
                    Circle()
                        .trim(from: 0, to: percentage)
                        .stroke(color, lineWidth: 20)
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90 + Double(index) * 90))
                }
                
                // Center text
                VStack {
                    Text("₪\(Int(companySavingsData.reduce(0) { $0 + $1.totalSavings }))")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("סה״כ חיסכון")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(companySavingsData.prefix(4).enumerated()), id: \.element.company) { index, companyData in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(getCompanyColor(for: index))
                            .frame(width: 10, height: 10)
                        Text(companyData.company)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 200)
    }

    // MARK: - Tooltip Bubble (RTL)
    private struct TooltipBubbleRTL: View {
        let text: String
        var body: some View {
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.8))
                )
                .multilineTextAlignment(.trailing)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
    
    // MARK: - Helper for Colors
    private func getCompanyColor(for index: Int) -> Color {
        let colors: [Color] = [Color.appBlue, .green, .orange, .purple, .red, .pink, .yellow, .mint]
        return colors[index % colors.count]
    }
    
    private func getCategoryColor(_ category: CouponCategory) -> Color {
        switch category {
        case .sports: return .orange
        case .digitalGiftCards: return .pink
        case .restaurants: return .blue
        case .travelData: return .mint
        case .gym: return .purple
        case .pharm: return .teal
        case .home: return .brown
        case .fashion: return .red
        case .coffee: return .yellow
        case .other: return .gray
        }
    }

    // MARK: - Tooltip text helpers
    private func companyTooltipText(companyName: String, value: Double, percent: Double) -> String {
        if let cached = companyTooltipCache[companyName] {
            let pctStr = String(format: "%.1f", cached.percent)
            return "\(companyName)\nחיסכון: ₪\(Int(cached.value)) (\(pctStr)%)\nפעילים: \(cached.active) | מנוצלים: \(cached.used) | סה\"כ: \(cached.total)"
        }
        if let row = companySavingsData.first(where: { $0.company == companyName }) {
            let pctStr = String(format: "%.1f", percent)
            return "\(companyName)\nחיסכון: ₪\(Int(value)) (\(pctStr)%)\nפעילים: \(row.activeCoupons) | מנוצלים: \(row.usedCoupons) | סה\"כ: \(row.totalCoupons)"
        }
        let pctStr = String(format: "%.1f", percent)
        return "\(companyName)\nחיסכון: ₪\(Int(value)) (\(pctStr)%)"
    }

    // MARK: - Donut hit-testing
    private func hitTestDonut(location: CGPoint, plotFrame: CGRect, innerRatio: CGFloat, values: [Double], startAngle: Double = -90) -> Int? {
        guard !values.isEmpty else { return nil }
        let center = CGPoint(x: plotFrame.midX, y: plotFrame.midY)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let radius = sqrt(dx*dx + dy*dy)
        let outerR = min(plotFrame.width, plotFrame.height) / 2
        let innerR = innerRatio * outerR
        // Ignore taps too close to center or far outside the donut
        guard radius >= innerR * 0.9 && radius <= outerR * 1.1 else { return nil }

        // Convert to angle in degrees where 0° is to the right (3 o'clock), 0...360 CCW
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        // Adjust for Charts' default start angle (12 o'clock ≈ -90°)
        angle -= startAngle
        if angle < 0 { angle += 360 }

        let total = max(values.reduce(0, +), 1)
        var start: Double = 0
        for (i, v) in values.enumerated() {
            let sweep = 360.0 * (v / total)
            let end = start + sweep
            if angle >= start && angle < end { return i }
            start = end
        }
        // If due to rounding the angle is exactly 360, map to last slice
        return values.indices.last
    }

    // MARK: - Precompute all datasets on appear
    private func precomputeAll() {
        // Show the screen immediately with a live progress indicator.
        self.isLoading = true
        self.loadingProgress = 0
        self.loadingMessage = "מכין סטטיסטיקות..."

        func setProgress(_ value: Double, _ message: String) {
            DispatchQueue.main.async {
                self.loadingProgress = value
                self.loadingMessage = message
            }
        }
        // Snapshot values that depend on @State to avoid cross-thread reads
        let filteredForCategories = self.filteredCoupons

        DispatchQueue.global(qos: .userInitiated).async {
            // Monthly datasets
            setProgress(0.1, "איגוד נתונים חודשיים...")
            let ms = self.monthlySavings
            var acc: [(Date, Double)] = []
            var run = 0.0
            for p in ms { run += p.value; acc.append((p.date, run)) }

            setProgress(0.3, "חישוב יתרות חודשיות...")
            let mr = self.monthlyRemaining

            // Yearly datasets
            setProgress(0.5, "איגוד נתונים שנתיים...")
            let yh = self.yearlyHoldings
            var yhacc: [(Date, Double)] = []
            var hrun = 0.0
            for p in yh { hrun += p.value; yhacc.append((p.date, hrun)) }

            let yn = self.yearlyNetSavings
            var ynacc: [(Date, Double)] = []
            var nrun = 0.0
            for p in yn { nrun += p.value; ynacc.append((p.date, nrun)) }

            // Debug logs for the two charts
            let holdingsRows = yhacc.map { "{year:\(yearText($0.0)), holdings:\(fmt2($0.1))}" }.joined(separator: ", ")
            logBoth("📈 [HoldingsCumulativeData] [\(holdingsRows)]")
            let netRows = ynacc.map { "{year:\(yearText($0.0)), net:\(fmt2($0.1))}" }.joined(separator: ", ")
            logBoth("📈 [NetSavingsCumulativeData] [\(netRows)]")

            setProgress(0.7, "חישוב יתרות שנתיות...")
            let yrm = self.yearlyRemaining

            // Categories and companies
            setProgress(0.85, "פילוח לפי קטגוריות וחברות...")
            let cats = self.computeCategorySavings(from: filteredForCategories)
            let allTimeCompanies = self.aggregateCompanySavings(from: self.coupons)
            let yearCompanies = self.aggregateCompanySavings(from: self.coupons.filter { c in
                guard let d = c.dateAddedAsDate else { return false }
                return Calendar.current.component(.year, from: d) == self.selectedYear
            })
            let monthCompanies = self.aggregateCompanySavings(from: self.coupons.filter { c in
                guard let d = c.dateAddedAsDate else { return false }
                let cal = Calendar.current
                let comps = cal.dateComponents([.month, .year], from: d)
                return comps.month == self.selectedMonth && comps.year == self.selectedYear
            })

            setProgress(0.95, "מסיים...")
            DispatchQueue.main.async {
                self.monthlySavingsPoints = ms
                self.cumulativeSavingsPoints = acc
                self.monthlyRemainingPoints = mr
                // Keep old arrays for compatibility, but populate new clarified series
                self.yearlySavingsPoints = self.yearlySavings
                self.yearlyCumulativePoints = self.yearlyCumulative
                self.yearlyHoldingsCumulativePoints = yhacc
                self.yearlyNetCumulativePoints = ynacc
                self.yearlyRemainingPoints = yrm
                self.precomputedCategorySavings = cats
                self.precomputedCompanySavingsAllTime = allTimeCompanies
                self.precomputedCompanySavingsThisYear = yearCompanies
                self.precomputedCompanySavingsThisMonth = monthCompanies
                self.isLoading = false
                self.loadingProgress = 1.0
                self.loadingMessage = ""
                self.rebuildTooltipCaches()
            }
        }
    }

    private func aggregateCompanySavings(from input: [Coupon]) -> [CompanySavings] {
        var dict: [String: CompanySavings] = [:]
        for coupon in input {
            // Aggregate by actual usage amount so charts match real use,
            // not theoretical savings.
            let savings = coupon.usedValue
            let existing = dict[coupon.company] ?? CompanySavings(company: coupon.company, totalSavings: 0, totalValue: 0, activeCoupons: 0, usedCoupons: 0, totalCoupons: 0)
            dict[coupon.company] = CompanySavings(
                company: coupon.company,
                totalSavings: existing.totalSavings + savings,
                totalValue: existing.totalValue + coupon.remainingValue,
                activeCoupons: existing.activeCoupons + (!coupon.isExpired && !coupon.isFullyUsed ? 1 : 0),
                usedCoupons: existing.usedCoupons + (coupon.usedValue > 0 ? 1 : 0),
                totalCoupons: existing.totalCoupons + 1
            )
        }
        return Array(dict.values).sorted { $0.totalSavings > $1.totalSavings }
    }

    // Cache tooltip data for instant display (called after data precomputation)
    private func rebuildTooltipCaches() {
        // Categories
        let cats = self.precomputedCategorySavings
        let totalCat = max(cats.reduce(0) { $0 + $1.totalSavings }, 1)
        var catMap: [String: (Double, Double)] = [:]
        for c in cats {
            let pct = (c.totalSavings / totalCat) * 100
            catMap[c.category.rawValue] = (c.totalSavings, pct)
        }
        self.categoryTooltipCache = catMap

        // Companies – use the currently selected timeframe dataset
        let companies = self.companySavingsData
        let totalComp = max(companies.reduce(0) { $0 + $1.totalSavings }, 1)
        var compMap: [String: (Double, Double, Int, Int, Int)] = [:]
        for c in companies {
            let pct = (c.totalSavings / totalComp) * 100
            compMap[c.company] = (c.totalSavings, pct, c.activeCoupons, c.usedCoupons, c.totalCoupons)
        }
        self.companyTooltipCache = compMap
    }
}

// Components moved to Views/SavingsReportComponents.swift

// Modal moved to Views/SavingsReportComponents.swift

// StatisticsCard moved to Views/SavingsReportComponents.swift

// Models moved to Models/SavingsReportModels.swift

// Coupon date parsing moved to Extensions/Coupon+DateAdded.swift

#Preview {
    SavingsReportView(
        user: User(
            id: 1,
            email: "test@test.com",
            password: nil,
            firstName: "איתי",
            lastName: "כהן",
            age: 30,
            gender: "male",
            region: nil,
            isConfirmed: true,
            isAdmin: false,
            slots: 5,
            slotsAutomaticCoupons: 50,
            createdAt: "2024-01-01T00:00:00Z",
            profileDescription: nil,
            profileImage: nil,
            couponsSoldCount: 0,
            isDeleted: false,
            dismissedExpiringAlertAt: nil,
            dismissedMessageId: nil,
            googleId: nil,
            newsletterSubscription: true,
            telegramMonthlySummary: true,
            newsletterImage: nil,
            showWhatsappBanner: false,
            faceIdEnabled: false,
            pushToken: nil
        ),
        coupons: []
    )
}
