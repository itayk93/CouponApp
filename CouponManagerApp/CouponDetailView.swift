//
//  CouponDetailView.swift
//  CouponManagerApp
//
//  מסך פרטי קופון מפורט - דומה לאתר המקורי
//

import SwiftUI
import UIKit
import WidgetKit
#if canImport(Charts)
import Charts
#endif

struct CouponDetailView: View {
    @State var coupon: Coupon
    let user: User
    let companies: [Company]
    let onUpdate: () -> Void

    @StateObject private var couponAPI = CouponAPIClient()
    @State private var selectedTab = 0
    @State private var usageHistory: [CouponUsage] = []
    @State private var consolidatedRows: [TransactionRow] = []
    @State private var isLoading = false
    @State private var showingUsageSheet = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingMarkUsedAlert = false
    @State private var showingShareSheet = false
    @State private var showCVV = false
    @Environment(\.presentationMode) var presentationMode
    @State private var showInWidgetToggle: Bool
    @State private var showWidgetLimitAlert = false
    @State private var showWidgetManagementSheet = false
    @State private var allCoupons: [Coupon] = []
    @State private var widgetStateChanged = false
    @State private var showSpecialMessageEditor = false
    @State private var specialMessageDraft: String = ""
    @State private var specialMessageError: String? = nil
    
    // Initialize showInWidgetToggle with the coupon's current value
    init(coupon: Coupon, user: User, companies: [Company], onUpdate: @escaping () -> Void) {
        self._coupon = State(initialValue: coupon)
        self.user = user
        self.companies = companies
        self.onUpdate = onUpdate
        self._showInWidgetToggle = State(initialValue: coupon.showInWidget ?? false)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with company info
                companyHeader

                // Sale info if applicable
                if coupon.isForSale {
                    saleInfoSection
                }
                
                // Tabs section
                tabsSection
                
                // Tab content
                tabContent
                
                // Section divider
                sectionDivider
                
                // Usage history
                usageHistorySection
                
                // Action buttons
                actionButtonsSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.backward")
                        Text("חזרה")
                    }
                }
            }
        }
        .sheet(isPresented: $showingUsageSheet) {
            UsageCouponSheet(coupon: coupon, onUsage: recordUsage)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCouponView(coupon: coupon, onUpdate: onUpdate)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: ["שיתוף קופון \(coupon.company)"])
        }
        .sheet(isPresented: $showSpecialMessageEditor) {
            SpecialMessageEditor(
                initialText: coupon.specialMessage ?? "",
                onSave: { newText in
                    let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let payload: [String: Any] = trimmed.isEmpty ? ["special_message": NSNull()] : ["special_message": trimmed]
                    couponAPI.updateCoupon(couponId: coupon.id, data: payload) { result in
                        switch result {
                        case .success:
                            self.coupon.specialMessage = trimmed.isEmpty ? nil : trimmed
                            self.showSpecialMessageEditor = false
                        case .failure(let error):
                            print("❌ Failed to update special_message: \(error)")
                            // Surface the error to the user instead of failing silently
                            self.specialMessageError = "Failed to save message: \(error.localizedDescription)"
                        }
                    }
                },
                onCancel: { showSpecialMessageEditor = false }
            )
        }
        // Error alert for special message save/delete failures
        .alert(isPresented: Binding(
            get: { specialMessageError != nil },
            set: { _ in specialMessageError = nil }
        )) {
            Alert(
                title: Text("שגיאת שמירה"),
                message: Text(specialMessageError ?? ""),
                dismissButton: .default(Text("אישור"))
            )
        }
        .rtlAlert("מחיקת קופון",
                  isPresented: $showingDeleteAlert,
                  message: "האם אתה בטוח שברצונך למחוק את הקופון? פעולה זו אינה ניתנת לביטול.",
                  buttons: [
                    RTLAlertButton("מחק", role: .destructive) { deleteCoupon() },
                    RTLAlertButton("ביטול", role: .cancel, action: nil)
                  ])
        .rtlAlert("סימון קופון כנוצל",
                  isPresented: $showingMarkUsedAlert,
                  message: "האם אתה בטוח שברצונך לסמן קופון זה כנוצל?",
                  buttons: [
                    RTLAlertButton("סמן כנוצל", role: .destructive) { markCouponAsUsed() },
                    RTLAlertButton("ביטול", role: .cancel, action: nil)
                  ])
        .rtlAlert("הגעת למקסימום קופונים בווידג'ט",
                  isPresented: $showWidgetLimitAlert,
                  message: "ניתן להציג עד 4 קופונים בווידג'ט. כדי להוסיף קופון זה, עליך להסיר קופון אחר תחילה.",
                  buttons: [
                    RTLAlertButton("נהל קופונים בווידג'ט") { showWidgetManagementSheet = true },
                    RTLAlertButton("ביטול", role: .cancel, action: nil)
                  ])
        .sheet(isPresented: $showWidgetManagementSheet) {
            WidgetCouponsManagementView(user: user, onUpdate: {
                loadAllCoupons()
                onUpdate()
            })
        }
        .onAppear {
            loadUsageHistory()
            loadConsolidatedRows()
            // Update last_detail_view timestamp for this specific coupon
            couponAPI.updateLastDetailView(for: coupon.id) { result in
                switch result {
                case .success:
                    print("✅ Updated last_detail_view for coupon \(coupon.id)")
                case .failure(let error):
                    print("❌ Failed to update last_detail_view for coupon \(coupon.id): \(error)")
                }
            }
            // Load all coupons to check widget limit
            loadAllCoupons()
            // Refresh the current coupon data to get latest show_in_widget value
            refreshCouponData()
        }
        .onDisappear {
            // Only refresh when widget state actually changed.
            // Avoid triggering a full list reload on simple back navigation,
            // which caused the navigation stack to pop to the main screen.
            if widgetStateChanged {
                print("⏰ Widget state changed, waiting before refresh...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.onUpdate()
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    // MARK: - Company Header
    private var companyHeader: some View {
        VStack(spacing: 20) {
            // Company logo and name
            VStack(alignment: .center, spacing: 12) {
                companyLogoView
                
                Text(coupon.company)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Sale Info Section
    private var saleInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "tag.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    let sellerName: String = "\(user.firstName ?? "") \(user.lastName ?? "")"
                    Text(sellerName)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("מוכר קופון על סך")
                        Text("₪\(Int(coupon.value))")
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("ל\(coupon.company)")
                    }
                    
                    HStack {
                        Text("ב-")
                        Text("₪\(Int(coupon.cost))")
                            .fontWeight(.bold)
                            .foregroundColor(Color.appBlue)
                        
                        if let discountPercentage = calculateDiscountPercentage() {
                            Text("\(Int(discountPercentage))% הנחה")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .font(.caption)
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
            }
            
            if coupon.userId != user.id {
                HStack(spacing: 12) {
                    Button("פרופיל המוכר") {
                        // Navigate to seller profile
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("בקש קופון") {
                        // Request coupon action
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("זהו הקופון שלך שעומד למכירה")
                        .fontWeight(.medium)
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var companyLogoView: some View {
        Group {
            if let url = companyImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    case .failure(_):
                        fallbackLogo
                    case .empty:
                        ProgressView()
                            .frame(width: 100, height: 100)
                    @unknown default:
                        fallbackLogo
                    }
                }
            } else {
                fallbackLogo
            }
        }
        .frame(width: 100, height: 100)
    }
    
    private var fallbackLogo: some View {
        ZStack {
            Circle()
                .fill(Color.appBlue.opacity(0.1))
            
            Text(String(coupon.company.prefix(2).uppercased()))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.appBlue)
        }
        .frame(width: 100, height: 100)
    }
    
    private var companyImageURL: URL? {
        // Use the same pattern as the main page
        if let company = companies.first(where: { $0.name.lowercased() == coupon.company.lowercased() }) {
            let baseURL = "https://www.couponmasteril.com/static/"
            return URL(string: baseURL + company.imagePath)
        }
        return nil
    }
    
    // MARK: - Tabs Section
    private var tabsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TabButton(title: "פרטי קופון", icon: "info.circle", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                if !coupon.isForSale {
                    TabButton(title: "ערכים כספיים", icon: "shekel.sign", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                }
                
                TabButton(title: "נתונים נוספים", icon: "list.clipboard", isSelected: selectedTab == (coupon.isForSale ? 1 : 2)) {
                    selectedTab = coupon.isForSale ? 1 : 2
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Tab Content
    private var tabContent: some View {
        VStack(spacing: 20) {
            switch selectedTab {
            case 0:
                couponDetailsTab
            case 1:
                if coupon.isForSale {
                    additionalDataTab
                } else {
                    financialValuesTab
                }
            case 2:
                additionalDataTab
            default:
                couponDetailsTab
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Coupon Details Tab
    private var couponDetailsTab: some View {
        VStack(spacing: 16) {
            // Special message banner or add button (shown only on details tab)
            if let msg = coupon.specialMessage, !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                SpecialMessageBanner(message: msg) {
                    if coupon.userId == user.id {
                        specialMessageDraft = msg
                        showSpecialMessageEditor = true
                    }
                }
            } else if coupon.userId == user.id {
                Button {
                    specialMessageDraft = ""
                    showSpecialMessageEditor = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.bubble")
                            .foregroundColor(.blue)
                        Text("הוסף הודעה מיוחדת")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }

            // Show-in-widget toggle (only for the owner and active coupons)
            if coupon.userId == user.id && coupon.status == "פעיל" {
                Toggle("הצג בווידג'ט", isOn: $showInWidgetToggle)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .onChange(of: showInWidgetToggle) { _, newValue in
                        updateShowInWidget(show: newValue)
                    }
            }

            // Usage percentage moved to the Coupon Details tab
            if !coupon.isForSale {
                InfoBoxWithProgress(icon: "percent", title: "אחוז שימוש:", progress: coupon.usagePercentage / 100)
            }

            if !coupon.isForSale {
                // Coupon code
                InfoBox(icon: "barcode", title: "קוד קופון:", value: coupon.decryptedCode, isCopyable: true)
                // Card fields directly under the code when available
                if let cardExp = coupon.decryptedCardExp, !cardExp.isEmpty {
                    InfoBox(icon: "calendar", title: "תוקף הכרטיס:", value: cardExp)
                }
                if let cvv = coupon.decryptedCvv, !cvv.isEmpty {
                    InfoBox(icon: "lock", title: "CVV:", value: cvv)
                }
            }
            
            InfoBox(icon: "building.2", title: "חברה:", value: coupon.company)
            
            if coupon.isOneTime {
                InfoBox(icon: "target", title: "מטרת הקופון:", value: coupon.purpose ?? "")
                InfoBox(icon: "checkmark.circle", title: "קוד לשימוש חד פעמי:", value: "כן")
                
                // One-time coupon buttons
                if coupon.userId == user.id && coupon.status == "פעיל" {
                    VStack(spacing: 12) {
                        Button("סימון הקופון כנוצל") {
                            showingMarkUsedAlert = true
                        }
                        .buttonStyle(DangerButtonStyle())
                        
                        if canShare {
                            Button(user.gender == "נקבה" || user.gender == "female" ? "שתפי את הקופון עם חבר" : "שתף את הקופון עם חבר") {
                                showingShareSheet = true
                            }
                            .buttonStyle(ShareButtonStyle())
                        }
                    }
                    .padding(.top, 20)
                }
            }
            
            if coupon.isForSale {
                InfoBox(icon: "shekel.sign", title: "ערך הקופון בפועל:", value: "₪\(String(format: "%.2f", coupon.value))", isHighlighted: true)
                InfoBox(icon: "banknote", title: "מחיר מבוקש:", value: "₪\(String(format: "%.2f", coupon.cost))", isHighlighted: true)
            }
            
            // Regular coupon share button
            if canShare && !coupon.isOneTime && coupon.userId == user.id && coupon.status == "פעיל" {
                Button(user.gender == "נקבה" || user.gender == "female" ? "שתפי את הקופון עם חבר" : "שתף את הקופון עם חבר") {
                    showingShareSheet = true
                }
                .buttonStyle(ShareButtonStyle())
                .padding(.top, 20)
            }
        }
    }
    
    // MARK: - Financial Values Tab
    private var financialValuesTab: some View {
        VStack(spacing: 20) {
            // Chart container
            VStack(spacing: 16) {
                Text("סיכום ערכים")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // Pie chart
                if #available(iOS 16.0, *) {
                    Chart {
                        SectorMark(
                            angle: .value("ערך שנוצל", coupon.usedValue),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(.red)
                        .opacity(0.8)
                        
                        SectorMark(
                            angle: .value("ערך נותר", coupon.remainingValue),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(.green)
                        .opacity(0.8)
                    }
                    .frame(height: 200)
                    .chartBackground { _ in
                        VStack {
                            Text("₪\(String(format: "%.2f", coupon.value))")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("סה״כ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // Fallback for iOS 15
                    SimpleProgressChart(usedValue: coupon.usedValue, totalValue: coupon.value)
                        .frame(height: 200)
                }
                
                // Value details
                VStack(spacing: 12) {
                    InfoBox(icon: "tag", title: "ערך מקורי:", value: "₪\(String(format: "%.2f", coupon.value))", isHighlighted: true)
                    InfoBox(icon: "cart", title: "ערך שהשתמשת בו:", value: "₪\(String(format: "%.2f", coupon.usedValue))", isHighlighted: true)
                    if !coupon.isOneTime {
                        InfoBox(icon: "coins", title: "ערך נותר:", value: "₪\(String(format: "%.2f", coupon.remainingValue))", isHighlighted: true)
                    }
                }
            }
        }
    }
    
    // MARK: - Additional Data Tab
    private var additionalDataTab: some View {
        VStack(spacing: 16) {
            if !coupon.isForSale {
                if let source = coupon.source, !source.isEmpty, source != "לא צוין" {
                    InfoBox(icon: "storefront", title: "מאיפה קיבלת את הקופון:", value: source)
                }

                InfoBox(icon: "calendar.badge.plus", title: "תאריך הזנה:", value: formatDate(coupon.dateAdded))
            }
            
            // External links
            if let buymeUrl = coupon.decryptedBuyMeUrl, !buymeUrl.isEmpty {
                ExternalLinkBox(icon: "link", title: "קישור BuyMe:", url: buymeUrl, buttonText: "עבור ל-BuyMe")
            }
            
            if let xtraUrl = coupon.decryptedXtraUrl, !xtraUrl.isEmpty {
                ExternalLinkBox(icon: "link", title: "קישור Xtra:", url: xtraUrl, buttonText: "עבור ל-Xtra")
            }
            
            if let straussUrl = coupon.decryptedStraussUrl, !straussUrl.isEmpty {
                ExternalLinkBox(icon: "link", title: "קישור שטראוס פלוס:", url: straussUrl, buttonText: "עבור לשטראוס פלוס")
            }
            
            // Tags/Categories
            InfoBox(icon: "tag", title: "קטגוריה:", value: "אין קטגוריה") // TODO: Add tags support
            
            InfoBox(icon: "banknote", title: "כמה שילמת על הקופון:", value: "₪\(String(format: "%.2f", coupon.cost))")
            
            // Savings percentage
            if coupon.value > 0 {
                let savingsPercentage = ((coupon.value - coupon.cost) / coupon.value * 100)
                InfoBox(icon: "percent", title: "כמה אחוז חסכת:", value: "\(String(format: "%.2f", savingsPercentage))%", isHighlighted: savingsPercentage > 0)
            }
            
            if let expiration = coupon.expiration, !expiration.isEmpty {
                InfoBox(icon: "calendar", title: "תוקף עד:", value: formatDate(expiration), isExpiring: coupon.isExpired)
            }
            
            if let description = coupon.decryptedDescription, !description.isEmpty, description != "nan" {
                InfoBox(icon: "text.alignleft", title: "תיאור:", value: description)
            }
        }
    }
    
    // MARK: - Section Divider
    private var sectionDivider: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.gray)
                .padding(.horizontal, 10)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
    }
    
    // MARK: - Usage History Section
    private var usageHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("היסטוריית טעינות / שימושים")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
            
            if consolidatedRows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("אין תנועות להצגה.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    // Table header
                    HStack {
                        Text("תאריך")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("סכום")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 60, alignment: .center)
                        
                        Text("פרטים")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    
                    // Table rows
                    ForEach(consolidatedRows, id: \.transactionId) { row in
                        TransactionRowView(row: row, isSum: row.sourceTable == "sum_row")
                        
                        if row.transactionId != consolidatedRows.last?.transactionId {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Secondary actions
            HStack(spacing: 12) {
                Button("עדכון שימוש בקופון") {
                    showingUsageSheet = true
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("ערוך קופון") {
                    showingEditSheet = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            // Primary actions
            HStack(spacing: 12) {
                Button("מחק קופון") {
                    showingDeleteAlert = true
                }
                .buttonStyle(DangerButtonStyle())
                
                Button("חזרה למסך הקופונים") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - Computed Properties
    private var canShare: Bool {
        coupon.userId == user.id && coupon.status == "פעיל"
    }
    
    // MARK: - Helper Functions
    private func loadUsageHistory() {
        isLoading = true
        couponAPI.fetchCouponUsageHistory(couponId: coupon.id) { result in
            isLoading = false
            switch result {
            case .success(let history):
                usageHistory = history
            case .failure(let error):
                print("Failed to load usage history: \(error)")
            }
        }
    }
    
    private func loadConsolidatedRows() {
        isLoading = true
        print("🔄 Loading consolidated rows for coupon ID: \(coupon.id)")
        couponAPI.fetchConsolidatedTransactionRows(couponId: coupon.id) { result in
            isLoading = false
            switch result {
            case .success(let rows):
                consolidatedRows = rows
                print("✅ Successfully loaded \(rows.count) consolidated transaction rows")
                for (index, row) in rows.enumerated() {
                    print("   Row \(index): \(row.sourceTable) | Amount: \(row.transactionAmount) | Details: \(row.details ?? "nil") | Date: \(row.timestamp ?? "nil")")
                }
            case .failure(let error):
                print("❌ Failed to load consolidated transaction rows: \(error)")
                consolidatedRows = []
            }
        }
    }
    
    private func recordUsage(amount: Double, details: String) {
        let usageRequest = CouponUsageRequest(
            usedAmount: amount,
            action: "use",
            details: details
        )
        
        couponAPI.updateCouponUsage(couponId: coupon.id, usageRequest: usageRequest) { result in
            switch result {
            case .success:
                // Optimistically update local coupon's usedValue so remaining reflects immediately
                let updated = Coupon(
                    id: coupon.id,
                    code: coupon.code,
                    description: coupon.description,
                    value: coupon.value,
                    cost: coupon.cost,
                    company: coupon.company,
                    expiration: coupon.expiration,
                    source: coupon.source,
                    buyMeCouponUrl: coupon.buyMeCouponUrl,
                    straussCouponUrl: coupon.straussCouponUrl,
                    xgiftcardCouponUrl: coupon.xgiftcardCouponUrl,
                    xtraCouponUrl: coupon.xtraCouponUrl,
                    dateAdded: coupon.dateAdded,
                    usedValue: coupon.usedValue + amount,
                    status: coupon.status,
                    isAvailable: coupon.isAvailable,
                    isForSale: coupon.isForSale,
                    isOneTime: coupon.isOneTime,
                    purpose: coupon.purpose,
                    excludeSaving: coupon.excludeSaving,
                    autoDownloadDetails: coupon.autoDownloadDetails,
                    userId: coupon.userId,
                    cvv: coupon.cvv,
                    cardExp: coupon.cardExp,
                    specialMessage: coupon.specialMessage,
                    showInWidget: coupon.showInWidget,
                    widgetDisplayOrder: coupon.widgetDisplayOrder
                )
                self.coupon = updated
                onUpdate()
                loadUsageHistory()
                loadConsolidatedRows()
            case .failure(let error):
                print("Failed to record usage: \(error)")
            }
        }
    }
    
    private func deleteCoupon() {
        couponAPI.deleteCoupon(couponId: coupon.id) { result in
            switch result {
            case .success:
                onUpdate()
                presentationMode.wrappedValue.dismiss()
            case .failure(let error):
                print("Failed to delete coupon: \(error)")
            }
        }
    }
    
    private func loadAllCoupons() {
        couponAPI.fetchUserCoupons(userId: user.id) { result in
            switch result {
            case .success(let coupons):
                allCoupons = coupons
            case .failure(let error):
                print("Failed to load coupons: \(error)")
            }
        }
    }
    
    private func refreshCouponData() {
        couponAPI.fetchUserCoupons(userId: user.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let coupons):
                    // Find the current coupon in the refreshed list
                    if let refreshedCoupon = coupons.first(where: { $0.id == self.coupon.id }) {
                        self.coupon = refreshedCoupon
                        self.showInWidgetToggle = refreshedCoupon.showInWidget ?? false
                        print("✅ Refreshed coupon data: show_in_widget = \(refreshedCoupon.showInWidget ?? false)")
                    }
                case .failure(let error):
                    print("❌ Failed to refresh coupon data: \(error)")
                }
            }
        }
    }
    
    private func updateShowInWidget(show: Bool) {
        print("🔵 updateShowInWidget called: show=\(show) for coupon \(coupon.id)")
        
        // Mark that widget state changed
        widgetStateChanged = true
        
        // If trying to enable, check the limit
        if show {
            print("🔵 Enabling widget for coupon \(coupon.id)")
            // If allCoupons is empty, load them first
            if allCoupons.isEmpty {
                print("⚠️ allCoupons is empty, loading first...")
                couponAPI.fetchUserCoupons(userId: user.id) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let coupons):
                            self.allCoupons = coupons
                            print("✅ Loaded \(coupons.count) coupons")
                            // Now check the limit with loaded data
                            self.checkLimitAndUpdate(show: show)
                        case .failure(let error):
                            print("❌ Failed to load coupons: \(error)")
                            // Revert toggle on error
                            self.showInWidgetToggle = false
                        }
                    }
                }
                return
            }
            
            checkLimitAndUpdate(show: show)
        } else {
            print("🔵 Disabling widget for coupon \(coupon.id)")
            // Disabling - no need to check limit
            performUpdate(show: show)
        }
    }
    
    private func checkLimitAndUpdate(show: Bool) {
        // Count only coupons that are eligible to appear in the widget:
        // active, not expired, and not fully used (unless one-time).
        let currentWidgetCouponsCount = allCoupons.filter { c in
            (c.showInWidget == true) &&
            (c.id != coupon.id) &&
            (c.status == "פעיל") &&
            (!c.isExpired) &&
            (!c.isFullyUsed || c.isOneTime)
        }.count
        
        print("🔍 Current widget coupons count: \(currentWidgetCouponsCount)")
        
        if currentWidgetCouponsCount >= 4 {
            // Revert the toggle
            showInWidgetToggle = false
            // Show alert
            showWidgetLimitAlert = true
            return
        }
        
        performUpdate(show: show)
    }
    
    private func performUpdate(show: Bool) {
        let userId = user.id
        let couponId = coupon.id
        
        print("🔄 performUpdate called: show=\(show) for coupon \(couponId)")
        
        couponAPI.updateCoupon(couponId: couponId, data: ["show_in_widget": show]) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Successfully updated show_in_widget in database")
                    // עדכן את המצב המקומי
                    self.coupon.showInWidget = show
                    // רענן את רשימת הקופונים
                    self.loadAllCoupons()
                    // DON'T call onUpdate() here - it causes the view to dismiss
                    // self.onUpdate()
                    
                    // שמור את הנתונים המעודכנים ל-shared container
                    print("📦 Fetching all coupons to update shared container...")
                    self.couponAPI.fetchUserCoupons(userId: userId) { fetchResult in
                        DispatchQueue.main.async {
                            if case .success(let updatedCoupons) = fetchResult {
                                print("📦 Saving \(updatedCoupons.count) coupons to shared container")
                                let widgetCoupons = updatedCoupons.filter { $0.showInWidget == true }
                                print("📦 Widget coupons count: \(widgetCoupons.count)")
                                for wc in widgetCoupons {
                                    print("   - ID:\(wc.id) | \(wc.company) | show_in_widget:\(wc.showInWidget ?? false)")
                                }
                                
                                AppGroupManager.shared.saveCouponsToSharedContainer(updatedCoupons)
                                print("✅ Updated shared container with new widget coupon data")
                                
                                // בקש ריענון מהיר של הווידג'ט
                                if #available(iOS 14.0, *) {
                                    WidgetCenter.shared.reloadTimelines(ofKind: "CouponManagerWidget")
                                    print("🔄 Requested widget timeline reload")
                                }
                            } else {
                                print("❌ Failed to fetch updated coupons for shared container")
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Failed to update show_in_widget: \(error)")
                    // Revert toggle on error
                    self.showInWidgetToggle = !show
                }
            }
        }
    }


    private func markCouponAsUsed() {
        couponAPI.markCouponAsUsed(couponId: coupon.id) { result in
            switch result {
            case .success:
                // If this coupon was selected for the widget, clear it
                if (self.coupon.showInWidget ?? false) {
                    let update: [String: Any] = ["show_in_widget": false, "widget_display_order": NSNull()]
                    self.couponAPI.updateCoupon(couponId: self.coupon.id, data: update) { _ in
                        // Best-effort; ignore errors for UX
                        AppGroupManager.shared.refreshWidgetTimelines()
                    }
                }
                onUpdate()
                presentationMode.wrappedValue.dismiss()
            case .failure(let error):
                print("Failed to mark coupon as used: \(error)")
            }
        }
    }
    
    private func calculateDiscountPercentage() -> Double? {
        guard coupon.value > 0 else { return nil }
        return ((coupon.value - coupon.cost) / coupon.value * 100)
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Try several parsers to cover values with/without milliseconds or timezone
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var parsedDate: Date? = iso.date(from: dateString)

        if parsedDate == nil {
            // Try ISO8601 without fractional seconds
            let isoNoFrac = ISO8601DateFormatter()
            isoNoFrac.formatOptions = [.withInternetDateTime]
            parsedDate = isoNoFrac.date(from: dateString)
        }

        if parsedDate == nil {
            // Try custom formats without timezone
            let df1 = DateFormatter()
            df1.locale = Locale(identifier: "en_US_POSIX")
            df1.timeZone = TimeZone(secondsFromGMT: 0)
            df1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS" // microseconds
            parsedDate = df1.date(from: dateString)

            if parsedDate == nil {
                let df2 = DateFormatter()
                df2.locale = Locale(identifier: "en_US_POSIX")
                df2.timeZone = TimeZone(secondsFromGMT: 0)
                df2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss" // seconds only
                parsedDate = df2.date(from: dateString)
            }
        }

        if parsedDate == nil {
            // Date-only (e.g., expiration "yyyy-MM-dd")
            let df3 = DateFormatter()
            df3.locale = Locale(identifier: "en_US_POSIX")
            df3.timeZone = TimeZone(secondsFromGMT: 0)
            df3.dateFormat = "yyyy-MM-dd"
            parsedDate = df3.date(from: dateString)
        }

        guard let date = parsedDate else {
            return dateString
        }

        // Output in Hebrew (Israel) locale; include time only if string had time
        let showTime = dateString.contains("T") || dateString.contains(":")
        let out = DateFormatter()
        out.locale = Locale(identifier: "he_IL")
        out.timeZone = TimeZone.current
        out.dateStyle = .medium
        out.timeStyle = showTime ? .short : .none
        return out.string(from: date)
    }
}


// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.appBlue.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .blue : .secondary)
            .cornerRadius(8)
        }
    }
}

// MARK: - Info Box
struct InfoBox: View {
    let icon: String
    let title: String
    let value: String
    var isHighlighted: Bool = false
    var isExpiring: Bool = false
    var isCopyable: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isExpiring ? .red : Color.appBlue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(isHighlighted ? .semibold : .medium)
                    .foregroundColor(isExpiring ? .red : (isHighlighted ? .green : .primary))
            }
            
            Spacer()
            
            if isCopyable {
                Button {
                    UIPasteboard.general.string = value
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(Color.appBlue)
                }
            }
        }
        .padding(12)
        .background(isHighlighted ? Color.green.opacity(0.1) : Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Info Box with Reveal
struct InfoBoxWithReveal: View {
    let icon: String
    let title: String
    let value: String
    @Binding var isRevealed: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(isRevealed ? value : "•••")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundColor(Color.appBlue)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Info Box with Progress
struct InfoBoxWithProgress: View {
    let icon: String
    let title: String
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Color.appBlue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor(for: progress)))
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func progressColor(for progress: Double) -> Color {
        if progress >= 0.9 { return .red }
        if progress >= 0.7 { return .orange }
        return .blue
    }
}

// MARK: - External Link Box
import SafariServices

struct ExternalLinkBox: View {
    let icon: String
    let title: String
    let url: String
    let buttonText: String
    @State private var safariURL: IdentifiableURL? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.appBlue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(buttonText) {
                if let u = sanitizeURL(url) {
                    // Try system open first; if it declines, show in SafariView
                    UIApplication.shared.open(u, options: [:]) { success in
                        if !success { safariURL = IdentifiableURL(url: u) }
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .font(.caption)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .sheet(item: $safariURL) { u in
            SafariView(url: u.url)
        }
    }
    
    private func sanitizeURL(_ original: String) -> URL? {
        let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        var candidate = trimmed
        if !(candidate.lowercased().hasPrefix("http://") || candidate.lowercased().hasPrefix("https://")) {
            candidate = "https://" + candidate
        }
        return URL(string: candidate) ?? URL(string: candidate.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? candidate)
    }
}

// MARK: - SafariView Wrapper
struct SafariView: UIViewControllerRepresentable, Identifiable {
    let id = UUID()
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Transaction Row View
struct TransactionRowView: View {
    let row: TransactionRow
    let isSum: Bool
    
    var body: some View {
        HStack {
            Text(formatTimestamp(row.timestamp))
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("\(row.transactionAmount, specifier: "%.2f")")
                .font(.caption)
                .fontWeight(isSum ? .bold : .medium)
                .foregroundColor(row.transactionAmount < 0 ? .red : .green)
                .frame(width: 60, alignment: .center)
            
            Text(row.details ?? "")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSum ? Color(.tertiarySystemBackground) : Color.clear)
    }
    
    private func formatTimestamp(_ timestamp: String?) -> String {
        guard let ts = timestamp, !ts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "-" }

        // First try robust ISO8601 parsing (supports Z, +00:00, fractional seconds)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: ts)
        if date == nil {
            let isoNoFraction = ISO8601DateFormatter()
            isoNoFraction.formatOptions = [.withInternetDateTime]
            date = isoNoFraction.date(from: ts)
        }

        // Fallbacks for common Postgres/PostgREST string shapes
        if date == nil {
            let patterns = [
                "yyyy-MM-dd'T'HH:mm:ssXXXXX",            // timezone as +00:00
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",     // fractional + timezone
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",         // fractional + Z/+0000
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd HH:mm:ssZ",
                "yyyy-MM-dd HH:mm:ss.SSSSSS"
            ]
            for p in patterns {
                let df = DateFormatter()
                df.dateFormat = p
                df.locale = Locale(identifier: "en_US_POSIX")
                if let d = df.date(from: ts) { date = d; break }
            }
        }

        guard let final = date else { return "-" }

        let display = DateFormatter()
        display.dateStyle = .short
        display.timeStyle = .none
        display.locale = Locale(identifier: "he_IL")
        return display.string(from: final)
    }
}

// MARK: - Simple Progress Chart (iOS 15 fallback)
struct SimpleProgressChart: View {
    let usedValue: Double
    let totalValue: Double
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: CGFloat(usedValue / totalValue))
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("₪\(String(format: "%.2f", totalValue))")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("סה״כ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label("נוצל", systemImage: "circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                
                Spacer()
                
                Label("נותר", systemImage: "circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.appBlue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ShareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Special Message UI

struct SpecialMessageBanner: View {
    let message: String
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "star.bubble.fill")
                .foregroundColor(.yellow)
                .font(.title2)
                .padding(.top, 2)
            
            Text(message)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .background(Color.yellow.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
        )
    }
}

struct SpecialMessageEditor: View {
    @State var text: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    init(initialText: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self._text = State(initialValue: initialText)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Text("הודעה מיוחדת")
                        .font(.headline)
                }

                RTLTextEditor(text: $text)
                    .frame(minHeight: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(16)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Place Save on the right (RTL leading) and Cancel on the left (RTL trailing)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("שמור") { onSave(text) }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("ביטול") { onCancel() }
                }
            }
            // Keep action buttons always above the keyboard
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button("ביטול") { onCancel() }
                        .buttonStyle(SecondaryButtonStyle())
                    
                    Spacer()
                    
                    if !isEmpty {
                        Button("מחק הודעה") { onSave("") }
                            .buttonStyle(DangerButtonStyle())
                    }
                    
                    Button("שמור") { onSave(text) }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - RTL TextEditor helper
private struct RTLTextEditor: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.textAlignment = .right
        tv.semanticContentAttribute = .forceRightToLeft
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        // Ensure alignment stays right-to-left if system flips
        uiView.textAlignment = .right
        uiView.semanticContentAttribute = .forceRightToLeft
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RTLTextEditor
        init(_ parent: RTLTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

#Preview {
    NavigationView {
        CouponDetailView(
            coupon: Coupon(
                id: 1,
                code: "SAVE20",
                description: "הנחה על קניות בסופר",
                value: 100.0,
                cost: 80.0,
                company: "קרפור",
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
                Company(id: 1, name: "קרפור", imagePath: "images/carrefour.png", companyCount: 1)
            ],
            onUpdate: {}
        )
    }
    .environment(\.layoutDirection, .rightToLeft)
}
