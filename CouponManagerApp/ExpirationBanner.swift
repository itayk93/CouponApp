//
//  ExpirationBanner.swift
//  CouponManagerApp
//
//  באנר התראה עבור קופונים שעומדים לפוג תוקף בשבוע הקרוב
//

import SwiftUI

struct ExpirationBanner: View {
    let expiringCoupons: [Coupon]
    let onTap: (Coupon) -> Void
    
    var body: some View {
        if !expiringCoupons.isEmpty {
            VStack(spacing: 0) {
                ForEach(expiringCoupons.prefix(3)) { coupon in
                    bannerRow(for: coupon)
                        .onTapGesture {
                            onTap(coupon)
                        }
                }
                
                if expiringCoupons.count > 3 {
                    additionalCouponsRow()
                }
            }
            .background(Color.red.opacity(0.1))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.red.opacity(0.3)),
                alignment: .bottom
            )
        }
    }
    
    private func bannerRow(for coupon: Coupon) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("קופון \(coupon.company) עומד לפוג!")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Text(expirationText(for: coupon))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.red)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.05))
    }
    
    private func additionalCouponsRow() -> some View {
        HStack {
            Image(systemName: "ellipsis")
                .foregroundColor(.red)
                .font(.title2)
            
            Text("ועוד \(expiringCoupons.count - 3) קופונים עומדים לפוג תוקף")
                .font(.headline)
                .foregroundColor(.red)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.red)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.08))
    }
    
    private func expirationText(for coupon: Coupon) -> String {
        guard let expirationDate = coupon.expirationDate else {
            return "אין תאריך תפוגה"
        }
        
        let calendar = Calendar.current
        let today = Date()
        let daysLeft = calendar.dateComponents([.day], from: today, to: expirationDate).day ?? 0
        
        switch daysLeft {
        case 0:
            return "פג תוקף היום!"
        case 1:
            return "פג תוקף מחר"
        case 2:
            return "פג תוקף בעוד יומיים"
        default:
            return "פג תוקף בעוד \(daysLeft) ימים"
        }
    }
}

extension Coupon {
    var isExpiringInWeek: Bool {
        guard let expirationDate = expirationDate else { return false }
        
        let calendar = Calendar.current
        let today = Date()
        let daysLeft = calendar.dateComponents([.day], from: today, to: expirationDate).day ?? -1
        
        return daysLeft >= 0 && daysLeft <= 7
    }
}

#Preview {
    ExpirationBanner(expiringCoupons: []) { coupon in
        print("Tapped coupon: \(coupon.id)")
    }
}