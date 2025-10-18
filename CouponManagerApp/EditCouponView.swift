//
//  EditCouponView.swift
//  CouponManagerApp
//
//  מסך עריכת קופון קיים
//

import SwiftUI

struct EditCouponView: View {
    let coupon: Coupon
    let onUpdate: () -> Void
    
    @StateObject private var couponAPI = CouponAPIClient()
    @State private var availableCompanies: [Company] = []
    @State private var isLoadingCompanies = false
    @State private var code: String
    @State private var description: String
    @State private var value: String
    @State private var cost: String
    @State private var discountPercentage: String
    @State private var selectedCompany: String
    @State private var customCompany = ""
    @State private var expiration = Date()
    @State private var hasExpiration: Bool
    @State private var source: String
    @State private var buyMeUrl: String
    @State private var straussUrl: String
    @State private var xgiftcardUrl: String
    @State private var hasStraussUrl: Bool
    @State private var hasXGiftCardUrl: Bool
    @State private var hasXtraUrl: Bool
    @State private var xtraUrl: String
    @State private var isOneTime: Bool
    @State private var purpose: String
    @State private var includeCardInfo: Bool
    @State private var cvv: String
    @State private var cardExpiry: String
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showingCompanyPicker = false
    
    @Environment(\.presentationMode) var presentationMode
    
    init(coupon: Coupon, onUpdate: @escaping () -> Void) {
        self.coupon = coupon
        self.onUpdate = onUpdate
        
        // Initialize state variables with coupon data
        _code = State(initialValue: coupon.decryptedCode)
        _description = State(initialValue: coupon.decryptedDescription ?? "")
        _value = State(initialValue: String(format: "%.2f", coupon.value))
        _cost = State(initialValue: String(format: "%.2f", coupon.cost))
        _selectedCompany = State(initialValue: coupon.company)
        _hasExpiration = State(initialValue: coupon.expiration != nil)
        _source = State(initialValue: coupon.source ?? "")
        _buyMeUrl = State(initialValue: coupon.buyMeCouponUrl ?? "")
        _straussUrl = State(initialValue: coupon.straussCouponUrl ?? "")
        _xgiftcardUrl = State(initialValue: coupon.xgiftcardCouponUrl ?? "")
        _xtraUrl = State(initialValue: coupon.xtraCouponUrl ?? "")
        _hasStraussUrl = State(initialValue: !(coupon.straussCouponUrl?.isEmpty ?? true))
        _hasXGiftCardUrl = State(initialValue: !(coupon.xgiftcardCouponUrl?.isEmpty ?? true))
        _hasXtraUrl = State(initialValue: !(coupon.xtraCouponUrl?.isEmpty ?? true))
        _isOneTime = State(initialValue: coupon.isOneTime)
        _purpose = State(initialValue: coupon.purpose ?? "")
        _includeCardInfo = State(initialValue: !(coupon.decryptedCvv?.isEmpty ?? true) || !(coupon.cardExp?.isEmpty ?? true))
        _cvv = State(initialValue: coupon.decryptedCvv ?? "")
        _cardExpiry = State(initialValue: coupon.cardExp ?? "")
        
        // Calculate discount percentage
        let discountValue = coupon.value > 0 ? ((coupon.value - coupon.cost) / coupon.value) * 100 : 0
        _discountPercentage = State(initialValue: String(format: "%.2f", discountValue))
        
        // Set expiration date
        if let expirationString = coupon.expiration,
           let date = ISO8601DateFormatter().date(from: expirationString + "T00:00:00Z") {
            _expiration = State(initialValue: date)
        } else {
            _expiration = State(initialValue: Date())
        }
    }
    
    private var companyNames: [String] {
        availableCompanies.map { $0.name }.sorted()
    }
    
    private var finalCompanyName: String {
        if selectedCompany == "אחר" {
            return customCompany
        }
        return selectedCompany
    }
    
    private var isFormValid: Bool {
        let costValue = Double(cost) ?? 0
        let valueAmount = Double(value) ?? 0
        let discountValue = Double(discountPercentage) ?? 0
        
        // Special case: cost is exactly 0 and value is positive, set discount to 100%
        if costValue == 0 && valueAmount > 0 {
            return !finalCompanyName.isEmpty && !code.isEmpty
        }
        
        let validFields = [
            costValue >= 0,
            valueAmount > 0,
            discountValue > 0 && discountValue <= 100
        ].filter { $0 }.count
        
        return !finalCompanyName.isEmpty && !code.isEmpty && validFields >= 2
    }
    
    private var validationMessage: String {
        let costValue = Double(cost) ?? 0
        let valueAmount = Double(value) ?? 0
        let discountValue = Double(discountPercentage) ?? 0
        
        let validFields = [
            costValue >= 0,
            valueAmount > 0,
            discountValue > 0 && discountValue <= 100
        ].filter { $0 }.count
        
        if !finalCompanyName.isEmpty && !code.isEmpty && validFields < 2 {
            return "יש למלא לפחות שניים מהשדות: מחיר קופון, ערך קופון, אחוז הנחה, בערך גדול מ-0."
        }
        
        return ""
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    Text("עריכת קופון")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appBlue)
                        .padding(.top)
                    
                    // Flash messages
                    flashMessagesSection
                    
                    // Edit coupon form
                    VStack(spacing: 16) {
                        companySection
                        basicInfoSection
                        valueSection
                        datesSection
                        urlsSection
                        cardInfoSection
                        optionsSection
                        submitSection
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding()
            }
            .navigationTitle("עריכת קופון")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ביטול") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .disabled(isLoading)
            .rtlAlert(
                "שגיאה",
                isPresented: Binding<Bool>(
                    get: { !errorMessage.isEmpty },
                    set: { newValue in if !newValue { errorMessage = "" } }
                ),
                message: errorMessage,
                buttons: [RTLAlertButton("OK", role: .cancel, action: nil)]
            )
            .rtlAlert(
                "הצלחה",
                isPresented: Binding<Bool>(
                    get: { !successMessage.isEmpty },
                    set: { newValue in if !newValue { successMessage = "" } }
                ),
                message: successMessage,
                buttons: [RTLAlertButton("OK", role: .cancel) {
                    presentationMode.wrappedValue.dismiss()
                }]
            )
            .onAppear {
                loadCompaniesFromAPI()
            }
            .sheet(isPresented: $showingCompanyPicker) {
                CompanyPickerView(selectedCompany: $selectedCompany)
            }
        }
    }
    
    // MARK: - Flash Messages Section
    private var flashMessagesSection: some View {
        VStack(spacing: 8) {
            if !errorMessage.isEmpty {
                HStack {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                    Spacer()
                    Button("×") {
                        errorMessage = ""
                    }
                    .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: 1)
                )
            }
            
            if !successMessage.isEmpty {
                HStack {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.caption)
                    Spacer()
                    Button("×") {
                        successMessage = ""
                    }
                    .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Company Section
    private var companySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("שם החברה")
                    .fontWeight(.medium)
                Text("*")
                    .foregroundColor(.red)
            }
            
            Button(selectedCompany.isEmpty ? "בחר חברה" : selectedCompany) {
                showingCompanyPicker = true
            }
            .foregroundColor(selectedCompany.isEmpty ? .gray : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if selectedCompany == "אחר" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("שם חברה חדשה")
                        .fontWeight(.medium)
                    TextField("הזן שם החברה", text: $customCompany)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            // Company-specific URL fields
            if selectedCompany == "BuyMe" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("כתובת URL של הקופון ל-BuyMe")
                        .fontWeight(.medium)
                    TextField("הדבק כאן את הקישור לקופון", text: $buyMeUrl)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
        }
    }
    
    // MARK: - Basic Info Section  
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Code field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("קוד הקופון")
                        .fontWeight(.medium)
                    Text("*")
                        .foregroundColor(.red)
                }
                TextField("הזן קוד הקופון", text: $code)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Description field
            VStack(alignment: .leading, spacing: 8) {
                Text("תיאור")
                    .fontWeight(.medium)
                TextField("תיאור הקופון (אופציונלי)", text: $description, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3, reservesSpace: true)
            }
            
            // Source field
            VStack(alignment: .leading, spacing: 8) {
                Text("מקור הקופון")
                    .fontWeight(.medium)
                TextField("מאיפה השגת את הקופון", text: $source)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    // MARK: - Value Section
    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cost field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("מחיר הקופון")
                        .fontWeight(.medium)
                    Text("*")
                        .foregroundColor(.red)
                }
                HStack {
                    TextField("0", text: $cost)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: cost) {
                            updateCalculations(changedField: "cost")
                        }
                    Text("₪")
                        .foregroundColor(.secondary)
                }
            }
            
            // Discount percentage field
            VStack(alignment: .leading, spacing: 8) {
                Text("אחוז הנחה")
                    .fontWeight(.medium)
                HStack {
                    TextField("0", text: $discountPercentage)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: discountPercentage) {
                            updateCalculations(changedField: "discount")
                        }
                    Text("%")
                        .foregroundColor(.secondary)
                }
                
                // Visual discount display
                discountDisplayView
            }
            
            // Value field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ערך הקופון")
                        .fontWeight(.medium)
                    Text("*")
                        .foregroundColor(.red)
                }
                HStack {
                    TextField("0", text: $value)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: value) {
                            updateCalculations(changedField: "value")
                        }
                    Text("₪")
                        .foregroundColor(.secondary)
                }
            }
            
            // Validation message
            if !validationMessage.isEmpty {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Discount Display View
    private var discountDisplayView: some View {
        let discountValue = Double(discountPercentage) ?? 0
        
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 30)
                        .cornerRadius(15)
                    
                    // Progress bar
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white, Color.appBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(discountValue / 100, 1.0), height: 30)
                        .cornerRadius(15)
                        .animation(.easeInOut(duration: 0.3), value: discountValue)
                    
                    // Percentage text
                    HStack {
                        Spacer()
                        Text("\(String(format: "%.2f", discountValue))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.trailing, 10)
                    }
                }
            }
            .frame(height: 30)
        }
    }
    
    // MARK: - Dates Section
    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("יש תאריך תפוגה", isOn: $hasExpiration)
                .toggleStyle(SwitchToggleStyle(tint: Color.appBlue))
            
            if hasExpiration {
                VStack(alignment: .leading, spacing: 8) {
                    Text("תאריך תפוגה")
                        .fontWeight(.medium)
                    DatePicker("", selection: $expiration, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                }
            }
        }
    }
    
    // MARK: - URLs Section
    private var urlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // BuyMe URL section
            VStack(alignment: .leading, spacing: 12) {
                Text("קישור BuyMe (אופציונלי)")
                    .fontWeight(.medium)
                TextField("הדבק כאן את הקישור לקופון BuyMe", text: $buyMeUrl)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            
            // Strauss URL section
            VStack(alignment: .leading, spacing: 12) {
                Toggle("קישור Strauss", isOn: $hasStraussUrl)
                    .toggleStyle(SwitchToggleStyle(tint: Color.appBlue))
                
                if hasStraussUrl {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("קישור שטראוס (אופציונלי)")
                            .fontWeight(.medium)
                        TextField("הדבק כאן את הקישור לקופון שטראוס", text: $straussUrl)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                }
            }
            
            // XGiftCard URL section
            VStack(alignment: .leading, spacing: 12) {
                Toggle("קישור XGiftCard", isOn: $hasXGiftCardUrl)
                    .toggleStyle(SwitchToggleStyle(tint: Color.appBlue))
                
                if hasXGiftCardUrl {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("קישור XGiftCard (אופציונלי)")
                            .fontWeight(.medium)
                        TextField("הדבק כאן את הקישור לקופון XGiftCard", text: $xgiftcardUrl)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                }
            }
            
            // Xtra URL section
            VStack(alignment: .leading, spacing: 12) {
                Toggle("קישור Xtra", isOn: $hasXtraUrl)
                    .toggleStyle(SwitchToggleStyle(tint: Color.appBlue))
                
                if hasXtraUrl {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("קישור Xtra (אופציונלי)")
                            .fontWeight(.medium)
                        TextField("הדבק כאן את הקישור לקופון Xtra", text: $xtraUrl)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                }
            }
        }
    }
    
    // MARK: - Card Info Section
    private var cardInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("האם להכניס תוקף כרטיס ו-CVV?", isOn: $includeCardInfo)
                .toggleStyle(SwitchToggleStyle(tint: Color.appBlue))
            
            if includeCardInfo {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CVV")
                            .fontWeight(.medium)
                        TextField("הזן CVV", text: $cvv)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("תוקף כרטיס")
                            .fontWeight(.medium)
                        TextField("MM/YY", text: $cardExpiry)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: cardExpiry) { _, newValue in
                                formatCardExpiry(newValue)
                            }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Options Section
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("שימוש חד-פעמי", isOn: $isOneTime)
                    .toggleStyle(SwitchToggleStyle(tint: Color.appBlue))
                
                Text("קופון חד-פעמי - מאפשר שימוש אחד בלבד, בניגוד לקופונים רב-פעמיים בהם היתרה נשמרת לשימושים הבאים.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            
            if isOneTime {
                VStack(alignment: .leading, spacing: 8) {
                    Text("מטרה")
                        .fontWeight(.medium)
                    TextField("למה קנית את הקופון?", text: $purpose)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
    }
    
    // MARK: - Submit Section
    private var submitSection: some View {
        VStack(spacing: 12) {
            if !validationMessage.isEmpty {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Button(action: {
                updateCoupon()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isLoading ? "מעדכן..." : "עדכן קופון")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.appBlue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(isLoading || !isFormValid)
        }
    }
    
    // MARK: - Helper Functions
    private func loadCompaniesFromAPI() {
        isLoadingCompanies = true
        couponAPI.fetchCompanies { result in
            DispatchQueue.main.async {
                self.isLoadingCompanies = false
                switch result {
                case .success(let fetchedCompanies):
                    self.availableCompanies = fetchedCompanies
                case .failure:
                    // Keep empty array, user can still type company name
                    break
                }
            }
        }
    }
    
    private func formatCardExpiry(_ value: String) {
        let digits = value.filter { $0.isNumber }
        var formatted = ""
        
        for (index, digit) in digits.enumerated() {
            if index == 2 {
                formatted += "/"
            }
            if index < 4 {
                formatted += String(digit)
            }
        }
        
        cardExpiry = formatted
    }
    
    private func updateCoupon() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        // Encrypt sensitive data
        let encryptedCode = EncryptionManager.encryptString(code)
        let encryptedDescription = description.isEmpty ? nil : EncryptionManager.encryptString(description)
        let encryptedCvv = cvv.isEmpty ? nil : EncryptionManager.encryptString(cvv)
        
        // Encrypt URL fields
        let encryptedBuyMeUrl = buyMeUrl.isEmpty ? nil : EncryptionManager.encryptString(buyMeUrl)
        let encryptedStraussUrl = (hasStraussUrl && !straussUrl.isEmpty) ? EncryptionManager.encryptString(straussUrl) : nil
        let encryptedXGiftCardUrl = (hasXGiftCardUrl && !xgiftcardUrl.isEmpty) ? EncryptionManager.encryptString(xgiftcardUrl) : nil
        let encryptedXtraUrl = (hasXtraUrl && !xtraUrl.isEmpty) ? EncryptionManager.encryptString(xtraUrl) : nil
        
        let updateData: [String: Any] = [
            "code": encryptedCode,
            "description": encryptedDescription ?? NSNull(),
            "value": Double(value) ?? 0,
            "cost": Double(cost) ?? 0,
            "company": finalCompanyName,
            "expiration": hasExpiration ? ISO8601DateFormatter().string(from: expiration).prefix(10).description : NSNull(),
            "source": source.isEmpty ? NSNull() : source,
            "buyme_coupon_url": encryptedBuyMeUrl ?? NSNull(),
            "strauss_coupon_url": encryptedStraussUrl ?? NSNull(),
            "xgiftcard_coupon_url": encryptedXGiftCardUrl ?? NSNull(),
            "xtra_coupon_url": encryptedXtraUrl ?? NSNull(),
            "is_one_time": isOneTime,
            "purpose": (isOneTime && !purpose.isEmpty) ? purpose : NSNull(),
            "cvv": encryptedCvv ?? NSNull(),
            "card_exp": (includeCardInfo && !cardExpiry.isEmpty) ? cardExpiry : NSNull()
        ]
        
        updateCouponAPI(updateData: updateData)
    }
    
    private func updateCouponAPI(updateData: [String: Any]) {
        let baseURL = SupabaseConfig.url
        let apiKey = SupabaseConfig.anonKey
        let urlString = "\(baseURL)/rest/v1/coupon?id=eq.\(coupon.id)"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "שגיאה בכתובת השרת"
            isLoading = false
            return
        }
        
        guard let requestData = try? JSONSerialization.data(withJSONObject: updateData) else {
            errorMessage = "שגיאה בהכנת הבקשה"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.httpBody = requestData
        
        print("📝 Updating coupon \(coupon.id) with data: \(updateData)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "שגיאה בעדכון הקופון: \(error.localizedDescription)"
                    return
                }
                
                // Debug: Print response
                if let data = data, let jsonString = String(data: data, encoding: .utf8) {
                    print("📝 Update response: \(jsonString)")
                }
                
                // If value changed, mirror web behavior: upsert initial recharge record
                let originalValue = self.coupon.value
                let newValue = Double(self.value) ?? originalValue
                if abs(newValue - originalValue) > 0.0001 {
                    print("🔁 Coupon value changed from \(originalValue) to \(newValue). Updating initial recharge transaction...")
                    self.couponAPI.upsertInitialRechargeTransaction(couponId: self.coupon.id, value: newValue) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                print("✅ Initial recharge transaction upserted for coupon \(self.coupon.id)")
                            case .failure(let err):
                                print("❌ Failed to upsert initial recharge transaction: \(err)")
                            }
                            self.successMessage = "הקופון עודכן בהצלחה!"
                            self.onUpdate()
                        }
                    }
                } else {
                    self.successMessage = "הקופון עודכן בהצלחה!"
                    self.onUpdate()
                }
            }
        }.resume()
    }
    
    // MARK: - Calculation Functions
    private func updateCalculations(changedField: String) {
        let costValue = Double(cost) ?? 0
        let valueAmount = Double(value) ?? 0
        let discountValue = Double(discountPercentage) ?? 0
        
        switch changedField {
        case "cost", "value":
            // Always calculate discount when cost or value changes (if both have values)
            if valueAmount > 0 {
                if costValue == 0 {
                    discountPercentage = "100.00"
                } else if costValue <= valueAmount {
                    let calculatedDiscount = ((valueAmount - costValue) / valueAmount) * 100
                    discountPercentage = String(format: "%.2f", max(0, min(100, calculatedDiscount)))
                } else {
                    // Cost is higher than value - set discount to 0
                    discountPercentage = "0.00"
                }
            }
            
        case "discount":
            // Calculate cost from value and discount
            if valueAmount > 0 && discountValue >= 0 && discountValue <= 100 {
                if discountValue == 100 {
                    cost = "0.00"
                } else {
                    let calculatedCost = valueAmount * (1 - discountValue / 100)
                    cost = String(format: "%.2f", max(0, calculatedCost))
                }
            }
            
        default:
            break
        }
    }
}

#Preview {
    EditCouponView(
        coupon: Coupon(
            id: 1,
            code: "SAVE20",
            description: "הנחה על קניות בסופר",
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
        ),
        onUpdate: {}
    )
}
