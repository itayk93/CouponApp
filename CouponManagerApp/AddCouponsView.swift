//
//  AddCouponsView.swift
//  CouponManagerApp
//
//  מסך הוספת קופונים מרובים
//

import SwiftUI

struct AddCouponsView: View {
    let user: User
    let companies: [Company]
    let onUpdate: () -> Void
    
    @StateObject private var couponAPI = CouponAPIClient()
    @State private var coupons: [CouponCreateRequest] = [CouponCreateRequest.empty()]
    @State private var isLoading = false
    @State private var showingInstructions = false
    @State private var errorMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top navigation buttons
                topNavigationBar
                
                // Title
                headerView
                
                // Action buttons
                actionButtonsRow
                
                // Help button
                helpButtonView
                
                // Instructions panel
                if showingInstructions {
                    instructionsPanel
                }
                
                // Error message
                if !errorMessage.isEmpty {
                    errorMessageView
                }
                
                // Coupons forms
                couponsFormsView
                
                // Add another coupon button
                addCouponButtonView
                
                // Submit button
                submitButtonView
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Header
    private var headerView: some View {
        Text("הוספת קופונים מרובים")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(Color.appBlue)
            .multilineTextAlignment(.center)
    }
    
    // MARK: - Action Buttons Row
    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: AddCouponView(user: user, companies: companies, preSelectedCompany: nil, onCouponAdded: onUpdate, prefilledData: nil)) {
                ActionButtonSmall(
                    title: "קופון יחיד",
                    icon: "plus.circle",
                    color: Color.appBlue
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: UploadCouponsView(user: user, companies: companies, onUpdate: onUpdate)) {
                ActionButtonSmall(
                    title: "העלאת קובץ",
                    icon: "doc.fill",
                    color: Color.appBlue
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Help Button
    private var helpButtonView: some View {
        Button(action: { showingInstructions.toggle() }) {
            HStack {
                Image(systemName: "questionmark.circle")
                Text("הסבר")
                    .fontWeight(.medium)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.appBlue)
            .foregroundColor(.white)
            .cornerRadius(20)
        }
    }
    
    // MARK: - Instructions Panel
    private var instructionsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(Color.appBlue)
                Text("איך להוסיף קופונים מרובים?")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InstructionRow(number: 1, text: "מלא את פרטי הקופון הראשון בטופס למטה.")
                InstructionRow(number: 2, text: "לאחר מילוי הפרטים, לחץ על \"הוספת קופון נוסף\" אם ברצונך להוסיף קופונים נוספים.")
                InstructionRow(number: 3, text: "באפשרותך לשכפל קופון קיים על ידי לחיצה על כפתור \"שכפול קופון\".")
                InstructionRow(number: 4, text: "כשסיימת למלא את כל הקופונים, לחץ על \"הוספת הקופונים לארנק\".")
            }
            
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("שים לב: שדות עם כוכבית (*) הם שדות חובה.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Error Message
    private var errorMessageView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.subheadline)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Coupons Forms
    private var couponsFormsView: some View {
        VStack(spacing: 16) {
            ForEach(coupons.indices, id: \.self) { index in
                CouponFormView(
                    coupon: $coupons[index],
                    companies: companies,
                    couponNumber: index + 1,
                    onDuplicate: {
                        duplicateCoupon(at: index)
                    },
                    onRemove: coupons.count > 1 ? {
                        removeCoupon(at: index)
                    } : nil
                )
            }
        }
    }
    
    // MARK: - Add Coupon Button
    private var addCouponButtonView: some View {
        Button(action: addNewCoupon) {
            HStack {
                Image(systemName: "plus.circle")
                Text("הוספת קופון נוסף")
                    .fontWeight(.medium)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.1))
            .foregroundColor(.green)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Submit Button
    private var submitButtonView: some View {
        Button(action: submitCoupons) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                }
                Text(isLoading ? "מוסיף קופונים..." : "הוספת הקופונים לארנק")
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isFormValid ? Color.appBlue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isFormValid || isLoading)
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        return coupons.allSatisfy { coupon in
            !coupon.company.isEmpty &&
            !coupon.code.isEmpty &&
            coupon.value > 0 &&
            coupon.cost >= 0
        }
    }
    
    // MARK: - Helper Functions
    private func addNewCoupon() {
        coupons.append(CouponCreateRequest.empty())
    }
    
    private func removeCoupon(at index: Int) {
        guard coupons.count > 1 else { return }
        coupons.remove(at: index)
    }
    
    private func duplicateCoupon(at index: Int) {
        let originalCoupon = coupons[index]
        let duplicatedCoupon = CouponCreateRequest(
            code: "", // Clear the code for the duplicate
            description: originalCoupon.description,
            value: originalCoupon.value,
            cost: originalCoupon.cost,
            company: originalCoupon.company,
            expiration: originalCoupon.expiration,
            source: originalCoupon.source,
            buyMeCouponUrl: originalCoupon.buyMeCouponUrl,
            straussCouponUrl: originalCoupon.straussCouponUrl,
            xgiftcardCouponUrl: originalCoupon.xgiftcardCouponUrl,
            xtraCouponUrl: originalCoupon.xtraCouponUrl,
            isForSale: originalCoupon.isForSale,
            isOneTime: originalCoupon.isOneTime,
            purpose: originalCoupon.purpose
        )
        coupons.insert(duplicatedCoupon, at: index + 1)
    }
    
    private func submitCoupons() {
        isLoading = true
        errorMessage = ""
        
        let group = DispatchGroup()
        var hasError = false
        
        for coupon in coupons {
            group.enter()
            couponAPI.createCoupon(coupon, userId: user.id) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    hasError = true
                    DispatchQueue.main.async {
                        self.errorMessage = "שגיאה בהוספת קופון: \(error.localizedDescription)"
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
            if !hasError {
                self.onUpdate()
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - Coupon Form View
struct CouponFormView: View {
    @Binding var coupon: CouponCreateRequest
    let companies: [Company]
    let couponNumber: Int
    let onDuplicate: () -> Void
    let onRemove: (() -> Void)?
    
    @State private var showingOtherCompany = false
    @State private var showingCardFields = false
    @State private var showingPurpose = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with coupon number and actions
            HStack {
                Text("קופון \(couponNumber)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: onDuplicate) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("שכפול")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appBlue.opacity(0.1))
                        .foregroundColor(Color.appBlue)
                        .cornerRadius(8)
                    }
                    
                    if let onRemove = onRemove {
                        Button(action: onRemove) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .padding(6)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            VStack(spacing: 12) {
                // Company selection
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("שם החברה")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("*")
                            .foregroundColor(.red)
                    }
                    
                    Picker("בחר חברה", selection: $coupon.company) {
                        Text("בחר").tag("")
                        ForEach(companies, id: \.name) { company in
                            Text(company.name).tag(company.name)
                        }
                        Text("אחר").tag("other")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onChange(of: coupon.company) { _, newValue in
                        showingOtherCompany = (newValue == "other")
                    }
                }
                
                // Other company field
                if showingOtherCompany {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("שם חברה חדשה")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("הזן שם החברה", text: $coupon.company)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                // Code field
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("קוד קופון")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("*")
                            .foregroundColor(.red)
                    }
                    
                    TextField("הזן קוד הקופון", text: $coupon.code)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Value and cost fields
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("ערך הקופון")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("*")
                                .foregroundColor(.red)
                        }
                        
                        TextField("0", value: $coupon.value, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("עלות")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("*")
                                .foregroundColor(.red)
                        }
                        
                        TextField("0", value: $coupon.cost, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                }
                
                // Expiration date
                VStack(alignment: .leading, spacing: 6) {
                    Text("תאריך תפוגה")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let expiration = coupon.expiration, !expiration.isEmpty {
                        DatePicker("", selection: Binding(
                            get: { 
                                ISO8601DateFormatter().date(from: expiration) ?? Date()
                            },
                            set: { date in
                                coupon.expiration = ISO8601DateFormatter().string(from: date)
                            }
                        ), displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                    } else {
                        Button("הוסף תאריך תפוגה") {
                            coupon.expiration = ISO8601DateFormatter().string(from: Date())
                        }
                        .foregroundColor(Color.appBlue)
                    }
                }
                
                // Description
                VStack(alignment: .leading, spacing: 6) {
                    Text("תיאור הקופון")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("תיאור אופציונלי", text: Binding(
                        get: { coupon.description ?? "" },
                        set: { coupon.description = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // One-time use toggle
                Toggle("קופון לשימוש חד פעמי", isOn: $coupon.isOneTime)
                    .onChange(of: coupon.isOneTime) { _, newValue in
                        showingPurpose = newValue
                        if !newValue {
                            coupon.purpose = nil
                        }
                    }
                
                // Purpose field for one-time coupons
                if showingPurpose {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("מטרת הקופון")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("למה הקופון מיועד?", text: Binding(
                            get: { coupon.purpose ?? "" },
                            set: { coupon.purpose = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

// MARK: - Supporting Views
struct ActionButtonSmall: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color, lineWidth: 1)
        )
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color.appBlue)
            
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - Extension for empty coupon
extension CouponCreateRequest {
    static func empty() -> CouponCreateRequest {
        return CouponCreateRequest(
            code: "",
            description: nil,
            value: 0,
            cost: 0,
            company: "",
            expiration: nil,
            source: nil,
            buyMeCouponUrl: nil,
            straussCouponUrl: nil,
            xgiftcardCouponUrl: nil,
            xtraCouponUrl: nil,
            isForSale: false,
            isOneTime: false,
            purpose: nil
        )
    }
}

#Preview {
    NavigationView {
        AddCouponsView(
            user: User(
                id: 1,
                email: "test@test.com",
                password: nil,
                firstName: "טסט",
                lastName: "יוזר",
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
            companies: [
                Company(id: 1, name: "Carrefour", imagePath: "carrefour.png", companyCount: 5),
                Company(id: 2, name: "BuyMe", imagePath: "buyme.png", companyCount: 3)
            ],
            onUpdate: {}
        )
    }
}