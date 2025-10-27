//
//  WidgetCouponsOrderingView.swift
//  CouponManagerApp
//
//  מסך ניהול ואסדר קופונים להצגה בווידג'ט
//

import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct WidgetCouponsOrderingView: View {
    let user: User
    let onUpdate: () -> Void
    
    @StateObject private var couponAPI = CouponAPIClient()
    @State private var allCoupons: [Coupon] = []
    @State private var allCompanies: [Company] = []
    @State private var isLoading = false
    @State private var showingCouponDetail: Coupon?
    // Force rebuild of the ordered list when order changes to reflect UI immediately
    @State private var orderingVersion: Int = 0
    @Environment(\.presentationMode) var presentationMode
    
    private var activeCoupons: [Coupon] {
        // Show active coupons (including one-time). Exclude used and expired.
        allCoupons.filter { coupon in
            coupon.status == "פעיל" && !coupon.isExpired && (!coupon.isFullyUsed || coupon.isOneTime)
        }
    }
    
    private var widgetCoupons: [Coupon] {
        activeCoupons
            .filter { $0.showInWidget == true }
            .sorted { coupon1, coupon2 in
                let order1 = coupon1.widgetDisplayOrder ?? 999
                let order2 = coupon2.widgetDisplayOrder ?? 999
                return order1 < order2
            }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection
                            
                            if !widgetCoupons.isEmpty {
                                orderedCouponsSection
                            }
                            
                            availableCouponsSection
                        }
                        .padding()
                        .multilineTextAlignment(.leading)
                    }
                }
            }
            .navigationTitle("ניהול סדר קופונים בווידג'ט")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("סגור") {
                        // Force final widget reload before closing
                        reloadWidget()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .onAppear {
                loadCoupons()
            }
            .sheet(item: $showingCouponDetail) { coupon in
                CouponDetailView(coupon: coupon, user: user, companies: allCompanies) {
                    loadCoupons()
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title2)
                    .foregroundColor(Color.appBlue)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ניהול קופונים בווידג'ט")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("בחר עד 4 קופונים וסדר את הופעתם")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(widgetCoupons.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.appBlue)
                    Text("נבחרו")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("/")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack {
                    Text("4")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text("מקסימום")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.appBlue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Ordered Coupons Section
    private var orderedCouponsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .trailing, spacing: 4) {
                Text("קופונים נבחרים (לפי סדר הצגה)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("גרור קופון או השתמש בחצים")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            VStack(spacing: 8) {
                ForEach(Array(widgetCoupons.enumerated()), id: \.element.id) { index, coupon in
                    OrderedCouponRow(
                        coupon: coupon,
                        companies: allCompanies,
                        position: index + 1,
                        canMoveUp: index > 0,
                        canMoveDown: index < widgetCoupons.count - 1,
                        onTap: { showingCouponDetail = coupon },
                        onRemove: { toggleCouponInWidget(coupon) },
                        onMoveUp: { moveItem(from: index, to: index - 1) },
                        onMoveDown: { moveItem(from: index, to: index + 1) },
                        onMoveToTop: { moveItemToTop(index: index) },
                        onMoveToBottom: { moveItemToBottom(index: index) }
                    )
                    // Enable drag-and-drop reordering within the selected list
                    .onDrag {
                        // Provide the coupon id as text for local drag
                        return NSItemProvider(object: NSString(string: String(coupon.id)))
                    }
                    .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                        guard let provider = providers.first else { return false }
                        // Load the dragged coupon id and perform move
                        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                            if let strObj = object as? NSString, let sourceId = Int(strObj as String) {
                                DispatchQueue.main.async {
                                    if let sourceIndex = self.widgetCoupons.firstIndex(where: { $0.id == sourceId }) {
                                        let destinationIndex = index
                                        if sourceIndex != destinationIndex {
                                            self.moveItem(from: sourceIndex, to: destinationIndex)
                                        }
                                    }
                                }
                                // Perform move asynchronously; return value is handled below
                            }
                        }
                        // Return true to accept the drop; the actual move is handled asynchronously above
                        return true
                    }
                }
            }
            // Recreate the list view hierarchy when version changes (fixes SwiftUI stale layout in ScrollView)
            .id(orderingVersion)
            
            if widgetCoupons.count >= 2 {
                Text("ווידג'ט בינוני יציג את קופונים 1-2")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("ווידג'ט גדול יציג את כל 4 הקופונים")
                    .font(.caption)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - Available Coupons Section
    private var availableCouponsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("קופונים זמינים")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
                    AvailableCouponRow(
                        coupon: coupon,
                        companies: allCompanies,
                        onAdd: {
                            if widgetCoupons.count < 4 {
                                toggleCouponInWidget(coupon)
                            }
                        },
                        onTap: {
                            showingCouponDetail = coupon
                        },
                        canAdd: widgetCoupons.count < 4
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func loadCoupons() {
        isLoading = true
        
        let group = DispatchGroup()
        
        group.enter()
        couponAPI.fetchAllUserCoupons(userId: user.id) { result in
            switch result {
            case .success(let coupons):
                let usedCouponsToUpdate = coupons.filter {
                    ($0.showInWidget ?? false) && ($0.status == "נוצל" || $0.isFullyUsed)
                }
                
                if usedCouponsToUpdate.isEmpty {
                    DispatchQueue.main.async {
                        self.allCoupons = coupons
                        group.leave()
                    }
                } else {
                    print("ℹ️ Found \(usedCouponsToUpdate.count) used coupons to remove from widget.")
                    let updateGroup = DispatchGroup()
                    for coupon in usedCouponsToUpdate {
                        updateGroup.enter()
                        let updateData: [String: Any] = ["show_in_widget": false, "widget_display_order": NSNull()]
                        self.couponAPI.updateCoupon(couponId: coupon.id, data: updateData) { updateResult in
                            if case .failure(let error) = updateResult {
                                print("❌ Failed to update used coupon \(coupon.id): \(error)")
                            }
                            updateGroup.leave()
                        }
                    }
                    
                    updateGroup.notify(queue: .main) {
                        // Re-fetch all coupons after the updates to get the latest state
                        self.couponAPI.fetchAllUserCoupons(userId: self.user.id) { finalResult in
                            switch finalResult {
                            case .success(let finalCoupons):
                                self.allCoupons = finalCoupons
                            case .failure(let error):
                                print("Failed to re-fetch coupons after update: \(error)")
                                self.allCoupons = coupons // Fallback to original list
                            }
                            group.leave()
                        }
                    }
                }

            case .failure(let error):
                print("Failed to load coupons: \(error)")
                group.leave()
            }
        }
        
        group.enter()
        couponAPI.fetchCompanies { result in
            switch result {
            case .success(let companies):
                self.allCompanies = companies
            case .failure(let error):
                print("Failed to load companies: \(error)")
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    private func toggleCouponInWidget(_ coupon: Coupon) {
        let wasInWidget = (coupon.showInWidget ?? false)
        let newValue = !wasInWidget

        // Respect max 4 selection
        if newValue && widgetCoupons.count >= 4 { return }

        // Compute next order by max existing, not just count
        let maxOrder = widgetCoupons.compactMap { $0.widgetDisplayOrder }.max() ?? 0
        let newOrder: Int? = newValue ? (maxOrder + 1) : nil

        // Prepare server payload (nullify order when removing)
        var updateData: [String: Any] = ["show_in_widget": newValue]
        updateData["widget_display_order"] = newOrder ?? NSNull()

        // Optimistic local update (ensure @State reassign for UI refresh)
        if let index = allCoupons.firstIndex(where: { $0.id == coupon.id }) {
            var local = allCoupons
            var updated = local[index]
            updated.showInWidget = newValue
            updated.widgetDisplayOrder = newOrder
            local[index] = updated

            // Keep sequential orders locally for stable UI
            if newValue {
                var seq = widgetCoupons + [updated]
                seq = seq.sorted { ($0.widgetDisplayOrder ?? 999) < ($1.widgetDisplayOrder ?? 999) }
                for (i, item) in seq.enumerated() {
                    if let idx = local.firstIndex(where: { $0.id == item.id }) {
                        local[idx].widgetDisplayOrder = i + 1
                    }
                }
            }
            withAnimation {
                allCoupons = local
                orderingVersion &+= 1
            }
        }

        // Persist to server
        couponAPI.updateCoupon(couponId: coupon.id, data: updateData) { result in
            switch result {
            case .success:
                saveToSharedContainer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { reloadWidget() }
                onUpdate()
                // Ensure latest state from server (defensive)
                DispatchQueue.main.async { loadCoupons() }
            case .failure(let error):
                print("❌ Failed to update show_in_widget: \(error)")
                // Revert on failure
                if let index = allCoupons.firstIndex(where: { $0.id == coupon.id }) {
                    var reverted = allCoupons[index]
                    reverted.showInWidget = wasInWidget
                    allCoupons[index] = reverted
                }
            }
        }
    }
    
    private func moveItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < widgetCoupons.count,
              destinationIndex >= 0, destinationIndex < widgetCoupons.count else {
            return
        }
        
        let sortedCoupons = widgetCoupons
        var updates: [(couponId: Int, order: Int)] = []
        
        // Simple swap logic - just swap the display orders
        let sourceCoupon = sortedCoupons[sourceIndex]
        let destinationCoupon = sortedCoupons[destinationIndex]
        
        let sourceOrder = sourceCoupon.widgetDisplayOrder ?? (sourceIndex + 1)
        let destinationOrder = destinationCoupon.widgetDisplayOrder ?? (destinationIndex + 1)
        
        // Swap the orders
        updates.append((couponId: sourceCoupon.id, order: destinationOrder))
        updates.append((couponId: destinationCoupon.id, order: sourceOrder))
        
        // Optimistic local update for instant UI feedback
        applyLocalOrderUpdates(updates)
        updateCouponOrders(updates: updates)
    }
    
    private func moveItemByDrag(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        
        let destinationIndex = destination > sourceIndex ? destination - 1 : destination
        
        guard sourceIndex != destinationIndex else { return }
        
        let sortedCoupons = widgetCoupons
        var updates: [(couponId: Int, order: Int)] = []
        
        // Get all coupons that need reordering
        var reorderedCoupons = sortedCoupons
        let movedCoupon = reorderedCoupons.remove(at: sourceIndex)
        reorderedCoupons.insert(movedCoupon, at: destinationIndex)
        
        // Update all orders
        for (index, coupon) in reorderedCoupons.enumerated() {
            updates.append((couponId: coupon.id, order: index + 1))
        }
        
        // Optimistic local update for instant UI feedback
        applyLocalOrderUpdates(updates)
        updateCouponOrders(updates: updates)
    }

    private func moveItemToTop(index: Int) {
        guard index > 0 && index < widgetCoupons.count else { return }
        var updates: [(couponId: Int, order: Int)] = []
        let sorted = widgetCoupons
        // Selected item goes to order 1
        updates.append((couponId: sorted[index].id, order: 1))
        // Shift down the ones that were above it
        for i in 0..<index {
            updates.append((couponId: sorted[i].id, order: i + 2))
        }
        // Keep the rest as-is
        for i in (index + 1)..<sorted.count {
            updates.append((couponId: sorted[i].id, order: i + 1))
        }
        // Optimistic local update for instant UI feedback
        applyLocalOrderUpdates(updates)
        updateCouponOrders(updates: updates)
    }

    private func moveItemToBottom(index: Int) {
        guard index >= 0 && index < widgetCoupons.count - 1 else { return }
        var updates: [(couponId: Int, order: Int)] = []
        let sorted = widgetCoupons
        let lastOrder = sorted.count
        // Selected item goes to bottom
        updates.append((couponId: sorted[index].id, order: lastOrder))
        // Shift up the ones that were below it
        for i in (index + 1)..<sorted.count {
            updates.append((couponId: sorted[i].id, order: i))
        }
        // Keep the rest as-is
        for i in 0..<index {
            updates.append((couponId: sorted[i].id, order: i + 1))
        }
        // Optimistic local update for instant UI feedback
        applyLocalOrderUpdates(updates)
        updateCouponOrders(updates: updates)
    }

    private func applyLocalOrderUpdates(_ updates: [(couponId: Int, order: Int)]) {
        var local = allCoupons
        for update in updates {
            if let idx = local.firstIndex(where: { $0.id == update.couponId }) {
                local[idx].widgetDisplayOrder = update.order
            }
        }
        withAnimation {
            allCoupons = local
            orderingVersion &+= 1
        }
    }
    
    private func updateCouponOrders(updates: [(couponId: Int, order: Int)]) {
        let group = DispatchGroup()
        var hasError = false
        
        for update in updates {
            group.enter()
            couponAPI.updateCoupon(couponId: update.couponId, data: ["widget_display_order": update.order]) { result in
                switch result {
                case .success:
                    if let index = allCoupons.firstIndex(where: { $0.id == update.couponId }) {
                        var local = allCoupons
                        local[index].widgetDisplayOrder = update.order
                        DispatchQueue.main.async { withAnimation { allCoupons = local } }
                    }
                case .failure(let error):
                    print("Failed to update order for coupon \(update.couponId): \(error)")
                    hasError = true
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !hasError {
                saveToSharedContainer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    reloadWidget()
                }
                onUpdate()
            }
        }
    }
    
    private func saveToSharedContainer() {
        print("💾 Saving updated coupons to shared container...")
        couponAPI.fetchAllUserCoupons(userId: user.id) { fetchResult in
            if case .success(let updatedCoupons) = fetchResult {
                let widgetCoupons = updatedCoupons.filter { $0.showInWidget == true }
                    .sorted { coupon1, coupon2 in
                        let order1 = coupon1.widgetDisplayOrder ?? 999
                        let order2 = coupon2.widgetDisplayOrder ?? 999
                        return order1 < order2
                    }
                
                print("💾 Widget coupons in order before saving:")
                for (index, coupon) in widgetCoupons.enumerated() {
                    print("   \(index+1). \(coupon.company) (Order: \(coupon.widgetDisplayOrder ?? 999))")
                }
                
                AppGroupManager.shared.saveCouponsToSharedContainer(updatedCoupons)
                print("✅ Updated shared container with new widget coupon order")
                
                // Force clear any widget cache
                DispatchQueue.main.async {
                    if #available(iOS 14.0, *) {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            } else {
                print("❌ Failed to fetch updated coupons for shared container")
            }
        }
    }
    
    private func reloadWidget() {
        if #available(iOS 14.0, *) {
            print("🔄 Reloading widget...")
            WidgetCenter.shared.reloadTimelines(ofKind: "CouponManagerWidget")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

// MARK: - Ordered Coupon Row
struct OrderedCouponRow: View {
    let coupon: Coupon
    let companies: [Company]
    let position: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onMoveToTop: () -> Void
    let onMoveToBottom: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Position number with drag indicator
            ZStack {
                Circle()
                    .fill(Color.appBlue)
                    .frame(width: 40, height: 40)
                
                VStack(spacing: 2) {
                    Text("\(position)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Image(systemName: "line.3.horizontal")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Coupon content
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(coupon.company)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // Coupon code and expiration
                        HStack(spacing: 6) {
                            Text("קוד: \(coupon.decryptedCode)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("תוקף: \(coupon.formattedExpirationDateShort)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            if let expiration = coupon.expirationDate {
                                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
                                if daysLeft <= 7 && daysLeft >= 0 {
                                    Text("\(daysLeft) ימים •")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            Text("נותר ₪\(Int(coupon.remainingValue))")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                    // Logo on the left of the text (RTL-friendly)
                    companyLogoView
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Control buttons
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up")
                            .font(.title3)
                            .foregroundColor(canMoveUp ? Color.appBlue : .gray.opacity(0.3))
                            .frame(width: 30, height: 30)
                    }
                    .disabled(!canMoveUp)
                    
                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .foregroundColor(canMoveDown ? Color.appBlue : .gray.opacity(0.3))
                            .frame(width: 30, height: 30)
                    }
                    .disabled(!canMoveDown)
                }
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .padding()
        .background(Color.appBlue.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            // Make overlay ignore taps so buttons work
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBlue, lineWidth: 2)
                .allowsHitTesting(false)
        )
        .contextMenu {
            if canMoveUp {
                Button("העבר לראש הרשימה", action: onMoveToTop)
            }
            if canMoveDown {
                Button("העבר לסוף הרשימה", action: onMoveToBottom)
            }
            Divider()
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("הסר מהווידג'ט", systemImage: "trash")
            }
        }
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
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    case .failure(_):
                        fallbackLogo
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    @unknown default:
                        fallbackLogo
                    }
                }
            } else {
                fallbackLogo
            }
        }
        .frame(width: 50, height: 50)
    }
    
    private var fallbackLogo: some View {
        ZStack {
            Circle()
                .fill(Color.appBlue.opacity(0.2))
            
            Text(String(coupon.company.prefix(1).uppercased()))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.appBlue)
        }
        .frame(width: 50, height: 50)
    }
    
    private var companyImageURL: URL? {
        if let company = companies.first(where: { $0.name.lowercased() == coupon.company.lowercased() }) {
            let baseURL = "https://www.couponmasteril.com/static/"
            return URL(string: baseURL + company.imagePath)
        }
        return nil
    }
}

// MARK: - Available Coupon Row
struct AvailableCouponRow: View {
    let coupon: Coupon
    let companies: [Company]
    let onAdd: () -> Void
    let onTap: () -> Void
    let canAdd: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(coupon.company)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // Coupon code and expiration
                        HStack(spacing: 6) {
                            Text("קוד: \(coupon.decryptedCode)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("תוקף: \(coupon.formattedExpirationDateShort)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            if let expiration = coupon.expirationDate {
                                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
                                if daysLeft <= 7 && daysLeft >= 0 {
                                    Text("\(daysLeft) ימים •")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            Text("נותר ₪\(Int(coupon.remainingValue))")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                    companyLogoView
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onAdd) {
                Image(systemName: canAdd ? "plus.circle.fill" : "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(canAdd ? Color.appBlue : .orange)
                    .frame(width: 30, height: 30)
            }
            .disabled(!canAdd)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .allowsHitTesting(false)
        )
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
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    case .failure(_):
                        fallbackLogo
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    @unknown default:
                        fallbackLogo
                    }
                }
            } else {
                fallbackLogo
            }
        }
        .frame(width: 50, height: 50)
    }
    
    private var fallbackLogo: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
            
            Text(String(coupon.company.prefix(1).uppercased()))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
        }
        .frame(width: 50, height: 50)
    }
    
    private var companyImageURL: URL? {
        if let company = companies.first(where: { $0.name.lowercased() == coupon.company.lowercased() }) {
            let baseURL = "https://www.couponmasteril.com/static/"
            return URL(string: baseURL + company.imagePath)
        }
        return nil
    }
}


#Preview {
    WidgetCouponsOrderingView(
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
            faceIdEnabled: false,
            pushToken: nil
        ),
        onUpdate: {}
    )
}
