//
//  WidgetCouponsManagementView.swift
//  CouponManagerApp
//
//  מסך ניהול קופונים להצגה בווידג'ט
//

import SwiftUI
import WidgetKit

struct WidgetCouponsManagementView: View {
    let user: User
    let onUpdate: () -> Void
    
    @StateObject private var couponAPI = CouponAPIClient()
    @State private var allCoupons: [Coupon] = []
    @State private var isLoading = false
    @Environment(\.presentationMode) var presentationMode
    
    private var activeCoupons: [Coupon] {
        allCoupons.filter { $0.status == "פעיל" && !$0.isExpired && !$0.isFullyUsed }
    }
    
    private var widgetCoupons: [Coupon] {
        activeCoupons.filter { $0.showInWidget == true }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header Info
                            headerSection
                            
                            // Currently Selected Coupons
                            if !widgetCoupons.isEmpty {
                                selectedCouponsSection
                            }
                            
                            // Available Coupons to Add
                            availableCouponsSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("ניהול קופונים בווידג'ט")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("סגור") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                loadCoupons()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title2)
                    .foregroundColor(Color.appBlue)
                
                Text("בחר עד 4 קופונים להצגה בווידג'ט")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text("\(widgetCoupons.count)/4 קופונים נבחרו")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.appBlue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Selected Coupons Section
    private var selectedCouponsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("קופונים בווידג'ט")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(widgetCoupons) { coupon in
                WidgetCouponRow(
                    coupon: coupon,
                    isSelected: true,
                    action: {
                        toggleCouponInWidget(coupon)
                    }
                )
            }
        }
    }
    
    // MARK: - Available Coupons Section
    private var availableCouponsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("קופונים זמינים")
                .font(.headline)
                .fontWeight(.semibold)
            
            let availableCoupons = activeCoupons.filter { $0.showInWidget != true }
            
            if availableCoupons.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("כל הקופונים הפעילים כבר נבחרו")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(availableCoupons) { coupon in
                    WidgetCouponRow(
                        coupon: coupon,
                        isSelected: false,
                        action: {
                            toggleCouponInWidget(coupon)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func loadCoupons() {
        isLoading = true
        couponAPI.fetchUserCoupons(userId: user.id) { result in
            isLoading = false
            switch result {
            case .success(let coupons):
                allCoupons = coupons
            case .failure(let error):
                print("Failed to load coupons: \(error)")
            }
        }
    }
    
    private func toggleCouponInWidget(_ coupon: Coupon) {
        let newValue = !(coupon.showInWidget ?? false)
        
        // Check limit when adding
        if newValue && widgetCoupons.count >= 4 {
            return // Already at limit
        }
        
        couponAPI.updateCoupon(couponId: coupon.id, data: ["show_in_widget": newValue]) { result in
            switch result {
            case .success:
                // Update local state
                if let index = allCoupons.firstIndex(where: { $0.id == coupon.id }) {
                    var updatedCoupon = allCoupons[index]
                    updatedCoupon.showInWidget = newValue
                    allCoupons[index] = updatedCoupon
                }
                
                // שמור את הנתונים המעודכנים ל-shared container
                couponAPI.fetchUserCoupons(userId: user.id) { fetchResult in
                    if case .success(let updatedCoupons) = fetchResult {
                        AppGroupManager.shared.saveCouponsToSharedContainer(updatedCoupons)
                        print("✅ Updated shared container with new widget coupon data")
                    }
                }
                
                // Reload widget
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadTimelines(ofKind: "CouponManagerWidget")
                }
                
                // Notify parent
                onUpdate()
                
            case .failure(let error):
                print("Failed to update show_in_widget: \(error)")
            }
        }
    }
}

// MARK: - Widget Coupon Row
struct WidgetCouponRow: View {
    let coupon: Coupon
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Company initial or logo
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.appBlue.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Text(String(coupon.company.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? Color.appBlue : .gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(coupon.company)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("₪\(Int(coupon.remainingValue)) נותר")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        
                        if let expiration = coupon.expirationDate {
                            let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
                            if daysLeft <= 7 && daysLeft >= 0 {
                                Text("• \(daysLeft) ימים")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.appBlue)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
            .padding()
            .background(isSelected ? Color.appBlue.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.appBlue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    WidgetCouponsManagementView(
        user: User(
            id: 1,
            email: "test@test.com",
            password: nil,
            firstName: "Test",
            lastName: "User",
            age: nil,
            gender: "male",
            region: nil,
            isConfirmed: true,
            isAdmin: false,
            slots: 10,
            slotsAutomaticCoupons: 5,
            createdAt: nil,
            profileDescription: nil,
            profileImage: nil,
            couponsSoldCount: 0,
            isDeleted: false,
            dismissedExpiringAlertAt: nil,
            dismissedMessageId: nil,
            googleId: nil,
            newsletterSubscription: false,
            telegramMonthlySummary: false,
            newsletterImage: nil,
            showWhatsappBanner: false,
            faceIdEnabled: false
        ),
        onUpdate: {}
    )
}
