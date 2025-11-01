//
//  CompanyCouponsOrderingView.swift
//  CouponManagerApp
//
//  Manual ordering of coupons within a specific company screen.
//

import SwiftUI

struct CompanyCouponsOrderingView: View {
    let companyName: String
    let user: User
    let coupons: [Coupon]
    let companies: [Company]
    let onDone: () -> Void

    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var couponAPI = CouponAPIClient()
    @State private var localCoupons: [Coupon] = []
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    private var sortedForDisplay: [Coupon] {
        localCoupons.sorted { lhs, rhs in
            let lo = lhs.companyDisplayOrder ?? Int.max
            let ro = rhs.companyDisplayOrder ?? Int.max
            if lo != ro { return lo < ro }
            if let le = lhs.expirationDate, let re = rhs.expirationDate, le != re { return le < re }
            return lhs.remainingValue > rhs.remainingValue
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let msg = errorMessage {
                    Text(msg)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                }

                // Always-on reordering list
                List {
                    ForEach(sortedForDisplay) { coupon in
                        HStack {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(coupon.decryptedCode)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                HStack(spacing: 8) {
                                    if let exp = coupon.expirationDate {
                                        Text("תוקף: \(formatDate(exp))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("ללא תפוגה")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text("נותר ₪\(Int(coupon.remainingValue))")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            Spacer()
                            // Company logo / initial
                            CompanyLogoCircle(companyName: coupon.company, companies: companies)
                        }
                    }
                    .onMove(perform: move)
                }
                .environment(\.editMode, .constant(.active))

                Button(action: saveOrder) {
                    if isSaving {
                        ProgressView().padding()
                    } else {
                        Text("שמור סידור")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appBlue)
                            .cornerRadius(12)
                            .padding()
                    }
                }
                .disabled(isSaving)
            }
            .navigationTitle("סידור קופונים – \(companyName)")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("סגור") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                // Seed local coupons and ensure only target company
                let companyCoupons = coupons.filter { $0.company.caseInsensitiveCompare(companyName) == .orderedSame }
                // Initialize missing orders to keep stable sequence based on current appearance
                var initial = companyCoupons
                let maxExisting = initial.compactMap { $0.companyDisplayOrder }.max() ?? 0
                var next = maxExisting + 1
                for i in 0..<initial.count {
                    if initial[i].companyDisplayOrder == nil {
                        initial[i].companyDisplayOrder = next
                        next += 1
                    }
                }
                self.localCoupons = initial
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var arr = sortedForDisplay
        arr.move(fromOffsets: source, toOffset: destination)
        // Reassign sequential orders starting at 1
        for (idx, c) in arr.enumerated() {
            if let index = localCoupons.firstIndex(where: { $0.id == c.id }) {
                localCoupons[index].companyDisplayOrder = idx + 1
            }
        }
    }

    private func saveOrder() {
        isSaving = true
        errorMessage = nil

        // Persist all display orders
        let arr = sortedForDisplay
        let group = DispatchGroup()
        var encounteredError: Error? = nil
        for (idx, coupon) in arr.enumerated() {
            group.enter()
            let newOrder = idx + 1
            couponAPI.updateCoupon(couponId: coupon.id, data: ["company_display_order": newOrder]) { result in
                if case .failure(let error) = result {
                    encounteredError = error
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            isSaving = false
            if let err = encounteredError {
                errorMessage = err.localizedDescription
            } else {
                onDone()
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "he_IL")
        return formatter.string(from: date)
    }
}

private struct CompanyLogoCircle: View {
    let companyName: String
    let companies: [Company]

    private var logoURL: URL? {
        if let c = companies.first(where: { $0.name.lowercased() == companyName.lowercased() }) {
            return URL(string: "https://www.couponmasteril.com/static/" + c.imagePath)
        }
        return nil
    }

    var body: some View {
        Group {
            if let url = logoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure(_):
                        fallback
                    case .empty:
                        ProgressView()
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(Color.appBlue.opacity(0.2))
            Text(String(companyName.prefix(1).uppercased()))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(Color.appBlue)
        }
    }
}

