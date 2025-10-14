//
//  AddCouponFromTextView.swift
//  CouponManagerApp
//
//  מסך הוספת קופון מטקסט/SMS עם ניתוח GPT
//

import SwiftUI

struct AddCouponFromTextView: View {
    let user: User
    let companies: [Company]
    let onCouponAdded: () -> Void
    let onSwitchToImageAnalysis: (() -> Void)?
    
    init(user: User, companies: [Company], onCouponAdded: @escaping () -> Void, onSwitchToImageAnalysis: (() -> Void)? = nil) {
        self.user = user
        self.companies = companies
        self.onCouponAdded = onCouponAdded
        self.onSwitchToImageAnalysis = onSwitchToImageAnalysis
    }
    
    @State private var inputText = ""
    @State private var isAnalyzing = false
    @State private var analysisResult: CouponExtractionResult?
    @State private var showingManualEntry = false
    @State private var showingAddCouponView = false
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    
    // Manual entry fields
    @State private var manualCode = ""
    @State private var manualDescription = ""
    @State private var manualValue = ""
    @State private var manualCompany = ""
    @State private var manualExpiration = Date()
    @State private var manualCost = ""
    @State private var manualFullName = ""
    @State private var manualPhone = ""
    @State private var manualEmail = ""
    @State private var manualCategory = ""
    @State private var manualNotes = ""
    
    private let openAIClient = OpenAIClient(apiKey: Config.openAIAPIKey)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    if !showingManualEntry {
                        // Text Input Section
                        textInputSection
                        
                        // Action Buttons
                        actionButtonsSection
                    } else {
                        // Manual Entry Form
                        manualEntrySection
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("הוספת קופון מטקסט")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ביטול") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if showingManualEntry {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("שמור") {
                            saveManualCoupon()
                        }
                        .disabled(!isManualFormValid)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCouponView) {
            AddCouponView(
                user: user,
                companies: companies,
                onCouponAdded: {
                    onCouponAdded()
                    presentationMode.wrappedValue.dismiss()
                },
                prefilledData: analysisResult
            )
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(Color.appBlue)
                
                Text("העתק את טקסט הקופון או ה-SMS")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("המערכת תנתח את הטקסט ותמלא את הפרטים אוטומטית")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Action buttons row
            HStack(spacing: 12) {
                Button(action: { 
                    if let switchToImage = onSwitchToImageAnalysis {
                        presentationMode.wrappedValue.dismiss()
                        switchToImage()
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title2)
                        Text("מתמונה")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
                }
                
                Button(action: { 
                    showingAddCouponView = true
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.title2)
                        Text("טופס ידני")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Text Input Section
    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("טקסט הקופון")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextEditor(text: $inputText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            if inputText.isEmpty {
                Text("לדוגמה: 'קוד הקופון שלך: SAVE20 בשווי 100₪ תקף עד 31/12/2024'")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Analysis Result Section
    private func analysisResultSection(_ result: CouponExtractionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("תוצאות הניתוח")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("ערוך ידנית") {
                    populateManualFields(from: result)
                    showingManualEntry = true
                }
                .font(.caption)
                .foregroundColor(Color.appBlue)
            }
            
            VStack(spacing: 12) {
                if let code = result.code {
                    resultRow(title: "קוד:", value: code)
                }
                
                if let description = result.description {
                    resultRow(title: "תיאור:", value: description)
                }
                
                if let value = result.value {
                    resultRow(title: "ערך:", value: "₪\(Int(value))")
                }
                
                if let company = result.company {
                    resultRow(title: "חברה:", value: company)
                }
                
                if let expiration = result.expiration {
                    resultRow(title: "תפוגה:", value: formatDate(expiration))
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func resultRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: analyzeText) {
                HStack {
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isAnalyzing ? "מנתח..." : "נתח עם GPT")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(inputText.isEmpty ? Color.gray : Color.appBlue)
                .cornerRadius(12)
            }
            .disabled(inputText.isEmpty || isAnalyzing)
            
            Button("הוספה ידנית") {
                showingAddCouponView = true
            }
            .foregroundColor(Color.appBlue)
        }
    }
    
    // MARK: - Manual Entry Section
    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button("← חזור לטקסט") {
                    showingManualEntry = false
                }
                .foregroundColor(Color.appBlue)
                
                Spacer()
                
                Text("הוספה ידנית")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            // Navigation buttons in manual entry
            HStack(spacing: 12) {
                Button(action: { 
                    showingManualEntry = false
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title3)
                        Text("מטקסט")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.appBlue)
                    .cornerRadius(8)
                }
                
                Button(action: { 
                    if let switchToImage = onSwitchToImageAnalysis {
                        presentationMode.wrappedValue.dismiss()
                        switchToImage()
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title3)
                        Text("מתמונה")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
            
            VStack(spacing: 16) {
                formField(title: "שם מלא", text: $manualFullName, placeholder: "שם מלא של בעל הקופון")
                formField(title: "קוד קופון", text: $manualCode, placeholder: "לדוגמה: SAVE20")
                formField(title: "תיאור", text: $manualDescription, placeholder: "תיאור הקופון")
                formField(title: "ערך (₪)", text: $manualValue, placeholder: "100", keyboardType: .decimalPad)
                formField(title: "חברה", text: $manualCompany, placeholder: "שם החברה")
                formField(title: "קטגוריה", text: $manualCategory, placeholder: "קטגורית הקופון")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("תאריך תפוגה")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    DatePicker("", selection: $manualExpiration, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .environment(\.locale, Locale(identifier: "he"))
                }
                
                formField(title: "עלות (₪) - אופציונלי", text: $manualCost, placeholder: "80", keyboardType: .decimalPad)
                formField(title: "טלפון - אופציונלי", text: $manualPhone, placeholder: "מספר טלפון", keyboardType: .phonePad)
                formField(title: "אימייל - אופציונלי", text: $manualEmail, placeholder: "כתובת אימייל", keyboardType: .emailAddress)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("הערות - אופציונלי")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    TextEditor(text: $manualNotes)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            HStack(spacing: 12) {
                Button("ביטול") {
                    showingManualEntry = false
                    clearManualFields()
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                
                Button("שמור") {
                    saveManualCoupon()
                }
                .disabled(!isManualFormValid)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isManualFormValid ? Color.green : Color.gray)
                .cornerRadius(12)
            }
        }
    }
    
    private func formField(title: String, text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
            
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    // MARK: - Helper Properties
    private var isManualFormValid: Bool {
        !manualFullName.isEmpty && !manualCode.isEmpty && !manualDescription.isEmpty && !manualValue.isEmpty && !manualCompany.isEmpty
    }
    
    // MARK: - Helper Functions
    private func analyzeText() {
        guard !inputText.isEmpty else { return }
        
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                print("📋 AddCouponFromTextView: About to call GPT with \(companies.count) companies")
                print("📋 Companies list: \(companies.map { $0.name })")
                let result = try await openAIClient.extractCouponFromTextWithTracking(inputText, companies: companies)
                
                await MainActor.run {
                    self.analysisResult = result
                    self.isAnalyzing = false
                    
                    // Show AddCouponView with prefilled data
                    self.showingAddCouponView = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "שגיאה בניתוח הטקסט: \(error.localizedDescription)"
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func saveCouponFromAnalysis() {
        guard let result = analysisResult else { return }
        
        // Create coupon from analysis result
        let coupon = createCouponFromResult(result)
        saveCoupon(coupon)
    }
    
    private func saveManualCoupon() {
        let coupon = Coupon(
            id: 0,
            code: manualCode,
            description: manualDescription,
            value: Double(manualValue) ?? 0,
            cost: Double(manualCost) ?? 0,
            company: manualCompany,
            expiration: formatDateForAPI(manualExpiration),
            source: "manual_text",
            buyMeCouponUrl: nil,
            straussCouponUrl: nil,
            xgiftcardCouponUrl: nil,
            xtraCouponUrl: nil,
            dateAdded: ISO8601DateFormatter().string(from: Date()),
            usedValue: 0,
            status: "פעיל",
            isAvailable: true,
            isForSale: false,
            isOneTime: false,
            purpose: nil,
            excludeSaving: false,
            autoDownloadDetails: nil,
            userId: user.id,
            cvv: nil,
            cardExp: nil
        )
        
        saveCoupon(coupon)
    }
    
    private func saveCoupon(_ coupon: Coupon) {
        // TODO: Implement actual API call to save coupon
        print("Saving coupon: \(coupon)")
        onCouponAdded()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func createCouponFromResult(_ result: CouponExtractionResult) -> Coupon {
        return Coupon(
            id: 0,
            code: result.code ?? "",
            description: result.description ?? "",
            value: result.value ?? 0,
            cost: 0,
            company: result.company ?? "",
            expiration: result.expiration ?? "",
            source: result.source ?? "gpt_text",
            buyMeCouponUrl: result.buyMeUrl,
            straussCouponUrl: result.straussUrl,
            xgiftcardCouponUrl: nil,
            xtraCouponUrl: nil,
            dateAdded: ISO8601DateFormatter().string(from: Date()),
            usedValue: 0,
            status: "פעיל",
            isAvailable: true,
            isForSale: false,
            isOneTime: false,
            purpose: nil,
            excludeSaving: false,
            autoDownloadDetails: result.autoDownloadDetails,
            userId: user.id,
            cvv: nil,
            cardExp: nil
        )
    }
    
    private func populateManualFields(from result: CouponExtractionResult) {
        manualCode = result.code ?? ""
        manualDescription = result.description ?? ""
        manualValue = result.value != nil ? String(Int(result.value!)) : ""
        manualCompany = result.company ?? ""
        
        if let expiration = result.expiration {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            manualExpiration = formatter.date(from: expiration) ?? Date()
        }
    }
    
    private func clearManualFields() {
        manualFullName = ""
        manualCode = ""
        manualDescription = ""
        manualValue = ""
        manualCompany = ""
        manualCategory = ""
        manualExpiration = Date()
        manualCost = ""
        manualPhone = ""
        manualEmail = ""
        manualNotes = ""
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: date)
        }
        
        return dateString
    }
    
    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

#Preview {
    AddCouponFromTextView(
        user: User(
            id: 1,
            email: "test@example.com",
            password: nil,
            firstName: "Test",
            lastName: "User",
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
        companies: [
            Company(id: 1, name: "Carrefour", imagePath: "carrefour.png", companyCount: 10),
            Company(id: 2, name: "BuyMe", imagePath: "buyme.png", companyCount: 15)
        ],
        onCouponAdded: {
            print("Coupon added")
        },
        onSwitchToImageAnalysis: {
            print("Switch to image analysis")
        }
    )
}