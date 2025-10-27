import WidgetKit
import SwiftUI
import Foundation
import CryptoKit
import CommonCrypto

// MARK: - Encryption Manager for Widget

class WidgetEncryptionManager {
    private static let encryptionKey = "iKWLJAq-F_BoMip2duhM3-QUPNtxRrefQ0TeaxXQc0E="
    
    static func decryptString(_ encryptedString: String) -> String? {
        guard encryptedString.starts(with: "gAAAAA") else {
            return encryptedString
        }
        return fernetDecrypt(encryptedString)
    }
    
    private static func fernetDecrypt(_ encryptedString: String) -> String? {
        var base64String = encryptedString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let paddingLength = 4 - (base64String.count % 4)
        if paddingLength < 4 {
            base64String += String(repeating: "=", count: paddingLength)
        }
        
        guard let encryptedData = Data(base64Encoded: base64String) else {
            return nil
        }
        
        guard encryptedData.count >= 57 else {
            return nil
        }
        
        let version = encryptedData[0]
        guard version == 0x80 else {
            return nil
        }
        
        let _ = encryptedData[1..<9]
        let iv = encryptedData[9..<25]
        let hmac = encryptedData.suffix(32)
        let ciphertext = encryptedData[25..<(encryptedData.count-32)]
        
        var keyBase64 = encryptionKey
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let keyPaddingLength = 4 - (keyBase64.count % 4)
        if keyPaddingLength < 4 {
            keyBase64 += String(repeating: "=", count: keyPaddingLength)
        }
        
        guard let keyData = Data(base64Encoded: keyBase64),
              keyData.count == 32 else {
            return nil
        }
        
        let signingKey = keyData[0..<16]
        let encryptionKeyData = keyData[16..<32]
        
        let message = encryptedData[0..<(encryptedData.count-32)]
        let computedHmac = HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: signingKey))
        
        guard Data(computedHmac) == hmac else {
            return nil
        }
        
        let decryptedData = decryptAES128CBC(data: Data(ciphertext), key: Data(encryptionKeyData), iv: Data(iv))
        
        guard let decryptedData = decryptedData,
              let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            return nil
        }
        
        return decryptedString
    }
    
    private static func decryptAES128CBC(data: Data, key: Data, iv: Data) -> Data? {
        let keyBytes = key.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        let ivBytes = iv.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        let dataBytes = data.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        
        let decryptedLength = data.count + kCCBlockSizeAES128
        var decryptedData = Data(count: decryptedLength)
        var numBytesDecrypted: size_t = 0
        
        let cryptStatus = decryptedData.withUnsafeMutableBytes { decryptedBytes in
            CCCrypt(
                CCOperation(kCCDecrypt),
                CCAlgorithm(kCCAlgorithmAES),
                CCOptions(kCCOptionPKCS7Padding),
                keyBytes.baseAddress, key.count,
                ivBytes.baseAddress,
                dataBytes.baseAddress, data.count,
                decryptedBytes.bindMemory(to: UInt8.self).baseAddress, decryptedLength,
                &numBytesDecrypted
            )
        }
        
        guard cryptStatus == kCCSuccess else {
            return nil
        }
        
        decryptedData.removeSubrange(numBytesDecrypted...)
        return decryptedData
    }
}

// MARK: - Extensions

extension View {
    @ViewBuilder
    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            background(backgroundView)
        }
    }
}

extension View {
    func couponFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: size, weight: weight, design: .rounded))
    }
}

// MARK: - Shared widget style

private struct WidgetStyle {
    static var primaryGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 44/255, green: 63/255, blue: 80/255), location: 0.0),
                .init(color: Color(red: 64/255, green: 83/255, blue: 100/255), location: 0.3),
                .init(color: Color(red: 44/255, green: 63/255, blue: 80/255), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var alertGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 220/255, green: 100/255, blue: 60/255), location: 0.0),
                .init(color: Color(red: 240/255, green: 120/255, blue: 80/255), location: 0.3),
                .init(color: Color(red: 220/255, green: 100/255, blue: 60/255), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var subtleCardBackground: Color {
        Color.primary.opacity(0.05)
    }
}

// MARK: - Provider and Entry

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        print("🎯 WIDGET PROVIDER: placeholder called")
        return SimpleEntry(date: Date(), coupons: [], companies: [], activeCouponsCount: 0, totalRemainingValue: 0.0, debugMessage: "Loading...")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        print("🎯 WIDGET PROVIDER: getSnapshot called")
        Task {
            do {
                let userId = WidgetAPIClient.shared.getCurrentUserId()
                if userId != nil {
                    let allCoupons = try await WidgetAPIClient.shared.getCoupons()
                    let activeCoupons = allCoupons.filter { $0.status == "פעיל" }
                    let activeCouponsCount = activeCoupons.count
                    let totalValue = activeCoupons.filter { !$0.isOneTime }.reduce(0.0) { $0 + $1.remainingValue }
                    // Show only coupons chosen for the widget that are still active and have a positive remaining value
                    let widgetCoupons = allCoupons.filter { ($0.showInWidget == true) && ($0.status == "פעיל") && ($0.remainingValue > 0) }
                    let companies = try await WidgetAPIClient.shared.getCompanies()
                    
                    let entry = SimpleEntry(
                        date: Date(),
                        coupons: widgetCoupons,
                        companies: companies,
                        activeCouponsCount: activeCouponsCount,
                        totalRemainingValue: totalValue,
                        debugMessage: nil
                    )
                    completion(entry)
                } else {
                    let entry = SimpleEntry(date: Date(), coupons: [], companies: [], activeCouponsCount: 0, totalRemainingValue: 0.0, debugMessage: "Please open app")
                    completion(entry)
                }
            } catch {
                let entry = SimpleEntry(date: Date(), coupons: [], companies: [], activeCouponsCount: 0, totalRemainingValue: 0.0, debugMessage: "Please open app")
                completion(entry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        print("🎯 WIDGET: getTimeline called")
        Task {
            var debugLog = "🎯 WIDGET Timeline started...\n"
            do {
                print("🎯 WIDGET: Step 1 - Checking User ID")
                let userId = WidgetAPIClient.shared.getCurrentUserId()
                debugLog += "User ID: \(userId != nil ? String(userId!) : "Not Found")\n"
                print("🎯 WIDGET: User ID = \(userId ?? -1)")
                
                guard userId != nil else {
                    print("❌ WIDGET: No user ID, throwing error")
                    throw APIError.notAuthenticated
                }

                print("🎯 WIDGET: Step 2 - Reading from shared container")
                debugLog += "Reading from shared container...\n"
                let allCoupons = try await WidgetAPIClient.shared.getCoupons()
                debugLog += "Total coupons: \(allCoupons.count)\n"
                print("🎯 WIDGET: Found \(allCoupons.count) total coupons")
                
                print("🎯 WIDGET: Step 3 - Calculating statistics")
                let activeCoupons = allCoupons.filter { $0.status == "פעיל" }
                let activeCouponsCount = activeCoupons.count
                let totalValue = activeCoupons.filter { !$0.isOneTime }.reduce(0.0) { $0 + $1.remainingValue }
                debugLog += "Active: \(activeCouponsCount), Value: ₪\(totalValue) (Corrected)\n"
                print("🎯 WIDGET: Active coupons = \(activeCouponsCount), Total value = ₪\(totalValue) (Corrected)")
                
                print("🎯 WIDGET: Step 4 - Filtering and ordering widget coupons")
                // Show only selected coupons that are active and with a positive remaining value
                let widgetCoupons = allCoupons
                    .filter { ($0.showInWidget == true) && ($0.status == "פעיל") && ($0.remainingValue > 0) }
                    .sorted { coupon1, coupon2 in
                        let order1 = coupon1.widgetDisplayOrder ?? 999
                        let order2 = coupon2.widgetDisplayOrder ?? 999
                        return order1 < order2
                    }
                debugLog += "Widget coupons: \(widgetCoupons.count) (ordered)\n"
                print("🎯 WIDGET: Widget coupons = \(widgetCoupons.count) (ordered by display order)")
                
                for (index, coupon) in widgetCoupons.enumerated() {
                    debugLog += "W\(index+1): \(coupon.company) (Order: \(coupon.widgetDisplayOrder ?? 999))\n"
                }

                debugLog += "Fetching companies...\n"
                let companies = try await WidgetAPIClient.shared.getCompanies()
                debugLog += "Companies: \(companies.count)\n"
                
                // Companies are fetched for logo matching below; no-op loop removed
                
                for coupon in widgetCoupons {
                    let normalizedCouponCompany = coupon.company.lowercased().trimmingCharacters(in: .whitespaces)
                    let matchedCompany = companies.first { company in
                        let normalizedCompanyName = company.name.lowercased().trimmingCharacters(in: .whitespaces)
                        return normalizedCompanyName == normalizedCouponCompany
                    }
                    let logo = matchedCompany?.imagePath ?? "NOT FOUND"
                    print("   - Company: '\(coupon.company)' | Logo: '\(logo)'")
                }

                print("🎯 WIDGET: Step 6 - Creating entry")
                let currentDate = Date()
                let entry = SimpleEntry(
                    date: currentDate,
                    coupons: widgetCoupons,
                    companies: companies,
                    activeCouponsCount: activeCouponsCount,
                    totalRemainingValue: totalValue,
                    debugMessage: debugLog + "✅ Success!"
                )
                
                print("🎯 WIDGET: Entry created with \(entry.coupons.count) coupons, \(entry.activeCouponsCount) active, ₪\(entry.totalRemainingValue) total")
                
                let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                print("🎯 WIDGET: Timeline completed successfully")
                completion(timeline)

            } catch {
                print("❌ WIDGET ERROR: \(error.localizedDescription)")
                debugLog += "❌ ERROR: \(error.localizedDescription)\n"
                let entry = SimpleEntry(
                    date: Date(),
                    coupons: [],
                    companies: [],
                    activeCouponsCount: 0,
                    totalRemainingValue: 0.0,
                    debugMessage: debugLog
                )
                let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30)))
                print("🎯 WIDGET: Error timeline created, will retry in 30 seconds")
                completion(timeline)
            }
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let coupons: [WidgetCoupon]
    let companies: [WidgetCompany]
    let activeCouponsCount: Int
    let totalRemainingValue: Double
    var debugMessage: String?
}

// MARK: - Small Widget

struct CouponStatsSmallView: View {
    var entry: Provider.Entry
    
    private var activeCouponsCount: Int {
        return entry.activeCouponsCount
    }
    
    private var oneTimeCouponsCount: Int {
        let allCoupons = getAllCouponsFromSharedContainer()
        return allCoupons.filter { $0.status == "פעיל" && $0.isOneTime == true }.count
    }
    
    private func getAllCouponsFromSharedContainer() -> [WidgetCoupon] {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.itaykarkason.CouponManagerApp"),
              let data = sharedDefaults.data(forKey: "SharedCouponData") else {
            return []
        }
        
        do {
            struct SharedCoupon: Codable {
                let id: Int
                let code: String
                let description: String?
                let value: Double
                let cost: Double
                let company: String
                let expiration: String?
                let dateAdded: String
                let usedValue: Double
                let status: String
                let isOneTime: Bool
                let userId: Int
                let showInWidget: Bool?
                let widgetDisplayOrder: Int?
                
                var remainingValue: Double {
                    return value - usedValue
                }
            }
            
            let sharedCoupons = try JSONDecoder().decode([SharedCoupon].self, from: data)
            
            return sharedCoupons.map { shared in
                WidgetCoupon(
                    id: shared.id,
                    code: shared.code,
                    description: shared.description,
                    value: shared.value,
                    cost: shared.cost,
                    company: shared.company,
                    expiration: shared.expiration,
                    dateAdded: shared.dateAdded,
                    usedValue: shared.usedValue,
                    status: shared.status,
                    isOneTime: shared.isOneTime,
                    userId: shared.userId,
                    showInWidget: shared.showInWidget,
                    widgetDisplayOrder: shared.widgetDisplayOrder
                )
            }
        } catch {
            print("❌ Failed to decode all coupons from shared container: \(error)")
            return []
        }
    }
    
    private var totalActiveValue: Double {
        return entry.totalRemainingValue
    }
    
    private var expiringThisWeek: [WidgetCoupon] {
        let calendar = Calendar.current
        let today = Date()
        let oneWeekFromNow = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        
        return entry.coupons.filter { coupon in
            guard let expirationDate = coupon.expirationDate else { return false }
            return expirationDate >= today && expirationDate <= oneWeekFromNow
        }.sorted { $0.expirationDate ?? Date.distantFuture < $1.expirationDate ?? Date.distantFuture }
    }
    
    private var hasExpiringCoupons: Bool {
        return !expiringThisWeek.isEmpty
    }
    
    private var shouldShowExpiringAlert: Bool {
        guard hasExpiringCoupons else { return false }
        let currentTime = Date().timeIntervalSince1970
        let secondsInMinute = Int(currentTime) % 60
        return secondsInMinute < 3
    }
    
    var body: some View {
        let _ = print("🎯 WIDGET VIEW: CouponStatsSmallView.body called")
        
        if entry.coupons.isEmpty && activeCouponsCount == 0 {
            ZStack {
                WidgetStyle.primaryGradient
                    .edgesIgnoringSafeArea(.all)
                VStack(spacing: 4) {
                    Text("Debug Info:")
                        .couponFont(10, weight: .bold)
                        .foregroundColor(.red)
                    
                    Text("User ID: \(WidgetAPIClient.shared.getCurrentUserId() ?? -1)")
                        .couponFont(8)
                        .foregroundColor(.white)
                    
                    Text("Entry Coupons: \(entry.coupons.count)")
                        .couponFont(8)
                        .foregroundColor(.white)
                    
                    Text("Active: \(activeCouponsCount)")
                        .couponFont(8)
                        .foregroundColor(.white)
                    
                    Text("Total: ₪\(Int(totalActiveValue))")
                        .couponFont(8)
                        .foregroundColor(.white)
                    
                    if WidgetAPIClient.shared.getCurrentUserId() == nil {
                        Text("Please open the main app first")
                            .couponFont(8)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Data loaded but no display")
                            .couponFont(8)
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
            }
            .widgetBackground(Color.clear)
        } else if hasExpiringCoupons && shouldShowExpiringAlert {
            expiringCouponsView
                .widgetBackground(Color.clear)
        } else {
            regularStatsView
                .widgetBackground(Color.clear)
        }
    }
    
    private var regularStatsView: some View {
        ZStack {
            WidgetStyle.primaryGradient
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                Spacer()
                Spacer()
                
                VStack(spacing: 10) {
                    HStack {
                        Spacer()
                        
                        if let uiImage = UIImage(named: "CouponLogo", in: Bundle.main, compatibleWith: nil) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .cornerRadius(6)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.2, green: 0.6, blue: 1.0),
                                                Color(red: 0.1, green: 0.5, blue: 0.9)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 24, height: 24)
                                
                                VStack(spacing: 1) {
                                    Text("%")
                                        .couponFont(12, weight: .heavy)
                                        .foregroundColor(.white)
                                    
                                    Text("✂")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
                
                HStack {
                    VStack(alignment: .center, spacing: 2) {
                        Text("חד פעמיים")
                            .couponFont(9, weight: .regular)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("\(oneTimeCouponsCount)")
                            .couponFont(20, weight: .bold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 2) {
                        Text("קופונים פעילים")
                            .couponFont(9, weight: .regular)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("\(activeCouponsCount)")
                            .couponFont(20, weight: .bold)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
                
                VStack(spacing: 6) {
                    Text("₪\(Int(totalActiveValue))")
                        .couponFont(34, weight: .bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text("נותר לשימוש")
                        .couponFont(13, weight: .regular)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var expiringCouponsView: some View {
        ZStack {
            WidgetStyle.alertGradient
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .couponFont(16, weight: .bold)
                        .foregroundColor(.white)
                    
                    Text("קופון עומד לפוג תוקף!")
                        .couponFont(12, weight: .bold)
                        .foregroundColor(.white)
                }
                
                if let firstExpiring = expiringThisWeek.first {
                    VStack(spacing: 4) {
                        Text(firstExpiring.company)
                            .couponFont(16, weight: .semibold)
                            .foregroundColor(.white)
                        
                        Text("₪\(Int(firstExpiring.remainingValue))")
                            .couponFont(24, weight: .bold)
                            .foregroundColor(.white)
                        
                        if let expirationDate = firstExpiring.expirationDate {
                            let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                            Text("נותרו \(daysLeft) ימים")
                                .couponFont(11, weight: .medium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                
                Text("מתחלף לסטטיסטיקות...")
                    .couponFont(8)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
        }
    }
}

// MARK: - Medium Widget

struct CouponCompaniesView: View {
    var entry: Provider.Entry
    
    private var couponsToShow: [WidgetCoupon] {
        let sorted = entry.coupons.sorted { coupon1, coupon2 in
            let order1 = coupon1.widgetDisplayOrder ?? 999
            let order2 = coupon2.widgetDisplayOrder ?? 999
            return order1 < order2
        }
        let first2 = Array(sorted.prefix(2))
        print("🎯 MEDIUM WIDGET: Displaying first 2 coupons in order:")
        for (index, coupon) in first2.enumerated() {
            print("   \(index+1). \(coupon.company) (Order: \(coupon.widgetDisplayOrder ?? 999))")
        }
        return first2
    }
    
    private var totalActiveValue: Double {
        return entry.totalRemainingValue
    }
    
    private var totalActiveCoupons: Int {
        return entry.activeCouponsCount
    }
    
    private func getCompanyLogo(for companyName: String) -> String {
        let normalizedInput = companyName.lowercased().trimmingCharacters(in: .whitespaces)
        
        let company = entry.companies.first { company in
            let normalizedCompanyName = company.name.lowercased().trimmingCharacters(in: .whitespaces)
            return normalizedCompanyName == normalizedInput
        }
        
        let imagePath = company?.imagePath ?? ""
        
        print("🖼️ Logo lookup for '\(companyName)':")
        print("   - Found: \(company != nil)")
        print("   - Image Path: '\(imagePath)'")
        
        return imagePath
    }
    
    var body: some View {
        ZStack {
            WidgetStyle.primaryGradient
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 8) {
                if couponsToShow.isEmpty {
                    VStack {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .couponFont(18)
                        Text("בחר עד 2 קופונים")
                            .couponFont(12)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                    ForEach(couponsToShow) { coupon in
                        CouponMediumCardView(
                            coupon: coupon,
                            logoPath: getCompanyLogo(for: coupon.company)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if couponsToShow.count == 1 {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.05))
                            .overlay(
                                Text("בחר קופון נוסף")
                                    .couponFont(12)
                                    .foregroundColor(.secondary)
                            )
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    Spacer()
                }
            }
            .padding()
        }
        .widgetBackground(Color.clear)
    }
}

// MARK: - Helper Functions

private func formatCouponCode(_ code: String) -> String {
    var formattedCode = ""
    for (index, character) in code.enumerated() {
        if index > 0 && index % 10 == 0 {
            formattedCode += "\n"
        }
        formattedCode += String(character)
    }
    return formattedCode
}

// MARK: - CompanyLogoView - גרסה מתוקנת שמשתמשת רק ב-AsyncImage

private struct CompanyLogoView: View {
    let company: String
    let logoPath: String
    
    private var companyImageURL: URL? {
        let trimmed = logoPath.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmed.isEmpty {
            let baseURL = "https://www.couponmasteril.com/static/"
            let fullURL = baseURL + trimmed
            
            if let url = URL(string: fullURL) {
                return url
            }
        }
        
        return nil
    }
    
    var body: some View {
        Group {
            if let url = companyImageURL,
               let imageData = try? Data(contentsOf: url),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            } else {
                fallbackLogo
            }
        }
        .frame(width: 60, height: 60)
    }
    
    private var fallbackLogo: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 60, height: 60)
            
            Text(String(company.prefix(2).uppercased()))
                .couponFont(18, weight: .bold)
                .foregroundColor(.blue)
        }
    }
}
// MARK: - Medium Coupon Card View

struct CouponMediumCardView: View {
    let coupon: WidgetCoupon
    let logoPath: String
    
    private var couponURL: URL? {
        URL(string: "couponmaster://coupon/\(coupon.id)")
    }
    
    private var decryptedCode: String {
        if let decrypted = WidgetEncryptionManager.decryptString(coupon.code) {
            return decrypted
        }
        return coupon.code
    }
    
    @Environment(\.layoutDirection) private var layoutDirection
    
    var body: some View {
        Link(destination: couponURL ?? URL(string: "couponmaster://")!) {
            HStack(spacing: 12) {
                CompanyLogoView(company: coupon.company, logoPath: logoPath)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(coupon.company)
                        .couponFont(15, weight: .semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("יתרה: \(Int(coupon.remainingValue))₪")
                        .couponFont(12, weight: .semibold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCouponCode(decryptedCode))
                        .couponFont(10, weight: .bold)
                        .foregroundColor(.blue)
                        .lineLimit(4)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                
                Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                    .couponFont(12, weight: .bold)
                    .foregroundColor(.gray)
                    .opacity(0.5)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .environment(\.layoutDirection, layoutDirection)
    }
}

// MARK: - Main Widget Configuration

@main
struct CouponManagerWidget: Widget {
    let kind: String = "CouponManagerWidget"
    
    init() {
        print("🎯 WIDGET INIT: CouponManagerWidget initialized")
    }

    var body: some WidgetConfiguration {
        print("🎯 WIDGET CONFIG: Widget configuration requested")
        let config = StaticConfiguration(kind: kind, provider: Provider()) { entry in
            print("🎯 WIDGET ENTRY: Creating widget entry view")
            return CouponManagerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ניהול קופונים")
        .description("עקוב אחר הקופונים שלך ותאריכי התפוגה")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        
        if #available(iOSApplicationExtension 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct CouponManagerWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                CouponStatsSmallView(entry: entry)
            case .systemMedium:
                ZStack {
                    WidgetStyle.primaryGradient.edgesIgnoringSafeArea(.all)
                    CouponCompaniesView(entry: entry)
                }
            case .systemLarge:
                ZStack {
                    WidgetStyle.primaryGradient.edgesIgnoringSafeArea(.all)
                    CouponLargeView(entry: entry)
                }
            default:
                CouponStatsSmallView(entry: entry)
            }
        }
    }
}

// MARK: - Large Widget

struct CouponLargeView: View {
    var entry: Provider.Entry
    
    private var couponsToShow: [WidgetCoupon] {
        let sorted = entry.coupons.sorted { coupon1, coupon2 in
            let order1 = coupon1.widgetDisplayOrder ?? 999
            let order2 = coupon2.widgetDisplayOrder ?? 999
            return order1 < order2
        }
        print("🎯 LARGE WIDGET: Displaying \(sorted.count) coupons in order:")
        for (index, coupon) in sorted.enumerated() {
            print("   \(index+1). \(coupon.company) (Order: \(coupon.widgetDisplayOrder ?? 999))")
        }
        return sorted
    }
    
    private func getCompanyLogo(for companyName: String) -> String {
        let normalizedInput = companyName.lowercased().trimmingCharacters(in: .whitespaces)
        
        let company = entry.companies.first { company in
            let normalizedCompanyName = company.name.lowercased().trimmingCharacters(in: .whitespaces)
            return normalizedCompanyName == normalizedInput
        }
        
        let imagePath = company?.imagePath ?? ""
                
        return imagePath
    }
    
    private var totalActiveCoupons: Int { entry.activeCouponsCount }
    private var totalActiveBalance: Double { entry.totalRemainingValue }
    
    var body: some View {
        VStack(spacing: 4) {
            // שורה אחת עם הלוגו בצד שמאל והמידע במרכז
            HStack(spacing: 12) {
                // הלוגו בצד שמאל
                if let uiImage = UIImage(named: "CouponLogo", in: Bundle.main, compatibleWith: nil) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .cornerRadius(8)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.2, green: 0.6, blue: 1.0),
                                        Color(red: 0.1, green: 0.5, blue: 0.9)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        VStack(spacing: 1) {
                            Text("%")
                                .couponFont(14, weight: .heavy)
                                .foregroundColor(.white)
                            
                            Text("✂")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                // הטקסט במרכז
                VStack(alignment: .center, spacing: 2) {
                    Text("קופונים פעילים: \(totalActiveCoupons)")
                        .couponFont(14, weight: .semibold)
                        .foregroundColor(.white)
                    
                    Text("יתרה: ₪\(Int(totalActiveBalance))")
                        .couponFont(14, weight: .medium)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

            VStack(spacing: 8) {
                if couponsToShow.isEmpty {
                    VStack {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .couponFont(18)
                        Text("No active coupons")
                            .couponFont(14)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(couponsToShow) { coupon in
                        CouponLargeCardView(
                            coupon: coupon,
                            logoPath: getCompanyLogo(for: coupon.company)
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .widgetBackground(Color.clear)
    }
}

private struct CouponLargeCardView: View {
    let coupon: WidgetCoupon
    let logoPath: String
    
    private var couponURL: URL? {
        URL(string: "couponmaster://coupon/\(coupon.id)")
    }
    
    private var decryptedCode: String {
        if let decrypted = WidgetEncryptionManager.decryptString(coupon.code) {
            return decrypted
        }
        return coupon.code
    }
    
    @Environment(\.layoutDirection) private var layoutDirection
    
    var body: some View {
        Link(destination: couponURL ?? URL(string: "couponmaster://")!) {
            HStack(spacing: 16) {
                CompanyLogoView(company: coupon.company, logoPath: logoPath)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(coupon.company)
                        .couponFont(14, weight: .bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("יתרה: \(Int(coupon.remainingValue))₪")
                        .couponFont(11, weight: .semibold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCouponCode(decryptedCode))
                        .couponFont(11, weight: .bold)
                        .foregroundColor(.blue)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .frame(width: 140, alignment: .trailing)
                
                Image(systemName: "chevron.left")
                    .couponFont(12)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}
