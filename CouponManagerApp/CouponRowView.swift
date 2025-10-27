//
//  CouponRowView.swift
//  CouponManagerApp
//
//  רכיב תצוגת קופון בודד ברשימה
//

import SwiftUI

struct CouponRowView: View {
    let coupon: Coupon
    var companies: [Company] = [] // Optional companies array to get logo info
    
    // Computed properties for decrypted content
    private var decryptedCode: String {
        return EncryptionManager.decryptString(coupon.code) ?? coupon.code
    }
    
    private var decryptedDescription: String? {
        guard let description = coupon.description, !description.isEmpty else { return nil }
        return EncryptionManager.decryptString(description)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 12) {
                // Company logo placeholder
                companyLogo
                
                // Coupon details
                VStack(alignment: .leading, spacing: 6) {
                    // Company name and status
                    HStack(spacing: 6) {
                        Text(coupon.company)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        // Indicator that a special message exists (no content shown here)
                        if let msg = coupon.specialMessage, !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                                .accessibilityLabel("יש הודעה חשובה")
                        }

                        Spacer()

                        statusBadge
                    }
                    
                    // Coupon code - large and prominent, centered
                    if !decryptedCode.isEmpty {
                        HStack {
                            Spacer()
                            Text(decryptedCode)
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(colorScheme == .dark ? .white : Color.appBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(colorScheme == .dark ? Color.appBlue.opacity(0.2) : Color.appBlue.opacity(0.1))
                                )
                            Spacer()
                        }
                    }
                    
                    // Value information
                    HStack {
                        valueInfo
                        
                        Spacer()
                        
                        expirationInfo
                    }
                }
                
                // Action indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            // Usage progress bar (only for non-one-time coupons)
            if coupon.usedValue > 0 && !coupon.isOneTime {
                usageProgressBar
            }
        }
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: shadowColor, radius: 3, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // MARK: - Company Logo
    private var companyLogo: some View {
        Group {
            let company = companies.first { $0.name == coupon.company }
            
            if let company = company {
                // Show actual company logo
                AsyncImage(url: companyImageURL(for: company)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    // Fallback to text initials
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.appBlue.opacity(0.1))
                        
                        Text(String(coupon.company.prefix(2)))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color.appBlue)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Fallback when company not found
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appBlue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Text(String(coupon.company.prefix(2)))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color.appBlue)
                }
            }
        }
    }
    
    private func companyImageURL(for company: Company) -> URL? {
        let baseURL = "https://www.couponmasteril.com/static/"
        return URL(string: baseURL + company.imagePath)
    }
    
    // MARK: - Status Badge
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
    }
    
    // MARK: - Value Info
    private var valueInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            if coupon.isOneTime {
                // For one-time coupons, show purpose instead of remaining value
                if let purpose = coupon.purpose, !purpose.isEmpty {
                    Text(purpose)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appBlue)
                } else {
                    Text("שימוש חד-פעמי")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appBlue)
                }
                
                Text("₪\(Int(coupon.value))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Regular coupon logic
                if coupon.usedValue > 0 {
                    HStack(spacing: 4) {
                        Text("₪\(Int(coupon.remainingValue))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        Text("מתוך ₪\(Int(coupon.value))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("₪\(Int(coupon.value))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            if coupon.cost > 0 && !coupon.isOneTime {
                Text("עלות: ₪\(Int(coupon.cost))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Expiration Info
    private var expirationInfo: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let expirationDate = coupon.expirationDate {
                let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                
                if coupon.isFullyUsed {
                    // Don't show expiration info for fully used coupons
                    Text("100%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                } else if coupon.isExpired {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text("פג תוקף")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                } else if daysUntilExpiration <= 7 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("\(daysUntilExpiration) ימים")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                } else {
                    Text(coupon.formattedExpirationDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("ללא תפוגה")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Usage Progress Bar
    private var usageProgressBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text("שימוש: \(Int(coupon.usagePercentage))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if coupon.isOneTime {
                    // For one-time coupons, show purpose instead of remaining value
                    if let purpose = coupon.purpose, !purpose.isEmpty {
                        Text("מטרה: \(purpose)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("שימוש חד-פעמי")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("נותר: ₪\(Int(coupon.remainingValue))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: coupon.usagePercentage, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .frame(height: 4)
                .background(Color.gray.opacity(colorScheme == .dark ? 0.4 : 0.2))
                .cornerRadius(2)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    // MARK: - Computed Properties
    private var statusColor: Color {
        if coupon.isFullyUsed { return .gray }
        if coupon.isExpired { return .red }
        if coupon.status == "פעיל" { return .green }
        return .orange
    }
    
    private var statusText: String {
        if coupon.isFullyUsed { return "מנוצל" }
        if coupon.isExpired { return "פג תוקף" }
        return coupon.status
    }
    
    private var borderColor: Color {
        let baseOpacity: Double = colorScheme == .dark ? 0.5 : 0.2
        
        if coupon.isFullyUsed { 
            return .gray.opacity(colorScheme == .dark ? 0.6 : 0.3) 
        }
        if coupon.isExpired { 
            return .red.opacity(colorScheme == .dark ? 0.6 : 0.3) 
        }
        return .gray.opacity(baseOpacity)
    }
    
    private var progressColor: Color {
        if coupon.usagePercentage >= 90 { return .red }
        if coupon.usagePercentage >= 70 { return .orange }
        return Color.appBlue
    }
    
    // MARK: - Dark Mode Support
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackgroundColor: Color {
        switch colorScheme {
        case .dark:
            return Color(.systemGray6) // Light gray for dark mode
        case .light:
            return Color(.systemBackground) // White for light mode
        @unknown default:
            return Color(.systemBackground)
        }
    }
    
    private var shadowColor: Color {
        switch colorScheme {
        case .dark:
            return Color.clear // No shadow in dark mode
        case .light:
            return Color.black.opacity(0.08) // Subtle shadow in light mode
        @unknown default:
            return Color.black.opacity(0.08)
        }
    }
}

// MARK: - Extension for debugging decryption
extension CouponRowView {
    func debugDecryption() {
        print("🧪 Debug decryption in CouponRowView:")
        print("Original code: \(coupon.code)")
        print("Decrypted code: \(decryptedCode)")
        
        if let desc = coupon.description {
            print("Original description: \(desc)")
            print("Decrypted description: \(decryptedDescription ?? "nil")")
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Active coupon with encrypted data
        CouponRowView(coupon: Coupon(
            id: 1,
            code: "gAAAAABozqEehEReNYFE1jtEbhr3XVF3HfbFFa7cF70V_C_t5talP98A26ISg86JjgwCUGabT1MmaU_c5EkO-0wLEah5de67dg==", // Example encrypted code
            description: "gAAAAABozqEeOM1r0yu1bqV...", // Example encrypted description
            value: 100.0,
            cost: 80.0,
            company: "Carrefour",
            expiration: "2024-12-31",
            source: "manual",
            buyMeCouponUrl: nil,
            straussCouponUrl: nil,
            xgiftcardCouponUrl: nil,
            xtraCouponUrl: nil,
            dateAdded: "2024-01-01T00:00:00Z",
            usedValue: 30.0,
            status: "פעיל",
            isAvailable: true,
            isForSale: false,
            isOneTime: false,
            purpose: nil,
            excludeSaving: false,
            autoDownloadDetails: nil,
            userId: 1,
            cvv: nil,
            cardExp: nil
        ), companies: [
            Company(id: 2, name: "Carrefour", imagePath: "images/carrefour.png", companyCount: 4)
        ])
        
        // Plain text coupon (fallback)
        CouponRowView(coupon: Coupon(
            id: 2,
            code: "PLAIN_CODE",
            description: "תיאור רגיל ללא הצפנה",
            value: 50.0,
            cost: 40.0,
            company: "BuyMe",
            expiration: "2024-12-31",
            source: "manual",
            buyMeCouponUrl: nil,
            straussCouponUrl: nil,
            xgiftcardCouponUrl: nil,
            xtraCouponUrl: nil,
            dateAdded: "2023-12-01T00:00:00Z",
            usedValue: 0.0,
            status: "פעיל",
            isAvailable: true,
            isForSale: false,
            isOneTime: false,
            purpose: nil,
            excludeSaving: false,
            autoDownloadDetails: nil,
            userId: 1,
            cvv: nil,
            cardExp: nil
        ), companies: [
            Company(id: 54, name: "BuyMe", imagePath: "images/BuyMe.png", companyCount: 8)
        ])
    }
    .padding()
}
