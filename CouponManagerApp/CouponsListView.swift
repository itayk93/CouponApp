//
//  CouponsListView.swift
//  CouponManagerApp
//
//  מסך רשימת הקופונים הראשי - עם עיצוב מודרני רק למסך החברה
//

import SwiftUI

struct CouponsListView: View {
    let user: User
    let onLogout: (() -> Void)?
    
    @StateObject private var couponAPI = CouponAPIClient()
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var coupons: [Coupon] = []
    @State private var filteredCoupons: [Coupon] = []
    @State private var companies: [Company] = []
    @State private var companyUsageStats: [CompanyUsageStats] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedFilter = CouponFilter.active
    @State private var selectedSort = CouponSort.dateAdded
    @State private var showingAddCoupon = false
    @State private var showingQuickAddSheet = false
    @State private var showingImageAnalysis = false
    @State private var incomingSharedImage: UIImage? = nil
    @State private var errorMessage = ""
    @State private var showingFilterSheet = false
    // Pagination variables removed - all coupons loaded at once
    @State private var selectedCompanyForQuickAdd: Company?
    @State private var quickAddText = ""
    @State private var isProcessingQuickAdd = false
    @State private var showingQuickUsageReport = false
    @State private var showingSavingsReport = false
    @State private var showingProfile = false
    @State private var selectedCouponForDetail: Coupon? = nil
    @State private var viewId = UUID()
    @State private var lastSelectedCouponIdForRestore: Int? = nil
    @State private var expiringCoupons: [Coupon] = []
    @State private var selectedCompanyFromWidget: String? = nil
    @State private var monthlySummaryTrigger: MonthlySummaryTrigger? = nil
    @State private var showingMonthlySummary = false
    @State private var showingMonthlySummariesList = false
    @State private var monthlySummaryFilter: (month: Int, year: Int)? = nil
    
    var body: some View {
        withEventHandlers
    }
    
    private var mainNavigationView: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Blue header bar (like website)
                blueHeaderBar
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Expiration banner at the top
                        if !expiringCoupons.isEmpty {
                            ExpirationBanner(expiringCoupons: expiringCoupons) { coupon in
                                selectedCouponForDetail = coupon
                            }
                        }
                        
                        // Main dashboard content
                        mainDashboardView
                        
                        // Search and Filter Bar
                        searchFilterBar
                        
                        // Content
                        if isLoading {
                            loadingView
                        } else if coupons.isEmpty {
                            emptyStateView
                        } else {
                            // If the selected filter is Active, show grouped companies first
                            if selectedFilter == .active {
                                activeCompaniesGroupedView
                            } else {
                                // Otherwise show the normal coupon list content
                                couponListContent
                            }
                        }
                    }
                }
            }
            .refreshable {
                resetAndLoadData()
            }
            #if targetEnvironment(simulator)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .navigationTitle("")
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            .environment(\.layoutDirection, .rightToLeft) // keep main screen RTL
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCoupon = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.appBlue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: loadData) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCoupon = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.appBlue)
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button(action: loadData) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                    }
                }
                #endif
            }
        }
    }
    
    private var withSheetPresentations: some View {
        mainNavigationView
            .sheet(isPresented: $showingAddCoupon) {
                AddCouponView(user: user, companies: companies, preSelectedCompany: selectedCompanyForQuickAdd) {
                    loadData()
                    selectedCompanyForQuickAdd = nil
                }
            }
            .sheet(isPresented: $showingQuickAddSheet) {
                AddCouponFromTextView(
                    user: user,
                    companies: companies,
                    onCouponAdded: {
                        print("🔄 Coupon added, refreshing list...")
                        DispatchQueue.main.async {
                            loadData()
                        }
                        showingQuickAddSheet = false
                    },
                    onSwitchToImageAnalysis: {
                        showingQuickAddSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showingImageAnalysis = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showingImageAnalysis, onDismiss: {
                incomingSharedImage = nil
            }) {
                AddCouponFromImageView(
                    user: user,
                    companies: companies,
                    initialImage: incomingSharedImage,
                    onCouponAdded: {
                        print("🔄 Image coupon added, refreshing list...")
                        DispatchQueue.main.async {
                            loadData()
                        }
                        showingImageAnalysis = false
                    }
                )
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheetView(
                    selectedFilter: $selectedFilter,
                    selectedSort: $selectedSort
                )
            }
            .sheet(isPresented: $showingQuickUsageReport) {
                QuickUsageReportView(
                    user: user,
                    coupons: coupons.filter { !$0.isForSale && $0.status == "פעיל" && !$0.isExpired },
                    allCompanies: companies,
                    onUsageReported: {
                        loadData()
                    }
                )
            }
            .sheet(isPresented: $showingSavingsReport) {
                SavingsReportView(
                    user: user,
                    coupons: coupons.filter { !$0.isForSale },
                    initialMonth: monthlySummaryFilter?.month,
                    initialYear: monthlySummaryFilter?.year
                )
                .environment(\.layoutDirection, .rightToLeft)
                .onDisappear {
                    monthlySummaryFilter = nil
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView(user: user) {
                    // Handle logout - this will be passed up to ContentView
                    showingProfile = false
                    onLogout?()
                }
            }
            .sheet(item: $selectedCouponForDetail) { coupon in
                NavigationView {
                    CouponDetailView(coupon: coupon, user: user, companies: companies, onUpdate: loadData)
                }
            }
            .sheet(isPresented: $showingMonthlySummariesList) {
                MonthlySummariesListView(user: user) { trigger in
                    monthlySummaryTrigger = trigger
                    showingMonthlySummary = true
                    showingMonthlySummariesList = false
                }
            }
            .sheet(isPresented: $showingMonthlySummary) {
                if let trigger = monthlySummaryTrigger {
                    MonthlySummaryView(
                        userId: user.id,
                        month: trigger.month,
                        year: trigger.year,
                        summaryId: trigger.summaryId,
                        onOpenStatistics: { summary in
                            monthlySummaryFilter = (month: summary.month, year: summary.year)
                            showingMonthlySummary = false
                            showingSavingsReport = true
                        },
                        onClose: { showingMonthlySummary = false }
                    )
                }
            }
    }
    
    @Environment(\.scenePhase) private var scenePhase

    private var withEventHandlers: some View {
        withSheetPresentations
            .id(viewId)
            .onAppear {
                if coupons.isEmpty {
                    loadData()
                }
                setupNotifications()
                
                // Ensure user data is saved to shared container every time the app appears
                AppGroupManager.shared.saveCurrentUserToSharedContainer(user)
                consumePendingMonthlySummaryIfNeeded()
            }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .background, .inactive:
                    // If a coupon detail is open and the app goes to background,
                    // remember which coupon was open so we can restore it when returning.
                    if let c = selectedCouponForDetail {
                        lastSelectedCouponIdForRestore = c.id
                    }
                case .active:
                    if let restoreId = lastSelectedCouponIdForRestore, selectedCouponForDetail == nil {
                        if let coupon = coupons.first(where: { $0.id == restoreId }) {
                            // Restore detail sheet
                            selectedCouponForDetail = coupon
                        }
                        lastSelectedCouponIdForRestore = nil
                    }
                @unknown default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToHome"))) { _ in
                // Dismiss any open sheets
                showingAddCoupon = false
                showingQuickAddSheet = false
                showingImageAnalysis = false
                showingFilterSheet = false
                showingQuickUsageReport = false
                showingSavingsReport = false
                showingProfile = false
                selectedCouponForDetail = nil
                
                // Reset navigation by changing the view's ID
                viewId = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToCouponDetail"))) { notification in
                if let couponId = notification.userInfo?["couponId"] as? Int,
                   let coupon = coupons.first(where: { $0.id == couponId }) {
                    selectedCouponForDetail = coupon
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToMonthlySummary)) { notification in
                let monthValue = notification.userInfo?["month"] as? Int ?? Calendar.current.component(.month, from: Date())
                let yearValue = notification.userInfo?["year"] as? Int ?? Calendar.current.component(.year, from: Date())
                let summaryId = notification.userInfo?["summaryId"] as? String
                let style = notification.userInfo?["style"] as? String
                
                monthlySummaryTrigger = MonthlySummaryTrigger(
                    summaryId: summaryId,
                    month: monthValue,
                    year: yearValue,
                    style: style
                )
                showingMonthlySummary = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToAddFromImage"))) { notification in
                // Expecting a file name stored in the shared app group container
                guard let fileName = notification.userInfo?["fileName"] as? String else { return }
                if let image = SharedImageInbox.loadImage(named: fileName) {
                    incomingSharedImage = image
                    showingImageAnalysis = true
                    // Clean the file after loading to avoid growth
                    SharedImageInbox.removeImage(named: fileName)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToCompany"))) { notification in
                if let companyName = notification.object as? String {
                    selectedCompanyFromWidget = companyName
                    searchText = companyName
                    selectedFilter = .active  // Show only active coupons for the company
                    filterCoupons()
                    
                    // Show company filter sheet to display company-specific coupons
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingFilterSheet = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToCompanyFilter"))) { notification in
                if let companyName = notification.object as? String {
                    selectedCompanyFromWidget = companyName
                    searchText = companyName
                    selectedFilter = .active  // Show only active coupons for the company
                    filterCoupons()
                    
                    // Clear any existing search and show company-specific view
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // The coupons are already filtered by the company name
                        // This creates the effect of showing company-specific coupons
                    }
                }
            }
            .onChange(of: searchText) {
                filterCoupons()
            }
            .onChange(of: selectedFilter) {
                filterCoupons()
            }
            .onChange(of: selectedSort) {
                sortCoupons()
            }
            .onChange(of: coupons) {
                updateExpiringCoupons()
                updateNotifications()
            }
    }
    
    // MARK: - Blue Header Bar (Website Style)
    @Environment(\.colorScheme) private var colorScheme
    
    private var blueHeaderBar: some View {
        HStack {
            // Welcome text (left side)
            HStack(spacing: 8) {
                Image(systemName: "house.fill")
                    .font(.system(size: 20))
                    .foregroundColor(headerTextColor)

                Text("ברוך הבא, \(user.firstName ?? "")")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(headerTextColor)
            }

            Spacer()

            // Profile + Stats buttons (right side)
            HStack(spacing: 14) {
                // Statistics ("על מה חסכת?")
                Button(action: { showingSavingsReport = true }) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 20))
                        .foregroundColor(headerTextColor)
                        .accessibilityLabel("סטטיסטיקות חיסכון")
                }

                // Profile
                Button(action: { showingProfile = true }) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 20))
                        .foregroundColor(headerTextColor)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(headerBackgroundGradient)
    }
    
    // MARK: - Dark Mode Support for Header
    private var headerTextColor: Color {
        colorScheme == .dark ? .white : .white
    }
    
    private var headerBackgroundGradient: LinearGradient {
        switch colorScheme {
        case .dark:
            return LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.gray.opacity(0.7)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .light:
            return LinearGradient(
                gradient: Gradient(colors: [Color.appBlue.opacity(0.9), Color.appBlue.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        @unknown default:
            return LinearGradient(
                gradient: Gradient(colors: [Color.appBlue.opacity(0.9), Color.appBlue.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    // MARK: - Main Dashboard View (Website Style)
    private var mainDashboardView: some View {
        VStack(spacing: 20) {
            // Welcome message and savings display
            VStack(spacing: 16) {
                // Good evening/morning message
                Text(getGreetingMessage())
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                
                // Savings card (identical to website)
                VStack(spacing: 12) {
                    Text("נשאר לך בארנק:")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Text(remainingValue)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            
            // Two primary action buttons (quick add + quick usage)
            HStack(spacing: 12) {
                // Green button - Quick Add Coupon
                ActionButton(
                    title: "הוספת קופון מהירה",
                    icon: "plus",
                    color: .green
                ) {
                    showingQuickAddSheet = true
                }
                
                // Orange button - Quick Usage Report
                ActionButton(
                    title: "דיווח מהיר על שימוש",
                    icon: "star.fill",
                    color: .orange
                ) {
                    showingQuickUsageReport = true
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
    }
    
    private func getGreetingMessage() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let firstName = user.firstName ?? "משתמש"
        
        if hour < 12 {
            return "בוקר טוב, \(firstName)!"
        } else if hour < 18 {
            return "צהריים טובים, \(firstName)!"
        } else {
            return "ערב טוב, \(firstName)!"
        }
    }
    
    
    // MARK: - Search and Filter Bar
    private var searchFilterBar: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("חיפוש קופונים...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .multilineTextAlignment(.trailing)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Hide the "forSale" chip - we don't want to expose sale coupons
                    ForEach(CouponFilter.allCases.filter({ $0 != .forSale }), id: \.self) { filter in
                        FilterChip(
                            title: filter.displayName,
                            isSelected: selectedFilter == filter,
                            count: getFilterCount(filter)
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
            }
            #if targetEnvironment(simulator)
            .scrollDismissesKeyboard(.interactively)
            #endif
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("טוען קופונים...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("אין לך קופונים עדיין")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("הוסף את הקופון הראשון שלך כדי להתחיל לחסוך כסף!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { showingAddCoupon = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("הוסף קופון")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.appBlue)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Active Companies Grouped View (ORIGINAL - NO CHANGE)
    private var activeCompaniesGroupedView: some View {
        VStack(spacing: 12) {
            // Title
            HStack {
                Text("קופונים פעילים לפי חברה")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            
            // Cards grid: each card shows company name + logo (below)
            let groups = activeCouponsGrouped // computed property below
            if groups.isEmpty {
                Text("אין קופונים פעילים כרגע")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // 3 columns grid with proper spacing to avoid cramped appearance
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(groups.keys.sorted(), id: \.self) { companyName in
                        if let couponsForCompany = groups[companyName] {
                            // ensure we pass coupons without isForSale (group already guarantees that)
                            NavigationLink(destination: CompanyCouponsView(companyName: companyName, coupons: couponsForCompany, user: user, companies: companies, onUpdate: loadData)
                                            .environment(\.layoutDirection, .rightToLeft) // force RTL in destination
                            ) {
                                CompanyLogoCard(companyName: companyName, companies: companies, couponCount: couponsForCompany.count)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Show regular coupon list below
            couponListContent
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Coupons List
    private var couponListContent: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredCoupons) { coupon in
                // Ensure sellable coupons are never shown
                if !coupon.isForSale {
                    NavigationLink(destination: CouponDetailView(coupon: coupon, user: user, companies: companies, onUpdate: loadData)) {
                        CouponRowView(coupon: coupon, companies: companies)
                    }
                    .buttonStyle(PlainButtonStyle())
                    // Removed onAppear for pagination - all coupons loaded at once now
                }
            }
            
            // All coupons loaded at once - no need for pagination indicators
        }
        .padding()
    }
    
    // MARK: - State for total value
    @State private var totalRemainingValue: Double = 0.0
    
    // MARK: - Computed Properties
    private var remainingValue: String {
        // Use the pre-calculated total from server to avoid memory issues
        return String(format: "₪%.2f", totalRemainingValue)
    }
    
    // MARK: - Active grouping helper (NO CHANGE)
    private var activeCouponsGrouped: [String: [Coupon]] {
        // Groups only the active coupons (matching the filter logic used elsewhere)
        let active = coupons.filter { coupon in
            !coupon.isForSale &&
            !coupon.excludeSaving &&
            coupon.status == "פעיל" &&
            !coupon.isExpired &&
            !coupon.isFullyUsed
        }
        
        // Optionally apply searchText filter to the grouped list (so search will filter inside)
        let searched = active.filter { coupon in
            searchText.isEmpty ||
            coupon.company.localizedCaseInsensitiveContains(searchText) ||
            coupon.decryptedCode.localizedCaseInsensitiveContains(searchText) ||
            (coupon.decryptedDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        var dict: [String: [Coupon]] = [:]
        for c in searched {
            dict[c.company, default: []].append(c)
        }
        return dict
    }
    
    // MARK: - Helper Functions (NO CHANGES)
    private func resetAndLoadData() {
        coupons = []
        loadData()
    }
    
    private func loadData() {
        isLoading = true
        errorMessage = ""
        
        // Save current user to shared container for widget access
        AppGroupManager.shared.saveCurrentUserToSharedContainer(user)
        
        let group = DispatchGroup()
        
        // Load ALL coupons without pagination
        group.enter()
        couponAPI.fetchAllUserCoupons(userId: user.id) { result in
            switch result {
            case .success(let fetchedCoupons):
                self.coupons = fetchedCoupons
                // All coupons loaded at once - no need for hasMoreCoupons tracking
                
                // Calculate total value from all coupons if needed
                if self.totalRemainingValue == 0.0 {
                    let filteredCoupons = fetchedCoupons.filter { !$0.isForSale && !$0.excludeSaving && !$0.isOneTime }
                    self.totalRemainingValue = filteredCoupons.reduce(0) { $0 + $1.remainingValue }
                    print("🔄 Calculated total from all coupons: ₪\(self.totalRemainingValue)")
                }
                
            case .failure(let error):
                print("❌ Failed to load all coupons: \(error)")
                self.errorMessage = "שגיאה בטעינת קופונים"
            }
            group.leave()
        }
        
        // Load companies
        group.enter()
        couponAPI.fetchCompanies { result in
            switch result {
            case .success(let fetchedCompanies):
                self.companies = fetchedCompanies
            case .failure:
                // Companies is not critical, continue without error
                break
            }
            group.leave()
        }
        
        // Load total remaining value
        group.enter()
        couponAPI.fetchUserTotalValue(userId: user.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let totalValue):
                    self.totalRemainingValue = totalValue
                case .failure(let error):
                    print("❌ Failed to load total value: \(error)")
                    // Fallback to calculating from loaded coupons if API fails
                    let filteredCoupons = self.coupons.filter { !$0.isForSale && !$0.excludeSaving && !$0.isOneTime }
                    self.totalRemainingValue = filteredCoupons.reduce(0) { $0 + $1.remainingValue }
                    print("🔄 Using fallback calculation: ₪\(self.totalRemainingValue)")
                }
                group.leave()
            }
        }
        
        // Load company usage statistics
        group.enter()
        couponAPI.fetchCompanyUsageStats(userId: user.id) { result in
            switch result {
            case .success(let stats):
                self.companyUsageStats = stats
            case .failure(let error):
                print("❌ Failed to load company usage stats: \(error)")
                // Not critical, continue without error
                break
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
            self.filterCoupons()
            self.updateExpiringCoupons()
            self.updateNotifications()
            
            // Save data to shared container for widget
            AppGroupManager.shared.saveCouponsToSharedContainer(self.coupons)
            AppGroupManager.shared.saveCompaniesToSharedContainer(self.companies)
            
            // After loading data, check if there's a pending coupon requested by widget tap
            self.checkForPendingCoupon()
        }
    }

    // Check shared container for a pending coupon id saved by widget deep link.
    private func checkForPendingCoupon() {
        var pendingId: Int? = nil
        if let sharedDefaults = AppGroupManager.shared.sharedUserDefaults {
            if let val = sharedDefaults.object(forKey: "PendingCouponId") as? Int {
                pendingId = val
            }
        }

        if pendingId == nil {
            if let val = UserDefaults.standard.object(forKey: "PendingCouponId") as? Int {
                pendingId = val
            }
        }

        guard let couponId = pendingId else { return }

        if let coupon = coupons.first(where: { $0.id == couponId }) {
            print("✅ CouponsListView: Found pending coupon id \(couponId). Navigating to details.")
            selectedCouponForDetail = coupon
            // Remove pending id now that we've consumed it
            if let sharedDefaults = AppGroupManager.shared.sharedUserDefaults {
                sharedDefaults.removeObject(forKey: "PendingCouponId")
            }
            UserDefaults.standard.removeObject(forKey: "PendingCouponId")
        } else {
            print("⚠️ CouponsListView: Pending coupon id \(couponId) not found in loaded coupons yet")
        }
    }
    
    // loadMoreCoupons removed - no longer needed since we fetch all coupons at once
    
    // All pagination removed - now using fetchAllUserCoupons to load everything at once!
    
    private func filterCoupons() {
        // Start with all coupons but exclude FOR SALE and EXCLUDE_SAVING coupons from main view
        var filtered = coupons.filter { coupon in
            !coupon.isForSale && !coupon.excludeSaving
        }
        
        // Apply search filter using decrypted values
        if !searchText.isEmpty {
            filtered = filtered.filter { coupon in
                coupon.company.localizedCaseInsensitiveContains(searchText) ||
                coupon.decryptedCode.localizedCaseInsensitiveContains(searchText) ||
                (coupon.decryptedDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply status filter - matching Flask logic exactly
        switch selectedFilter {
        case .all:
            // Show all coupons (already filtered for for_sale and exclude_saving above)
            break
        case .active:
            filtered = filtered.filter { $0.status == "פעיל" && !$0.isExpired && !$0.isFullyUsed }
        case .expired:
            filtered = filtered.filter { $0.isExpired }
        case .fullyUsed:
            filtered = filtered.filter { $0.status != "פעיל" || $0.isFullyUsed }
        case .forSale:
            // We explicitly disable viewing for-sale coupons — show none
            filtered = []
        }
        
        filteredCoupons = filtered
        sortCoupons()
    }
    
    private func sortCoupons() {
        // Special smart sorting: expiring soon first, then by company usage
        filteredCoupons.sort { coupon1, coupon2 in
            // First priority: Coupons expiring within a week (7 days)
            let isExpiringSoon1 = coupon1.isExpiringInWeek
            let isExpiringSoon2 = coupon2.isExpiringInWeek
            
            if isExpiringSoon1 && !isExpiringSoon2 {
                return true  // coupon1 is expiring soon, prioritize it
            }
            if !isExpiringSoon1 && isExpiringSoon2 {
                return false // coupon2 is expiring soon, prioritize it
            }
            
            // If both are expiring soon, sort by actual expiration date (closest first)
            if isExpiringSoon1 && isExpiringSoon2 {
                if let exp1 = coupon1.expirationDate, let exp2 = coupon2.expirationDate {
                    return exp1 < exp2
                }
            }
            
            // Second priority: Company usage statistics (most used companies first)
            let company1Stats = companyUsageStats.first { $0.company == coupon1.company }
            let company2Stats = companyUsageStats.first { $0.company == coupon2.company }
            
            let company1Rank = company1Stats != nil ? getCompanyRank(company1Stats!) : Int.max
            let company2Rank = company2Stats != nil ? getCompanyRank(company2Stats!) : Int.max
            
            if company1Rank != company2Rank {
                return company1Rank < company2Rank  // Lower rank = higher priority
            }
            
            // Third priority: Remaining value (higher first)
            if coupon1.remainingValue != coupon2.remainingValue {
                return coupon1.remainingValue > coupon2.remainingValue
            }
            
            // Final priority: Date added (newer first)
            return coupon1.dateAdded > coupon2.dateAdded
        }
    }
    
    // Helper function to get company rank based on usage statistics
    private func getCompanyRank(_ stats: CompanyUsageStats) -> Int {
        // Find the index of this company in the sorted usage stats
        // Companies are already sorted by paid_count DESC, total_count DESC
        return companyUsageStats.firstIndex { $0.company == stats.company } ?? Int.max
    }
    
    private func getFilterCount(_ filter: CouponFilter) -> Int {
        switch filter {
        case .all:
            return coupons.count
        case .active:
            return coupons.filter { !$0.isExpired && !$0.isFullyUsed && $0.status == "פעיל" }.count
        case .expired:
            return coupons.filter { $0.isExpired }.count
        case .fullyUsed:
            return coupons.filter { $0.isFullyUsed }.count
        case .forSale:
            return coupons.filter { $0.isForSale }.count
        }
    }
    
    // MARK: - Notification and Expiration Functions
    private func setupNotifications() {
        Task {
            let granted = await notificationManager.requestAuthorization()
            if granted {
                updateNotifications()
            } else {
                print("❌ Notification permission denied")
            }
        }
    }
    
    private func updateNotifications() {
        guard notificationManager.authorizationStatus == .authorized else { 
            print("❌ Cannot update notifications - not authorized")
            return 
        }
        notificationManager.updateNotifications(for: coupons)
    }
    
    private func consumePendingMonthlySummaryIfNeeded() {
        if let trigger = MonthlySummaryCache.shared.consumePending() {
            monthlySummaryTrigger = trigger
            showingMonthlySummary = true
        }
    }
    
    private func updateExpiringCoupons() {
        expiringCoupons = coupons.filter { coupon in
            !coupon.isForSale && 
            !coupon.isExpired && 
            !coupon.isFullyUsed && 
            coupon.status == "פעיל" &&
            coupon.isExpiringInWeek
        }
    }
}

// MARK: - Company Logo Card (Website Style)
struct CompanyLogoCard: View {
    let companyName: String
    let companies: [Company]
    let couponCount: Int
    
    init(companyName: String, companies: [Company] = [], couponCount: Int = 0) {
        self.companyName = companyName
        self.companies = companies
        self.couponCount = couponCount
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Company logo (larger, centered)
            logoView
            
            // Company name
            Text(companyName)
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            // Coupon count
            Text("\(couponCount) קופונים פעילים")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var logoView: some View {
        Group {
            if let company = companies.first(where: { $0.name.lowercased() == companyName.lowercased() }) {
                // Show actual company logo
                AsyncImage(url: companyImageURL(for: company)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } placeholder: {
                    // Fallback to letter circle while loading
                    letterCircle
                }
            } else {
                // No company data available, show letter circle
                letterCircle
            }
        }
    }
    
    private var letterCircle: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [getCompanyColor(for: companyName).opacity(0.8), getCompanyColor(for: companyName)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
            
            Text(getDisplayLetter(for: companyName))
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(.white)
        }
    }
    
    private func getCompanyColor(for company: String) -> Color {
        let companyLower = company.lowercased()
        
        switch companyLower {
        case "dream card": return .purple
        case "carrefour": return .red
        case "buyme": return .orange
        case "laline": return .pink
        case "freefit": return .green
        case "fox home": return Color.appBlue
        case "בנזיקט", "benzakt": return .indigo
        case "xtra": return .cyan
        case "power gift": return .yellow
        case "goodpharm": return .mint
        default: return Color.appBlue
        }
    }
    
    private func companyImageURL(for company: Company) -> URL? {
        let baseURL = "https://www.couponmasteril.com/static/"
        return URL(string: baseURL + company.imagePath)
    }
    
    // Get the appropriate display letter for each company
    private func getDisplayLetter(for company: String) -> String {
        let companyLower = company.lowercased()
        
        // Map specific companies to their preferred letters
        switch companyLower {
        case "dream card":
            return "D"
        case "carrefour":
            return "C"
        case "buyme":
            return "B"
        case "laline":
            return "L"
        case "freefit":
            return "F"
        case "fox home":
            return "F"
        case "בנזיקט", "benzakt":
            return "ב"
        case "xtra":
            return "X"
        case "power gift":
            return "P"
        case "ניצת הדזובדן":
            return "נ"
        case "מנה ספוריג", "mana sports":
            return "מ"
        default:
            // For other companies, use the first letter
            return String(company.prefix(1)).uppercased()
        }
    }
}

// MARK: - Company Coupons Screen (MODERN DESIGN - WITH WHITE BACKGROUND AND RTL)
struct CompanyCouponsView: View {
    let companyName: String
    let coupons: [Coupon]
    let user: User
    let companies: [Company]
    let onUpdate: () -> Void
    
    @StateObject private var couponAPI = CouponAPIClient()
    @State private var sortMode: CompanySortMode = .expiration
    @State private var showOrderingView: Bool = false

    enum CompanySortMode: String, CaseIterable {
        case expiration
        case remainingValue
        case value
        case dateAdded
        case manual

        var displayName: String {
            switch self {
            case .expiration: return "תוקף (קרוב קודם)"
            case .remainingValue: return "ערך נותר (גבוה קודם)"
            case .value: return "ערך (גבוה קודם)"
            case .dateAdded: return "תאריך הוספה (חדש קודם)"
            case .manual: return "לפי סדר ידני"
            }
        }
    }
    
    // Computed property for sorted coupons
    private var sortedCoupons: [Coupon] {
        let filteredCoupons = coupons.filter { !$0.isForSale }

        switch sortMode {
        case .manual:
            // Sort by company_display_order (nulls last), then fallback by expiration, then remaining value
            return filteredCoupons.sorted { a, b in
                let aOrder = a.companyDisplayOrder ?? Int.max
                let bOrder = b.companyDisplayOrder ?? Int.max
                if aOrder != bOrder { return aOrder < bOrder }
                // fallback if equal or nil
                if let exp1 = a.expirationDate, let exp2 = b.expirationDate, exp1 != exp2 { return exp1 < exp2 }
                return a.remainingValue > b.remainingValue
            }
        case .remainingValue:
            return filteredCoupons.sorted { lhs, rhs in
                if lhs.remainingValue != rhs.remainingValue { return lhs.remainingValue > rhs.remainingValue }
                return (lhs.expirationDate ?? .distantFuture) < (rhs.expirationDate ?? .distantFuture)
            }
        case .value:
            return filteredCoupons.sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return (lhs.expirationDate ?? .distantFuture) < (rhs.expirationDate ?? .distantFuture)
            }
        case .dateAdded:
            return filteredCoupons.sorted { lhs, rhs in
                return lhs.dateAdded > rhs.dateAdded
            }
        case .expiration:
            return filteredCoupons.sorted { coupon1, coupon2 in
                if let exp1 = coupon1.expirationDate, let exp2 = coupon2.expirationDate {
                    if exp1 != exp2 { return exp1 < exp2 }
                } else if coupon1.expirationDate != nil {
                    return true
                } else if coupon2.expirationDate != nil {
                    return false
                }
                return coupon1.remainingValue > coupon2.remainingValue
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if coupons.isEmpty {
                    Text("אין קופונים לחברה זו")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(sortedCoupons) { coupon in
                            NavigationLink(destination: CouponDetailView(coupon: coupon, user: user, companies: companies, onUpdate: onUpdate)) {
                                ModernCouponCard(coupon: coupon, companies: companies)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(20)
        }
        #if targetEnvironment(simulator)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .background(Color(.systemGroupedBackground))
        .navigationTitle(companyName)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft) // force RTL for this screen
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Sort options
                    Button(action: { sortMode = .expiration }) { Label(CompanySortMode.expiration.displayName, systemImage: "calendar") }
                    Button(action: { sortMode = .remainingValue }) { Label(CompanySortMode.remainingValue.displayName, systemImage: "banknote") }
                    Button(action: { sortMode = .value }) { Label(CompanySortMode.value.displayName, systemImage: "dollarsign.circle") }
                    // Use a widely supported symbol to avoid SF Symbols errors on older OS versions
                    Button(action: { sortMode = .dateAdded }) { Label(CompanySortMode.dateAdded.displayName, systemImage: "calendar.badge.plus") }
                    Divider()
                    Button(action: { sortMode = .manual }) { Label(CompanySortMode.manual.displayName, systemImage: "list.number") }
                    Button("סידור ידני…", action: { showOrderingView = true })
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
        .onAppear {
            // Update last_company_view timestamp for all coupons of this company
            couponAPI.updateLastCompanyView(for: companyName, userId: user.id) { result in
                switch result {
                case .success:
                    print("✅ Updated last_company_view for \(companyName)")
                case .failure(let error):
                    print("❌ Failed to update last_company_view for \(companyName): \(error)")
                }
            }
            // Load saved sort preference for this company
            loadSavedSortPreference()
        }
        .onChange(of: sortMode) {
            saveSortPreference()
        }
        .sheet(isPresented: $showOrderingView) {
            CompanyCouponsOrderingView(
                companyName: companyName,
                user: user,
                coupons: coupons.filter { !$0.isForSale },
                companies: companies,
                onDone: {
                    showOrderingView = false
                    // After manual ordering, default to manual sort for this company and persist
                    sortMode = .manual
                    saveSortPreference()
                    onUpdate()
                }
            )
        }
    }
}

// MARK: - Sort preference persistence (per company)
extension CompanyCouponsView {
    private func preferenceKey() -> String {
        return "CompanySortMode_\(companyName.lowercased())"
    }

    private func loadSavedSortPreference() {
        let key = preferenceKey()
        if let raw = UserDefaults.standard.string(forKey: key),
           let mode = CompanySortMode(rawValue: raw) {
            sortMode = mode
        }
    }

    private func saveSortPreference() {
        let key = preferenceKey()
        UserDefaults.standard.set(sortMode.rawValue, forKey: key)
    }
}

// MARK: - Modern Coupon Card (DYNAMIC BACKGROUND, RTL LAYOUT)
struct ModernCouponCard: View {
    let coupon: Coupon
    let companies: [Company]
    @Environment(\.colorScheme) private var colorScheme
    
    private var company: Company? {
        companies.first { $0.name.lowercased() == coupon.company.lowercased() }
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            HStack(spacing: 16) {
                // Arrow indicator (on the left)
                VStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    Spacer()
                }
                
                // Content (RTL aligned)
                VStack(alignment: .trailing, spacing: 8) {
                    // Status badge
                    HStack {
                        HStack(spacing: 6) {
                            Text("פעיל - אהבתי")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(12)
                        Spacer()
                    }
                    
                    // Company name + special message indicator
                    HStack(spacing: 6) {
                        Text(coupon.company)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)

                        if let msg = coupon.specialMessage, !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12, weight: .bold))
                                .accessibilityLabel("יש הודעה חשובה")
                        }

                        Spacer()
                    }
                    
                    // Coupon code - large and prominent, centered
                    HStack {
                        Spacer()
                        Text(coupon.decryptedCode)
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(Color.appBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appBlue.opacity(0.1))
                            .cornerRadius(8)
                        Spacer()
                    }
                    
                    // Description - small text with truncation, right-to-left aligned
                    if let description = coupon.decryptedDescription, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                
                // Company logo (on the right)
                VStack {
                    if let company = company {
                        AsyncImage(url: companyImageURL(for: company)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 45, height: 45)
                        } placeholder: {
                            companyLetterCircle
                        }
                    } else {
                        companyLetterCircle
                    }
                }
                .frame(width: 55, height: 55)
            }
            .padding(20)
            
            // Bottom section with remaining value and expiration
            HStack {
                // Value display (on the left)
                VStack(alignment: .leading, spacing: 2) {
                    if coupon.isOneTime {
                        let truncatedGoal = truncateText(coupon.decryptedDescription ?? "קופון חד פעמי", maxLength: 25)
                        Text("מטרה: \(truncatedGoal)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.orange)
                    } else {
                        Text("נותר: ₪\(Int(coupon.remainingValue))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // Expiration date (on the right)
                if let expirationDate = coupon.expirationDate {
                    HStack(spacing: 4) {
                        Text("תוקף עד: \(formatDate(expirationDate))")
                            .font(.system(size: 12))
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var companyLetterCircle: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.appBlue.opacity(0.8), Color.purple.opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 45, height: 45)
            
            Text(getDisplayLetter(for: coupon.company))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func companyImageURL(for company: Company) -> URL? {
        let baseURL = "https://www.couponmasteril.com/static/"
        return URL(string: baseURL + company.imagePath)
    }
    
    private func getDisplayLetter(for company: String) -> String {
        let companyLower = company.lowercased()
        
        switch companyLower {
        case "dream card": return "D"
        case "carrefour": return "C"
        case "buyme": return "B"
        case "laline": return "L"
        case "freefit": return "F"
        case "fox home": return "F"
        case "בנזיקט", "benzakt": return "ב"
        case "xtra": return "X"
        case "power gift": return "P"
        case "ניצת הדזובדן": return "נ"
        case "מנה ספוריג", "mana sports": return "מ"
        default:
            return String(company.prefix(1)).uppercased()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "he")
        return formatter.string(from: date)
    }
    
    private func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        } else {
            let truncated = String(text.prefix(maxLength))
            return truncated + "..."
        }
    }
}

// MARK: - Filter Chip (NO CHANGE)
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.primary.opacity(0.2) : Color.gray.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.appBlue : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

// MARK: - Action Button Component (Website Style)
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(color)
            .cornerRadius(12)
        }
    }
}

#Preview {
    CouponsListView(
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
        onLogout: nil
    )
}
