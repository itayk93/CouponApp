//
//  UsageCouponSheet.swift
//  CouponManagerApp
//
//  מסך רישום שימוש בקופון
//

import SwiftUI

struct UsageCouponSheet: View {
    let coupon: Coupon
    let onUsage: (Double, String) -> Void
    
    @State private var usageAmount = ""
    @State private var usageDetails = ""
    @State private var selectedQuickAmount: Double? = nil
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case amount
        case details
    }
    
    private var quickAmounts: [Double] {
        let remaining = coupon.remainingValue
        var amounts: [Double] = []
        
        if remaining >= 10 { amounts.append(10) }
        if remaining >= 20 { amounts.append(20) }
        if remaining >= 50 { amounts.append(50) }
        if remaining >= 100 { amounts.append(100) }
        
        // Add remaining value if it's different from the quick amounts
        if !amounts.contains(remaining) && remaining > 0 {
            amounts.append(remaining)
        }
        
        return amounts.sorted()
    }
    
    private var maxUsage: Double {
        coupon.remainingValue
    }
    
    private var isValidAmount: Bool {
        guard let amount = Double(usageAmount), amount > 0 else { return false }
        return amount <= maxUsage
    }
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        // Make header scrollable so inputs get space when keyboard shows
                        headerSection
                        
                        // Quick Amount Buttons
                        quickAmountSection
                        
                        // Manual Input
                        manualInputSection
                            .id("amountSection")
                        
                        // Usage Details
                        detailsSection
                            .id("detailsSection")
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture { focusedField = nil }
                .onChange(of: focusedField) { _, newVal in
                    // Bring editing field into view
                    withAnimation(.easeInOut) {
                        if newVal == .amount {
                            proxy.scrollTo("amountSection", anchor: .bottom)
                        } else if newVal == .details {
                            proxy.scrollTo("detailsSection", anchor: .bottom)
                        }
                    }
                }
                // Pin the action area above the keyboard/safe area
                .safeAreaInset(edge: .bottom) {
                    bottomActionSection
                        .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("רישום שימוש")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ביטול") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Company logo
            ZStack {
                Circle()
                    .fill(Color.appBlue.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Text(String(coupon.company.prefix(2)))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.appBlue)
            }
            
            // Company name
            Text(coupon.company)
                .font(.headline)
                .fontWeight(.semibold)
            
            // Available amount
            VStack(spacing: 4) {
                Text("זמין לשימוש")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("₪\(Int(maxUsage))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Quick Amount Section
    private var quickAmountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("סכומים מהירים")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(quickAmounts, id: \.self) { amount in
                    QuickAmountButton(
                        amount: amount,
                        isSelected: selectedQuickAmount == amount,
                        isRemaining: amount == coupon.remainingValue
                    ) {
                        selectedQuickAmount = amount
                        usageAmount = String(Int(amount))
                    }
                }
            }
        }
    }
    
    // MARK: - Manual Input Section
    private var manualInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("סכום מותאם אישית")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                TextField("0", text: $usageAmount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .amount)
                    .onChange(of: usageAmount) { _, _ in
                        selectedQuickAmount = nil
                    }
                
                Text("₪")
                    .foregroundColor(.secondary)
            }
            
            if !usageAmount.isEmpty && !isValidAmount {
                if let amount = Double(usageAmount), amount > maxUsage {
                    Text("הסכום גדול מהזמין (₪\(Int(maxUsage)))")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("יש להזין סכום תקין")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("פרטי השימוש (אופציונלי)")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("לדוגמה: קניות בסופר, מסעדה, וכו'", text: $usageDetails, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .details)
                .lineLimit(3, reservesSpace: true)
        }
    }
    
    // MARK: - Bottom Action Section
    private var bottomActionSection: some View {
        VStack(spacing: 16) {
            if let amount = Double(usageAmount), isValidAmount {
                VStack(spacing: 8) {
                    HStack {
                        Text("סכום לשימוש:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("₪\(Int(amount))")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("יישאר:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("₪\(Int(maxUsage - amount))")
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Button(action: recordUsage) {
                Text("רשום שימוש")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidAmount ? Color.appBlue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!isValidAmount)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    private func recordUsage() {
        guard let amount = Double(usageAmount), isValidAmount else { return }
        focusedField = nil
        onUsage(amount, usageDetails)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Quick Amount Button
struct QuickAmountButton: View {
    let amount: Double
    let isSelected: Bool
    let isRemaining: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("₪\(Int(amount))")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if isRemaining {
                    Text("הכל")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .opacity(0.8)
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.appBlue : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.appBlue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

#Preview {
    UsageCouponSheet(
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
        onUsage: { amount, details in
            print("Used: ₪\(amount), Details: \(details)")
        }
    )
}
