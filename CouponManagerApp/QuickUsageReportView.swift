//
//  QuickUsageReportView.swift
//  CouponManagerApp
//
//  Quick usage report dashboard matching website design
//

import SwiftUI

struct QuickUsageReportView: View {
    let user: User
    let coupons: [Coupon]
    let onUsageReported: () -> Void
    
    @StateObject private var couponAPI = CouponAPIClient()
    @State private var selectedCoupon: Coupon?
    @State private var showingUsageSheet = false
    @Environment(\.presentationMode) var presentationMode
    
    // Sort coupons by remaining value (highest first)
    private var sortedCoupons: [Coupon] {
        coupons.sorted { $0.remainingValue > $1.remainingValue }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Instructions
                        instructionsSection
                        
                        // Coupons list
                        couponsListSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("דיווח מהיר על שימוש")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("סגור") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(item: $selectedCoupon) { coupon in
                UsageCouponSheet(coupon: coupon) { amount, details in
                    recordUsage(for: coupon, amount: amount, details: details)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
            }
            
            // Title and description
            VStack(spacing: 4) {
                Text("דיווח מהיר על שימוש")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("בחר קופון כדי לרשום שימוש מהיר")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Instructions Section
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color.appBlue)
                Text("איך זה עובד:")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("1.")
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appBlue)
                    Text("בחר קופון מהרשימה למטה")
                    Spacer()
                }
                
                HStack {
                    Text("2.")
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appBlue)
                    Text("הזן את סכום השימוש")
                    Spacer()
                }
                
                HStack {
                    Text("3.")
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appBlue)
                    Text("הוסף פרטים (אופציונלי) ואשר")
                    Spacer()
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Coupons List Section
    private var couponsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("הקופונים הפעילים שלך")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(sortedCoupons.count) קופונים")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if sortedCoupons.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "ticket")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("אין קופונים פעילים")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("הוסף קופונים כדי להתחיל לעקוב אחרי השימוש")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(sortedCoupons) { coupon in
                        QuickUsageCouponRow(coupon: coupon) {
                            selectedCoupon = coupon
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func recordUsage(for coupon: Coupon, amount: Double, details: String) {
        let usageRequest = CouponUsageRequest(
            usedAmount: amount,
            action: "use",
            details: details
        )
        
        couponAPI.updateCouponUsage(couponId: coupon.id, usageRequest: usageRequest) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Usage recorded successfully for coupon \(coupon.id)")
                    onUsageReported()
                case .failure(let error):
                    print("❌ Failed to record usage: \(error)")
                }
            }
        }
    }
}

// MARK: - Quick Usage Coupon Row
struct QuickUsageCouponRow: View {
    let coupon: Coupon
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Company logo placeholder
                ZStack {
                    Circle()
                        .fill(Color.appBlue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Text(String(coupon.company.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color.appBlue)
                }
                
                // Coupon info
                VStack(alignment: .leading, spacing: 2) {
                    Text(coupon.company)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("נותר: ₪\(Int(coupon.remainingValue))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    QuickUsageReportView(
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
            faceIdEnabled: false
        ),
        coupons: [],
        onUsageReported: {}
    )
}