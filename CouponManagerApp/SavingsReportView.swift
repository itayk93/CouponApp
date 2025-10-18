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
    @State private var selectedTimeframe: TimeframeFilter = .thisMonth
    @State private var showingStatisticsModal = false
    
    // Computed properties for statistics
    private var filteredCoupons: [Coupon] {
        let now = Date()
        let calendar = Calendar.current
        
        return coupons.filter { coupon in
            switch selectedTimeframe {
            case .allTime:
                // Include all coupons regardless of date parsing issues
                return true
            case .thisMonth:
                guard let dateAdded = coupon.dateAddedAsDate else { return false }
                return calendar.isDate(dateAdded, equalTo: now, toGranularity: .month)
            case .thisYear:
                guard let dateAdded = coupon.dateAddedAsDate else { return false }
                return calendar.isDate(dateAdded, equalTo: now, toGranularity: .year)
            }
        }
    }
    
    private var companySavingsData: [CompanySavings] {
        var companyDict: [String: CompanySavings] = [:]
        
        for coupon in filteredCoupons {
            // חישוב חיסכון: אם יש cost, נחשב הפרש. אחרת נחשב לפי used_value
            let savings: Double
            if coupon.cost > 0 {
                savings = max(0, coupon.value - coupon.cost)
            } else {
                // אם אין cost, נחשב את החיסכון לפי מה שהמשתמש השתמש
                savings = coupon.usedValue
            }
            
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
    
    private var totalStatistics: SavingsStatistics {
        let totalSavings = companySavingsData.reduce(0) { $0 + $1.totalSavings }
        let totalValue = companySavingsData.reduce(0) { $0 + $1.totalValue }
        let totalCoupons = companySavingsData.reduce(0) { $0 + $1.totalCoupons }
        let activeCoupons = companySavingsData.reduce(0) { $0 + $1.activeCoupons }
        let usedCoupons = companySavingsData.reduce(0) { $0 + $1.usedCoupons }
        
        let utilizationRate = totalCoupons > 0 ? Double(usedCoupons) / Double(totalCoupons) * 100 : 0
        let averageSavingsPerCoupon = totalCoupons > 0 ? totalSavings / Double(totalCoupons) : 0
        
        return SavingsStatistics(
            totalSavings: totalSavings,
            totalValue: totalValue,
            totalCoupons: totalCoupons,
            activeCoupons: activeCoupons,
            usedCoupons: usedCoupons,
            utilizationRate: utilizationRate,
            averageSavingsPerCoupon: averageSavingsPerCoupon
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with time period selector
                    timeframeSelector
                    
                    // Main statistics card
                    mainStatisticsCard
                    
                    // Companies breakdown (like the original)
                    companiesBreakdownSection
                    
                    // Charts section - always visible
                    chartsSection
                }
                .padding()
            }
            .navigationTitle("על מה חסכת?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("סגור") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("סטטיסטיקות") {
                        showingStatisticsModal = true
                    }
                    .font(.caption)
                }
            }
            .sheet(isPresented: $showingStatisticsModal) {
                StatisticsModalView(statistics: totalStatistics, timeframe: selectedTimeframe)
            }
            .onAppear {
                logSavingsDebug(context: "onAppear")
            }
            .onChange(of: selectedTimeframe) { _ in
                logSavingsDebug(context: "timeframeChanged")
            }
        }
    }

    // MARK: - Debug Logging
    private func logSavingsDebug(context: String) {
        print("\n==================== SavingsReport Debug (")
        print("📍 Context: \(context)")
        print("🕒 Timeframe: \(selectedTimeframe.displayName)")
        print("🎫 Incoming coupons: \(coupons.count)")

        // Date parsing stats
        var parseOK = 0
        var parseFail = 0
        for c in coupons.prefix(200) { // cap to avoid huge spam
            if c.dateAddedAsDate != nil { parseOK += 1 } else { parseFail += 1 }
        }
        print("📅 date_added parse OK=\(parseOK), FAIL=\(parseFail)")
        if parseFail > 0 {
            // Print up to 5 problematic examples
            let bad = coupons.filter { $0.dateAddedAsDate == nil }.prefix(5)
            for c in bad {
                print("⚠️ Failed to parse date_added for coupon id=\(c.id), company=\(c.company), raw='\(c.dateAdded)'")
            }
        }

        let filtered = filteredCoupons
        print("🔎 After timeframe filter: \(filtered.count) coupons")

        // Company aggregation overview
        print("🏷️ Companies in breakdown: \(companySavingsData.count)")
        for item in companySavingsData.prefix(10) {
            print(" • \(item.company): coupons=\(item.totalCoupons), saved=₪\(Int(item.totalSavings)), activeValue=₪\(Int(item.totalValue)), active=\(item.activeCoupons), used=\(item.usedCoupons)")
        }

        // Totals
        print("Σ Totals -> saved=₪\(Int(totalStatistics.totalSavings)) | activeValue=₪\(Int(totalStatistics.totalValue)) | coupons=\(totalStatistics.totalCoupons) | used=\(totalStatistics.usedCoupons) | active=\(totalStatistics.activeCoupons) | utilization=\(String(format: "%.1f", totalStatistics.utilizationRate))%")
        print("====================\n")
    }

    // MARK: - Timeframe Selector
    private var timeframeSelector: some View {
        VStack(spacing: 12) {
            Text("בחר טווח זמן לניתוח")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            HStack(spacing: 12) {
                ForEach(TimeframeFilter.allCases, id: \.self) { timeframe in
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
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Main Statistics Card
    private var mainStatisticsCard: some View {
        VStack(spacing: 16) {
            Text("סיכום כללי")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            HStack(spacing: 20) {
                StatisticItem(
                    title: "סה״כ חיסכון",
                    value: "₪\(Int(totalStatistics.totalSavings))",
                    color: .green
                )
                
                StatisticItem(
                    title: "ערך פעיל",
                    value: "₪\(Int(totalStatistics.totalValue))",
                    color: Color.appBlue
                )
                
                StatisticItem(
                    title: "מספר קופונים",
                    value: "\(totalStatistics.totalCoupons)",
                    color: .orange
                )
            }
            
            // Utilization rate bar
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Text("\(String(format: "%.1f", totalStatistics.utilizationRate))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.appBlue)
                    Spacer()
                    Text("אחוז ניצול קופונים")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(Color.appBlue)
                            .frame(width: geometry.size.width * (totalStatistics.utilizationRate / 100), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
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
                Text("התפלגות החיסכון לפי חברות")
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
                .chartLegend(position: .bottom, alignment: .center, spacing: 8) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(companySavingsData.prefix(8), id: \.company) { companyData in
                            Label(companyData.company, systemImage: "circle.fill")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                }
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
    
    // MARK: - Helper for Colors
    private func getCompanyColor(for index: Int) -> Color {
        let colors: [Color] = [Color.appBlue, .green, .orange, .purple, .red, .pink, .yellow, .mint]
        return colors[index % colors.count]
    }
}

// MARK: - Company Breakdown Row (Original Design)
struct CompanyBreakdownRow: View {
    let companyData: CompanySavings
    
    var body: some View {
        VStack(spacing: 8) {
            // Header row with company name
            HStack {
                Text("\(companyData.totalCoupons)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("קופונים:")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(companyData.company)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            // Values row
            HStack {
                Text("₪\(Int(companyData.totalSavings))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                
                if companyData.totalSavings > 0 {
                    Text("(\(String(format: "%.0f", (companyData.totalSavings / max(companyData.totalValue + companyData.totalSavings, 1)) * 100))%)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Text("(₪\(Int(companyData.totalValue)) ערך זמין)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appBlue)
                }
                
                Spacer()
                
                Text("סך הכסף:")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Statistic Item Component
struct StatisticItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Statistics Modal
struct StatisticsModalView: View {
    let statistics: SavingsStatistics
    let timeframe: TimeframeFilter
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Modal title with settings icon
                HStack {
                    Button("⚙️ סיווג לפי חברות וסוגי קופונים") {
                        // Settings action
                    }
                    .font(.system(size: 14))
                    .foregroundColor(Color.appBlue)
                    
                    Spacer()
                }
                .padding(.top)
                
                // Main statistics grid (like original modal)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    StatisticsCard(
                        title: "סך החיסכון שלך",
                        value: "₪\(Int(statistics.totalSavings))",
                        subtitle: "מחיר \(Int(statistics.totalSavings + statistics.totalValue)) ש״ח אפשריים",
                        percentage: "\(Int((statistics.totalSavings / max(statistics.totalSavings + statistics.totalValue, 1)) * 100))%",
                        color: Color.appBlue
                    )
                    
                    StatisticsCard(
                        title: "אחוז ניצול ממוצע",
                        value: "\(String(format: "%.0f", statistics.utilizationRate))%",
                        subtitle: "ממוצע ניצול לכלל הקופונים",
                        percentage: "\(String(format: "%.0f", statistics.utilizationRate))%",
                        color: .green
                    )
                    
                    StatisticsCard(
                        title: "מספר קופונים",
                        value: "\(statistics.totalCoupons)",
                        subtitle: "\(statistics.usedCoupons) מתוכם פעילים",
                        percentage: "\(statistics.activeCoupons)",
                        color: .orange
                    )
                    
                    StatisticsCard(
                        title: "ממוצע חיסכון לקופון",
                        value: "₪\(Int(statistics.averageSavingsPerCoupon))",
                        subtitle: "חיסכון ממוצע לקופון",
                        percentage: "\(Int(statistics.averageSavingsPerCoupon))",
                        color: .purple
                    )
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("סטטיסטיקות החיסכון שלך")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("✕") {
                        dismiss()
                    }
                    .font(.title2)
                    .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Statistics Card Component
struct StatisticsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let percentage: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Supporting Models
struct CompanySavings {
    let company: String
    let totalSavings: Double
    let totalValue: Double
    let activeCoupons: Int
    let usedCoupons: Int
    let totalCoupons: Int
}

struct SavingsStatistics {
    let totalSavings: Double
    let totalValue: Double
    let totalCoupons: Int
    let activeCoupons: Int
    let usedCoupons: Int
    let utilizationRate: Double
    let averageSavingsPerCoupon: Double
}

enum TimeframeFilter: CaseIterable {
    case thisMonth, thisYear, allTime
    
    var displayName: String {
        switch self {
        case .thisMonth: return "החודש"
        case .thisYear: return "השנה"
        case .allTime: return "כל הזמן"
        }
    }
}

// MARK: - Coupon Date Extension
extension Coupon {
    // Parse `date_added` robustly: supports fractional seconds, timezone offsets, and date-only strings.
    var dateAddedAsDate: Date? {
        // 1) ISO8601 with fractional seconds (e.g., 2024-10-18T12:34:56.123456Z or +00:00)
        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoWithFraction.date(from: dateAdded) {
            return d
        }

        // 2) ISO8601 without fractional seconds
        let isoNoFraction = ISO8601DateFormatter()
        isoNoFraction.formatOptions = [.withInternetDateTime]
        if let d = isoNoFraction.date(from: dateAdded) {
            return d
        }

        // 3) Common fallback formats from DB exports (keep POSIX to avoid locale issues)
        let posix = Locale(identifier: "en_US_POSIX")
        let df = DateFormatter()
        df.locale = posix
        df.timeZone = TimeZone(secondsFromGMT: 0)

        let candidates = [
            // With fractional seconds
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",   // 2024-10-18T12:34:56+00:00
            "yyyy-MM-dd HH:mm:ssXXXXX",    // 2024-10-18 12:34:56+00:00
            "yyyy-MM-dd HH:mm:ss",         // 2024-10-18 12:34:56
            "yyyy-MM-dd"                    // 2024-10-18
        ]

        for format in candidates {
            df.dateFormat = format
            if let d = df.date(from: dateAdded) {
                return d
            }
        }

        return nil
    }
}

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
