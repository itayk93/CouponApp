//
//  AddCouponView.swift
//  CouponManagerApp
//
//  מסך הוספת קופון חדש
//

import SwiftUI

struct AddCouponView: View {
    let user: User
    let companies: [Company]
    let preSelectedCompany: Company?
    let onCouponAdded: () -> Void
    let prefilledData: CouponExtractionResult?
    
    @StateObject private var couponAPI = CouponAPIClient()
    @State private var availableCompanies: [Company] = []
    @State private var isLoadingCompanies = false
    @State private var code = ""
    @State private var description = ""
    @State private var value = ""
    @State private var cost = ""
    @State private var discountPercentage = ""
    @State private var selectedCompany = ""
    @State private var customCompany = ""
    @State private var expiration = Date()
    @State private var hasExpiration = false
    @State private var source = ""
    @State private var buyMeUrl = ""
    @State private var straussUrl = ""
    @State private var hasStraussUrl = false
    @State private var hasXtraUrl = false
    @State private var xtraUrl = ""
    @State private var isOneTime = false
    @State private var purpose = ""
    @State private var includeCardInfo = false
    @State private var cvv = ""
    @State private var cardExpiry = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showingCompanyPicker = false
    @State private var showingAddFromText = false
    @State private var showingAddFromImage = false
    @State private var showingInstructions = false
    @State private var hasExpandedInstructions = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var powerGiftUrl = ""
    @State private var pendingCalculationWorkItem: DispatchWorkItem?
    @FocusState private var focusedPricingField: PricingField?
    
    // MARK: - Dark Mode Support
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white
    }
    
    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemGray6)
    }
    @State private var showingExpirationAlert = false
    @State private var autoDownloadDetails = ""
    
    @Environment(\.presentationMode) var presentationMode
    
    init(user: User, companies: [Company], preSelectedCompany: Company? = nil, onCouponAdded: @escaping () -> Void, prefilledData: CouponExtractionResult? = nil) {
        self.user = user
        self.companies = companies
        self.preSelectedCompany = preSelectedCompany
        self.onCouponAdded = onCouponAdded
        self.prefilledData = prefilledData
    }
    
    private var companyNames: [String] {
        companies.map { $0.name }.sorted()
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
                    Text("הוספת קופון חדש")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appBlue)
                        .padding(.top)
                    
                    // Action buttons row
                    actionButtonsSection
                    
                    // Help button
                    helpButtonSection
                    
                    // Instructions panel
                    if showingInstructions {
                        instructionsSection
                    }
                    
                    // Flash messages
                    flashMessagesSection
                    
                    // Manual coupon form
                    VStack(spacing: 16) {
                        companySection
                        basicInfoSection
                        valueSection
                        datesSection
                        urlsSection
                        cardInfoSection
                        optionsSection
                        adminSection
                        submitSection
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding()
            }
            .navigationTitle("הוספת קופון")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ביטול") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("ביטול") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                #endif
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
                buttons: [RTLAlertButton("OK", role: .cancel, action: nil)]
            )
            .rtlAlert(
                "תאריך תפוגה",
                isPresented: $showingExpirationAlert,
                message: "תאריך התפוגה הוא היום או לפני היום. האם ברצונך להמשיך?",
                buttons: [
                    RTLAlertButton("ביטול", role: .cancel, action: nil),
                    RTLAlertButton("המשך") { performAddCoupon() }
                ]
            )
            .onAppear {
                // Always try to use passed companies first, then load from API
                if !companies.isEmpty {
                    availableCompanies = companies
                } else {
                    // Load companies from API
                    loadCompaniesFromAPI()
                }
                
                if let preSelected = preSelectedCompany {
                    selectedCompany = preSelected.name
                }
                
                // Handle prefilled data from text analysis
                if let data = prefilledData {
                    populateFormFromExtractedData(data)
                }
            }
            .sheet(isPresented: $showingAddFromText) {
                AddCouponFromTextView(
                    user: user,
                    companies: companies,
                    onCouponAdded: onCouponAdded,
                    onSwitchToImageAnalysis: {
                        showingAddFromText = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showingAddFromImage = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showingAddFromImage) {
                AddCouponFromImageView(user: user, companies: companies, onCouponAdded: onCouponAdded)
            }
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                // Multiple coupons button
                Button(action: { 
                    // TODO: Navigate to bulk add
                }) {
                    HStack {
                        Text("הוספת קופונים מרובים")
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Image(systemName: "plus.circle")
                    }
                    .foregroundColor(Color.appBlue)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding(.horizontal, 8)
                    .background(cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.appBlue, lineWidth: 1)
                    )
                }
                
                // Upload file button
                Button(action: { 
                    // TODO: Navigate to file upload
                }) {
                    HStack {
                        Text("העלאת קובץ קופונים")
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Image(systemName: "doc.badge.plus")
                    }
                    .foregroundColor(Color.appBlue)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding(.horizontal, 8)
                    .background(cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.appBlue, lineWidth: 1)
                    )
                }
                
                // Add from image button
                Button(action: { showingAddFromImage = true }) {
                    HStack {
                        Text("הוספת קופון מתמונה")
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Image(systemName: "camera")
                    }
                    .foregroundColor(Color.appBlue)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding(.horizontal, 8)
                    .background(cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.appBlue, lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Help Button Section
    private var helpButtonSection: some View {
        Button(action: {
            withAnimation {
                showingInstructions.toggle()
            }
        }) {
            HStack {
                Image(systemName: "questionmark.circle")
                Text("הסבר")
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.appBlue)
            .cornerRadius(25)
            .shadow(color: .gray.opacity(0.3), radius: 2, x: 0, y: 2)
        }
    }
    
    // MARK: - Instructions Section
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - always visible with tap gesture
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingInstructions.toggle()
                }
                if !hasExpandedInstructions {
                    hasExpandedInstructions = true
                }
            }) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(Color.appBlue)
                        .font(.title2)
                    
                    Text("איך להוסיף קופון?")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appBlue)
                    
                    Spacer()
                    
                    // First time hint
                    if !hasExpandedInstructions {
                        Text("לחץ להסבר")
                            .font(.caption2)
                            .foregroundColor(Color.appBlue.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.appBlue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Animated chevron indicator
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color.appBlue)
                        .font(.caption)
                        .rotationEffect(.degrees(showingInstructions ? 180 : 0))
                        .animation(.easeInOut(duration: 0.3), value: showingInstructions)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(hasExpandedInstructions ? 1.0 : 1.02)
            .animation(
                hasExpandedInstructions ? .none : 
                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: hasExpandedInstructions
            )
            
            // Collapsible content
            if showingInstructions {
                VStack(alignment: .trailing, spacing: 10) {
                    instructionStep(number: 1, text: "מלא את פרטי הקופון בטופס למטה.")
                    instructionStep(number: 2, text: "חובה למלא את שם החברה, קוד הקופון, כמה הקופון שווה בפועל וכמה שילמת על הקופון.")
                    instructionStep(number: 3, text: "אם יש לך תאריך תפוגה, הזן אותו בשדה המתאים.")
                    instructionStep(number: 4, text: "אם יש לך פרטי כרטיס (תוקף כרטיס ו-CVV), סמן את התיבה המתאימה והזן את הפרטים.")
                    instructionStep(number: 5, text: "לחץ על \"הוספת הקופון לארנק\" כשסיימת.")
                    
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("שים לב: שדות עם כוכבית (*) הם שדות חובה.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.medium)
                .foregroundColor(Color.appBlue)
                .environment(\.layoutDirection, .leftToRight) // Force LTR for numbering
                .multilineTextAlignment(.leading)
            Text(text)
                .font(.caption)
                .lineLimit(nil)
                .multilineTextAlignment(.trailing) // RTL for Hebrew text
            Spacer()
        }
        .environment(\.layoutDirection, .rightToLeft) // Overall RTL layout
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
            
            if selectedCompany == "Power Gift" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("כתובת URL של הקופון מPower Gift")
                        .fontWeight(.medium)
                    TextField("הדבק כאן את הקישור לקופון", text: $powerGiftUrl)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
        }
        .sheet(isPresented: $showingCompanyPicker) {
            CompanyPickerView(
                selectedCompany: $selectedCompany
            )
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
                        .focused($focusedPricingField, equals: .cost)
                        .onChange(of: cost) { _, _ in
                            if focusedPricingField == .cost {
                                scheduleCalculation(for: "cost")
                            }
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
                        .focused($focusedPricingField, equals: .discount)
                        .onChange(of: discountPercentage) { _, _ in
                            if focusedPricingField == .discount {
                                cancelScheduledCalculation()
                                updateCalculations(changedField: "discount")
                            }
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
                        .focused($focusedPricingField, equals: .value)
                        .onChange(of: value) { _, _ in
                            if focusedPricingField == .value {
                                scheduleCalculation(for: "value")
                            }
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
                        Text("\(PricingFormatter.string(from: discountValue))%")
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
                .onChange(of: hasExpiration) { _, isEnabled in
                    if isEnabled {
                        // Only set default date if expiration is not already set from automatic detection
                        // Check if expiration is today's date (which means it wasn't set by auto-detection)
                        let calendar = Calendar.current
                        let today = Date()
                        
                        // If expiration is today, it means it's the default value, so we can override it
                        if calendar.isDate(expiration, inSameDayAs: today) {
                            // Set default to December 31st of current year when manually toggled
                            let currentYear = calendar.component(.year, from: today)
                            var components = DateComponents()
                            components.year = currentYear
                            components.month = 12
                            components.day = 31
                            
                            if let defaultDate = calendar.date(from: components) {
                                expiration = defaultDate
                            }
                        }
                    }
                }
            
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
    
    // MARK: - URLs Section (only show if not company-specific)
    private var urlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if selectedCompany != "Power Gift" {
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
    
    // MARK: - Admin Section
    private var adminSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if user.isAdmin {
                Text("הורדה אוטומטית")
                    .fontWeight(.medium)
                
                Menu {
                    Button("ללא") {
                        autoDownloadDetails = ""
                    }
                    Button("BuyMe") {
                        autoDownloadDetails = "BuyMe"
                    }
                    Button("Max") {
                        autoDownloadDetails = "Max"
                    }
                    Button("Multipass") {
                        autoDownloadDetails = "Multipass"
                    }
                } label: {
                    HStack {
                        Text(autoDownloadDetails.isEmpty ? "בחר אופציה" : autoDownloadDetails)
                            .foregroundColor(autoDownloadDetails.isEmpty ? .gray : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
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
                addCoupon()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isLoading ? "מוסיף..." : "הוספת הקופון לארנק")
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
    private func addCoupon() {
        guard isFormValid else { return }
        
        // Check expiration date before submission
        if hasExpiration {
            let today = Calendar.current.startOfDay(for: Date())
            let expirationDay = Calendar.current.startOfDay(for: expiration)
            
            if expirationDay <= today {
                showingExpirationAlert = true
                return
            }
        }
        
        performAddCoupon()
    }
    
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
    
    private func performAddCoupon() {
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        let couponRequest = CouponCreateRequest(
            code: code,
            description: description.isEmpty ? nil : description,
            value: Double(value) ?? 0,
            cost: Double(cost) ?? 0,
            company: finalCompanyName,
            expiration: hasExpiration ? ISO8601DateFormatter().string(from: expiration).prefix(10).description : nil,
            source: source.isEmpty ? nil : source,
            buyMeCouponUrl: buyMeUrl.isEmpty ? nil : buyMeUrl,
            straussCouponUrl: straussUrl.isEmpty ? nil : straussUrl,
            xtraCouponUrl: powerGiftUrl.isEmpty ? xtraUrl.isEmpty ? nil : xtraUrl : powerGiftUrl,
            cvv: includeCardInfo && !cvv.isEmpty ? cvv : nil,
            cardExp: includeCardInfo && !cardExpiry.isEmpty ? cardExpiry : nil,
            isForSale: false, // Removed isForSale option
            isOneTime: isOneTime,
            purpose: purpose.isEmpty ? nil : purpose,
            autoDownloadDetails: autoDownloadDetails.isEmpty ? nil : autoDownloadDetails
        )
        
        couponAPI.createCoupon(couponRequest, userId: user.id) { result in
            isLoading = false
            
            switch result {
            case .success:
                successMessage = "קופון נוסף בהצלחה!"
                onCouponAdded() // Call immediately when coupon is successfully created
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    presentationMode.wrappedValue.dismiss()
                }
            case .failure(let error):
                errorMessage = "שגיאה בהוספת הקופון: \(error.localizedDescription)"
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
    
    private func populateFormFromExtractedData(_ data: CouponExtractionResult) {
        // Populate basic fields
        if let extractedCode = data.code {
            code = extractedCode
        }
        
        if let extractedDescription = data.description {
            description = extractedDescription
        }
        
        if let extractedValue = data.value {
            value = PricingFormatter.string(from: extractedValue)
        }
        
        // Handle extracted cost
        if let extractedCost = data.cost {
            cost = PricingFormatter.string(from: extractedCost)
        } else {
            cost = "0"
        }
        
        if let extractedSource = data.source {
            source = extractedSource
        }
        
        // Handle company selection
        if let extractedCompany = data.company {
            // Try to find matching company
            if let matchingCompany = companies.first(where: { company in
                // Exact case-insensitive match first
                company.name.lowercased() == extractedCompany.lowercased() ||
                // Then contains matching
                company.name.lowercased().contains(extractedCompany.lowercased()) ||
                extractedCompany.lowercased().contains(company.name.lowercased())
            }) {
                selectedCompany = matchingCompany.name
            } else {
                // Use "אחר" and set custom company name
                selectedCompany = "אחר"
                customCompany = extractedCompany
            }
        }
        
        // Handle expiration date
        if let extractedExpiration = data.expiration {
            print("📅 Extracted expiration: '\(extractedExpiration)'")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem") // Use Israeli timezone
            formatter.locale = Locale(identifier: "en_US_POSIX") // Avoid locale issues
            if let date = formatter.date(from: extractedExpiration) {
                print("📅 Parsed date successfully: \(date)")
                expiration = date
                hasExpiration = true
                print("📅 Set hasExpiration to true, expiration to: \(date)")
            } else {
                print("❌ Failed to parse date: '\(extractedExpiration)'")
            }
        }
        
        // Calculate discount percentage based on actual cost and value
        if let extractedValue = data.value, extractedValue > 0 {
            let extractedCost = data.cost ?? 0
            if extractedCost == 0 {
                discountPercentage = PricingFormatter.string(from: 100)
            } else {
                let calculatedDiscount = ((extractedValue - extractedCost) / extractedValue) * 100
                discountPercentage = PricingFormatter.string(from: max(0, calculatedDiscount))
            }
        }
        
        // Handle Strauss URL
        if let extractedStraussUrl = data.straussUrl, !extractedStraussUrl.isEmpty {
            straussUrl = extractedStraussUrl
            hasStraussUrl = true
            print("🔗 Auto-filled Strauss URL: \(extractedStraussUrl)")
        }
        
        // Handle BuyMe URL
        if let extractedBuyMeUrl = data.buyMeUrl, !extractedBuyMeUrl.isEmpty {
            buyMeUrl = extractedBuyMeUrl
            print("🔗 Auto-filled BuyMe URL: \(extractedBuyMeUrl)")
        }
        
        // Handle auto download details for admin users
        if user.isAdmin, let extractedAutoDownloadDetails = data.autoDownloadDetails, !extractedAutoDownloadDetails.isEmpty {
            autoDownloadDetails = extractedAutoDownloadDetails
            print("🔧 Auto-filled auto download details for admin: \(extractedAutoDownloadDetails)")
        }
        
        // Auto-hide instructions when form is prefilled
        showingInstructions = false
    }
    
    // MARK: - Calculation Functions
    private func scheduleCalculation(for changedField: String) {
        pendingCalculationWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            updateCalculations(changedField: changedField)
        }

        pendingCalculationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func cancelScheduledCalculation() {
        pendingCalculationWorkItem?.cancel()
        pendingCalculationWorkItem = nil
    }

    private func updateCalculations(changedField: String) {
        let costValue = Double(cost) ?? 0
        let valueAmount = Double(value) ?? 0
        let discountValue = Double(discountPercentage) ?? 0
        
        switch changedField {
        case "cost", "value":
            // Always calculate discount when cost or value changes (if both have values)
            if valueAmount > 0 {
                if costValue == 0 {
                    discountPercentage = PricingFormatter.string(from: 100)
                } else if costValue <= valueAmount {
                    let calculatedDiscount = ((valueAmount - costValue) / valueAmount) * 100
                    discountPercentage = PricingFormatter.string(from: max(0, min(100, calculatedDiscount)))
                } else {
                    // Cost is higher than value - set discount to 0
                    discountPercentage = PricingFormatter.string(from: 0)
                }
            }
            
        case "discount":
            // Calculate cost from value and discount
            if valueAmount > 0 && discountValue >= 0 && discountValue <= 100 {
                if discountValue == 100 {
                    cost = PricingFormatter.string(from: 0)
                } else {
                    let calculatedCost = valueAmount * (1 - discountValue / 100)
                    cost = PricingFormatter.string(from: max(0, calculatedCost))
                }
            }
            
            default:
                break
        }
    }

    private enum PricingField: Hashable {
        case cost, value, discount
    }
}

// MARK: - Company Picker View
struct CompanyPickerView: View {
    @State private var companies: [Company] = []
    @State private var isLoading = true
    @Binding var selectedCompany: String
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var couponAPI = CouponAPIClient()
    
    var sortedCompanies: [Company] {
        companies.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("טוען חברות...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if companies.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "building.2")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("לא נמצאו חברות")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("נטען מידע...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                            ForEach(sortedCompanies, id: \.id) { company in
                                Button(action: {
                                    selectedCompany = company.name
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    VStack(spacing: 8) {
                                        // Company Logo
                                        AsyncImage(url: companyImageURL(for: company)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        } placeholder: {
                                            Image(systemName: "building.2")
                                                .font(.system(size: 24))
                                                .foregroundColor(.gray)
                                        }
                                        .frame(width: 60, height: 60)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                        
                                        // Company Name
                                        Text(company.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                    }
                                    .frame(width: 80, height: 100)
                                    .padding(8)
                                    .background(selectedCompany == company.name ? Color.appBlue.opacity(0.1) : Color.clear)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedCompany == company.name ? Color.appBlue : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                            
                            // "Other" option at the end of the grid
                            Button(action: {
                                selectedCompany = "אחר"
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                VStack(spacing: 8) {
                                    // Other icon
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 30))
                                        .foregroundColor(Color.appBlue)
                                        .frame(width: 60, height: 60)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    
                                    // Text
                                    Text("אחר")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(width: 80, height: 100)
                                .padding(8)
                                .background(selectedCompany == "אחר" ? Color.appBlue.opacity(0.1) : Color.clear)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedCompany == "אחר" ? Color.appBlue : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            #if targetEnvironment(simulator)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .navigationTitle("בחר חברה")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("ביטול") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("ביטול") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                #endif
            }
            .environment(\.layoutDirection, .rightToLeft)
            .onAppear {
                loadCompanies()
            }
        }
    
    private func companyImageURL(for company: Company) -> URL? {
        let baseURL = "https://www.couponmasteril.com/static/"
        return URL(string: baseURL + company.imagePath)
    }
    
    private func loadCompanies() {
        isLoading = true
        couponAPI.fetchCompanies { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let fetchedCompanies):
                    self.companies = fetchedCompanies
                case .failure:
                    // Keep empty array
                    break
                }
            }
        }
    }
}

#Preview {
    AddCouponView(
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
            Company(id: 1, name: "Carrefour", imagePath: "carrefour.png", companyCount: 10),
            Company(id: 2, name: "BuyMe", imagePath: "buyme.png", companyCount: 15)
        ],
        preSelectedCompany: nil,
        onCouponAdded: {}
    )
}
