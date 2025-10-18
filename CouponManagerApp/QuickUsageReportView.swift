//
//  QuickUsageReportView.swift
//  CouponManagerApp
//
//  Quick usage report dashboard matching website design
//

import SwiftUI
import Combine
import UIKit

// MARK: - Quick Usage AI Models (file-scoped)
fileprivate struct ReviewRow: Identifiable {
    let id = UUID()
    let company: String
    let options: [Coupon]
    var selectedCouponId: Int
    var amountText: String
    var checked: Bool
    var confidence: Double
    var matchedText: String?
}

fileprivate struct QuickAISuggestion: Identifiable {
    let id = UUID()
    let couponId: String
    let confidence: Double
    let matchedText: String?
    let rationale: String?
    let usedAmount: Double?
}

fileprivate struct QuickActiveCouponDTO: Codable {
    let id: String
    let title: String
    let code: String?
    let merchant: String?
}

fileprivate final class QuickAIUsageService {
    private let session: URLSession
    private let model = "gpt-4o-mini"

    init(session: URLSession = .shared) { self.session = session }

    private func apiKey() -> String? { Config.openAIAPIKey }

    private struct OpenAIResponse: Codable { struct Choice: Codable { struct Message: Codable { let content: String }; let message: Message }; let choices: [Choice] }
    private struct AIVendorResponse: Codable { struct Vendor: Codable { let name: String; let amount: Double?; let matchedText: String?; let rationale: String? }; let vendors: [Vendor] }

    func analyzeUsedCoupons(from text: String, activeCoupons: [QuickActiveCouponDTO]) async throws -> [QuickAISuggestion] {
        enum LocalError: Error { case missingKey, invalidResponse, decoding, apiError(String) }
        guard let apiKey = apiKey(), !apiKey.isEmpty else { throw LocalError.missingKey }

        let companies = Array(Set(activeCoupons.map { ($0.merchant ?? $0.title).trimmingCharacters(in: .whitespacesAndNewlines) })).sorted()

        let systemPrompt = """
You are an expert at extracting structured data from Hebrew text about coupon usage.
From the user's text, identify vendors and the amount spent.
- ONLY match vendors from the provided list: \(companies.joined(separator: ", ")).
- Be flexible with names (e.g., \"שופרסל\" vs \"Shufersal\").
- Extract numeric amounts (e.g., \"50 שח\", \"ILS 50\", \"fifty\"). If no amount is clear for a vendor, use null.
- Your entire output MUST be a valid JSON object.

Example:
User: \"השתמשתי ב-50 שקל בשופרסל וגם קניתי בגוד פארם\"
Vendors: [\"Shufersal\", \"Good Pharm\"]
Output:
{
  \"vendors\": [
    { \"name\": \"Shufersal\", \"amount\": 50.0, \"matchedText\": \"50 שקל בשופרסל\", \"rationale\": \"Clear mention of amount and vendor.\" },
    { \"name\": \"Good Pharm\", \"amount\": null, \"matchedText\": \"גוד פארם\", \"rationale\": \"Vendor mentioned, but no specific amount.\" }
  ]
}
"""

        let userPrompt = "Text to analyze: \"\(text)\""

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": ["type": "json_object"]
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let (respData, resp) = try await session.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let errorBody = String(data: respData, encoding: .utf8) ?? "No details"
            throw LocalError.apiError("Code \( (resp as? HTTPURLResponse)?.statusCode ?? 0): \(errorBody)")
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: respData)
        guard let content = decoded.choices.first?.message.content.data(using: .utf8) else { throw LocalError.decoding }
        let vendorResult = try JSONDecoder().decode(AIVendorResponse.self, from: content)

        func normalize(_ s: String) -> String {
            return s.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
        }

        let couponsByCompany = Dictionary(grouping: activeCoupons, by: { normalize($0.merchant ?? $0.title) })

        var out: [QuickAISuggestion] = []
        for v in vendorResult.vendors {
            let key = normalize(v.name)
            if let matches = couponsByCompany[key] {
                for c in matches {
                    out.append(QuickAISuggestion(
                        couponId: c.id,
                        confidence: 0.85,
                        matchedText: v.matchedText,
                        rationale: v.rationale,
                        usedAmount: v.amount
                    ))
                }
            }
        }
        return out
    }
}

struct QuickUsageReportView: View {
    let user: User
    let coupons: [Coupon]
    let allCompanies: [Company] // Expect all companies to be passed in
    let onUsageReported: () -> Void
    
    @StateObject private var couponAPI = CouponAPIClient()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    
    @State private var inputText: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var errorMessage: String?
    
    @State private var reviewRows: [ReviewRow] = []
    @State private var inReviewMode: Bool = false
    
    // To control keyboard focus
    @FocusState private var focusedField: UUID?
    @FocusState private var isMainInputFocused: Bool
    
    private var activeCoupons: [Coupon] {
        coupons.filter { !$0.isForSale && $0.status == "פעיל" && !$0.isExpired }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("דיווח מהיר על שימוש")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("כתוב בקצרה מה שילמת ועל איזה קופון. המערכת תזהה את החברה והסכום ותציע לך לאשר.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $inputText)
                        .frame(minHeight: 140)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        .cornerRadius(10)
                        .focused($isMainInputFocused)
                    
                    Button {
                        Task {
                            if inReviewMode {
                                await submitSelectedReports()
                            } else {
                                await analyzeToReview()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: isAnalyzing ? "hourglass" : (inReviewMode ? "checkmark.seal.fill" : "wand.and.stars"))
                            Text(isAnalyzing ? "מעבד..." : (inReviewMode ? "אישור ושליחה" : "שלח לזיהוי"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
                    
                    if isAnalyzing { ProgressView().padding(.top, 4) }
                    if let err = errorMessage { Text(err).foregroundColor(.red).font(.footnote) }
                    
                    if inReviewMode {
                        Divider().padding(.vertical, 8)
                        
                        HStack {
                            Text("אשר שימושים שאותרו")
                                .font(.headline)
                            Spacer()
                            Button("בטל הכל") {
                                reviewRows.indices.forEach { reviewRows[$0].checked = false }
                            }
                            .font(.caption)
                        }

                        ForEach($reviewRows) { $row in
                            ReviewCardView(
                                row: $row,
                                allCompanies: allCompanies,
                                focusedField: $focusedField,
                                onApproveSwipe: { couponId, usedAmount in
                                    // Submit this single row immediately when swiped left to approve
                                    Task { await submitSingleReport(rowId: row.id, couponId: couponId, usedAmount: usedAmount) }
                                }
                            )
                                .padding(.vertical, 6)
                        }
                    }
                    
                    Spacer(minLength: 60)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("דיווח מהיר")
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("סגור") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("סגור מקלדת") {
                        isMainInputFocused = false
                        focusedField = nil
                    }
                }
            }
            .onTapGesture {
                // Tap outside to dismiss any focused input
                isMainInputFocused = false
                focusedField = nil
            }
        }
    }
    
    // MARK: - Data Flow
    
    private func analyzeToReview() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        await MainActor.run {
            self.isAnalyzing = true
            self.errorMessage = nil
            self.reviewRows = []
            self.inReviewMode = false
        }

        let dto: [QuickActiveCouponDTO] = activeCoupons.map {
            QuickActiveCouponDTO(id: String($0.id), title: $0.decryptedDescription ?? $0.company, code: $0.decryptedCode, merchant: $0.company)
        }

        do {
            let service = QuickAIUsageService()
            let suggestions = try await service.analyzeUsedCoupons(from: text, activeCoupons: dto)
            
            await MainActor.run {
                self.reviewRows = buildReviewRows(from: suggestions)
                self.inReviewMode = !self.reviewRows.isEmpty
                if self.reviewRows.isEmpty {
                    self.errorMessage = "לא זוהו קופונים מהטקסט. נסה לפרט יותר."
                }
            }
        } catch {
            await MainActor.run { self.errorMessage = "שגיאת תקשורת עם שירות הזיהוי: \(error.localizedDescription)" }
        }

        await MainActor.run {
            self.isAnalyzing = false
            // Dismiss keyboard when entering review mode
            if self.inReviewMode {
                self.isMainInputFocused = false
                self.focusedField = nil
            }
        }
    }

    private func buildReviewRows(from suggestions: [QuickAISuggestion]) -> [ReviewRow] {
        let validSuggestions = suggestions.compactMap { suggestion -> (coupon: Coupon, suggestion: QuickAISuggestion)? in
            guard let couponId = Int(suggestion.couponId),
                  let coupon = activeCoupons.first(where: { $0.id == couponId }) else {
                return nil
            }
            return (coupon, suggestion)
        }
        
        let groups = Dictionary(grouping: validSuggestions, by: { $0.coupon.company })
        
        return groups.compactMap { company, items -> ReviewRow? in
            guard let firstItem = items.first else { return nil }
            
            let options = activeCoupons.filter { $0.company.caseInsensitiveCompare(company) == .orderedSame }
            guard !options.isEmpty else { return nil }
            
            let initialAmount = firstItem.suggestion.usedAmount.map { numberString($0, fractionalDigits: 2) } ?? ""
            
            // Sort options by lowest remaining value, then nearest expiration
            let optionsSorted = options.sorted { lhs, rhs in
                let lhsRem = lhs.remainingValue
                let rhsRem = rhs.remainingValue
                if abs(lhsRem - rhsRem) > 0.0001 {
                    return lhsRem < rhsRem
                }
                let lExp = lhs.expirationDate ?? .distantFuture
                let rExp = rhs.expirationDate ?? .distantFuture
                return lExp < rExp
            }

            return ReviewRow(
                company: company,
                options: optionsSorted,
                selectedCouponId: optionsSorted.first?.id ?? firstItem.coupon.id,
                amountText: initialAmount,
                checked: true,
                confidence: firstItem.suggestion.confidence,
                matchedText: firstItem.suggestion.matchedText
            )
        }
    }

    private func submitSelectedReports() async {
        let text = "דיווח מהיר: \(inputText)"
        await MainActor.run { self.isAnalyzing = true; self.errorMessage = nil }
        
        var successCount = 0
        var errorCount = 0
        
        for row in reviewRows where row.checked {
            guard let usedAmount = parseAmount(row.amountText), usedAmount > 0 else { continue }
            
            do {
                try await reportUsage(for: row.selectedCouponId, usedAmount: usedAmount, details: text)
                successCount += 1
            } catch {
                errorCount += 1
            }
        }
        
        await MainActor.run {
            self.isAnalyzing = false
            if errorCount > 0 {
                self.errorMessage = "אירעה שגיאה בעדכון של \(errorCount) שימושים."
            } else if successCount > 0 {
                self.onUsageReported() // Trigger refresh
                self.presentationMode.wrappedValue.dismiss() // Close on success
            } else {
                self.errorMessage = "לא נבחרו דיווחים או שהסכום היה 0."
            }
        }
    }

    // Submit a single review row (used by swipe-left approve)
    private func submitSingleReport(rowId: UUID, couponId: Int, usedAmount: Double) async {
        let details = "דיווח מהיר: \(inputText)"
        await MainActor.run { self.isAnalyzing = true; self.errorMessage = nil }
        do {
            try await reportUsage(for: couponId, usedAmount: usedAmount, details: details)
            await MainActor.run {
                // Remove the row that was just approved
                if let idx = self.reviewRows.firstIndex(where: { $0.id == rowId }) {
                    withAnimation { self.reviewRows.remove(at: idx) }
                }
                // If no more rows left, refresh and close
                if self.reviewRows.isEmpty {
                    self.onUsageReported()
                    self.presentationMode.wrappedValue.dismiss()
                }
                self.isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                self.isAnalyzing = false
                self.errorMessage = "אירעה שגיאה בעת עדכון השימוש: \(error.localizedDescription)"
            }
        }
    }

    private func reportUsage(for id: Int, usedAmount: Double, details: String) async throws {
        let request = CouponUsageRequest(usedAmount: usedAmount, action: "use", details: details)
        return try await withCheckedThrowingContinuation { continuation in
            couponAPI.updateCouponUsage(couponId: id, usageRequest: request) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func parseAmount(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "₪", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }

    private func numberString(_ d: Double, fractionalDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionalDigits
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: d)) ?? "\(d)"
    }
}

// MARK: - Review Card Subview
fileprivate struct ReviewCardView: View {
    @Binding private var row: ReviewRow
    private let allCompanies: [Company]
    @FocusState.Binding private var focusedField: UUID?
    private let onApproveSwipe: (Int, Double) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var showCouponPicker: Bool = false
    @State private var swipeOffset: CGFloat = 0
    private let swipeThreshold: CGFloat = 80
    @State private var didCrossLeftThreshold: Bool = false
    @State private var didCrossRightThreshold: Bool = false
    
    // Explicit initializer to expose memberwise init despite private properties
    init(
        row: Binding<ReviewRow>,
        allCompanies: [Company],
        focusedField: FocusState<UUID?>.Binding,
        onApproveSwipe: @escaping (Int, Double) -> Void
    ) {
        self._row = row
        self.allCompanies = allCompanies
        self._focusedField = focusedField
        self.onApproveSwipe = onApproveSwipe
    }
    
    private var selectedCoupon: Coupon? {
        row.options.first { $0.id == row.selectedCouponId }
    }
    
    var body: some View {
        ZStack {
            // Colored background that fades in like Gmail
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    (swipeOffset > 0 ? Color.red : (swipeOffset < 0 ? Color.green : Color.clear))
                        .opacity(min(abs(swipeOffset) / swipeThreshold, 1) * 0.15)
                )
                .allowsHitTesting(false)

            // Background swipe indicators (stay put while card moves)
            HStack {
                // Right swipe (cancel)
                Label("בטל", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title3)
                    .opacity(max(0, min(swipeOffset / swipeThreshold, 1)))
                    .padding(.leading, 16)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                Spacer(minLength: 0)
                // Left swipe (approve)
                Label("אשר", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                    .opacity(max(0, min(-swipeOffset / swipeThreshold, 1)))
                    .padding(.trailing, 16)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 6)
            .allowsHitTesting(false)

            VStack(spacing: 12) {
            // Header with checkbox and company name
            HStack(alignment: .center) {
                Image(systemName: row.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(row.checked ? .green : .gray.opacity(0.7))
                    .onTapGesture { row.checked.toggle() }
                
                companyLogo(for: row.company)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.trailing, 4)
                
                Text(row.company)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let matched = row.matchedText, !matched.isEmpty {
                    Text("\"\(matched)\"")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Tappable code opens a full list of same-company coupons
            Button(action: { showCouponPicker = true }) {
                pickerLabel
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .sheet(isPresented: $showCouponPicker) {
                NavigationView {
                    List(row.options, id: \.id) { c in
                        HStack(spacing: 12) {
                            // Company logo (match implementation from CouponDetailView)
                            companyLogo(for: row.company)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.decryptedCode)
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                Text("נותר: ₪\(numberString(c.remainingValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Expiration date on the trailing side
                            let exp = c.formattedExpirationDate
                            if exp != "ללא תפוגה" {
                                Text(exp)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }

                            if c.id == row.selectedCouponId {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            row.selectedCouponId = c.id
                            showCouponPicker = false
                        }
                    }
                    .navigationTitle("בחר קופון")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("סגור") { showCouponPicker = false }
                        }
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
            
            // Amount input
            HStack(spacing: 10) {
                TextField("סכום לדיווח", text: $row.amountText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: row.id)
                
                Button("ניצול מלא") {
                    if let coupon = selectedCoupon {
                        row.amountText = numberString(coupon.remainingValue)
                        focusedField = nil // Dismiss keyboard
                    }
                }
                .buttonStyle(.bordered)
                
                Button("אשר סכום") {
                    if let amount = parseAmount(row.amountText) {
                        row.amountText = numberString(amount)
                    }
                    focusedField = nil
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(row.checked ? Color.green.opacity(0.7) : Color.gray.opacity(0.2), lineWidth: 1.5)
        )
        // Indicators moved to background HStack above
        .contentShape(Rectangle())
        .offset(x: swipeOffset)
        .highPriorityGesture(
            DragGesture()
                .onChanged { value in
                    guard abs(value.translation.height) < 40 else { return }
                    guard focusedField != row.id && !showCouponPicker else { return }
                    let effective = (layoutDirection == .rightToLeft) ? -value.translation.width : value.translation.width
                    swipeOffset = effective

                    // Haptic when crossing thresholds
                    if effective <= -swipeThreshold && !didCrossLeftThreshold {
                        triggerHaptic(.success)
                        didCrossLeftThreshold = true
                        didCrossRightThreshold = false
                    } else if effective >= swipeThreshold && !didCrossRightThreshold {
                        triggerHaptic(.warning)
                        didCrossRightThreshold = true
                        didCrossLeftThreshold = false
                    } else if abs(effective) < swipeThreshold {
                        // Reset so user can cross again in the same gesture if they move back
                        didCrossLeftThreshold = false
                        didCrossRightThreshold = false
                    }
                }
                .onEnded { value in
                    guard abs(value.translation.height) < 40 else { withAnimation { swipeOffset = 0 }; return }
                    let dx = swipeOffset
                    if dx <= -swipeThreshold {
                        // Approve and auto-submit this row
                        approveAmount()
                        if let used = parseAmount(row.amountText), used > 0 {
                            onApproveSwipe(row.selectedCouponId, used)
                        }
                        triggerHaptic(.success)
                        withAnimation(.spring()) { swipeOffset = -120 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(120)) {
                            withAnimation { swipeOffset = 0 }
                        }
                    } else if dx >= swipeThreshold {
                        withAnimation { row.checked = false }
                        triggerHaptic(.warning)
                        withAnimation(.spring()) { swipeOffset = 120 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(120)) {
                            withAnimation { swipeOffset = 0 }
                        }
                    } else {
                        withAnimation { swipeOffset = 0 }
                    }

                    // Reset haptic crossing flags for next gesture
                    didCrossLeftThreshold = false
                    didCrossRightThreshold = false
                }
        )
    }

    }

    @ViewBuilder
    private var pickerLabel: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(selectedCoupon?.decryptedCode ?? "בחר קופון")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? .white : Color.appBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color.appBlue.opacity(0.2) : Color.appBlue.opacity(0.1))
                )
            
            if let coupon = selectedCoupon {
                HStack {
                    Text("נותר:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("₪\(numberString(coupon.remainingValue))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Spacer()
                    let exp = coupon.formattedExpirationDate
                    if exp != "ללא תפוגה" {
                        Text(exp)
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    @ViewBuilder
    private func couponPickerRow(for coupon: Coupon) -> some View {
        HStack(spacing: 12) {
            companyLogo(for: coupon.company)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading) {
                Text("קוד: \(coupon.decryptedCode)")
                    .fontWeight(.bold)
                Text("נותר: ₪\(numberString(coupon.remainingValue))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            let exp = coupon.formattedExpirationDate
            if exp != "ללא תפוגה" {
                Text(exp)
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
    
    @ViewBuilder
    private func companyLogo(for companyName: String) -> some View {
        let company = allCompanies.first { $0.name.caseInsensitiveCompare(companyName) == .orderedSame }
        // Align with CouponDetailView: baseURL + imagePath
        if let company = company,
           let url = URL(string: "https://www.couponmasteril.com/static/" + company.imagePath) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit)
                case .failure(_):
                    placeholderIcon(for: companyName)
                case .empty:
                    ProgressView()
                @unknown default:
                    placeholderIcon(for: companyName)
                }
            }
        } else {
            placeholderIcon(for: companyName)
        }
    }
    
    private func placeholderIcon(for companyName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.appBlue.opacity(0.1))
            Text(String(companyName.prefix(2)))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color.appBlue)
        }
    }
    
    private func parseAmount(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "₪", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }

    private func approveAmount() {
        if let amount = parseAmount(row.amountText) {
            row.amountText = numberString(amount)
        }
        row.checked = true
    }

    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    private func numberString(_ d: Double, fractionalDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionalDigits
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: d)) ?? "\(d)"
    }
}


#Preview {
    // Mock data for preview
    let mockCoupons = [
        Coupon(id: 1, code: "ENC123", description: "Shufersal Coupon", value: 100, cost: 0, company: "Shufersal", expiration: "2025-12-31", source: "manual", buyMeCouponUrl: nil, straussCouponUrl: nil, xgiftcardCouponUrl: nil, xtraCouponUrl: nil, dateAdded: "2024-01-01", usedValue: 20, status: "פעיל", isAvailable: true, isForSale: false, isOneTime: false, purpose: nil, excludeSaving: false, autoDownloadDetails: nil, userId: 1, cvv: nil, cardExp: nil),
        Coupon(id: 2, code: "ENC456", description: "Shufersal Gift Card", value: 200, cost: 180, company: "Shufersal", expiration: "2025-10-20", source: "manual", buyMeCouponUrl: nil, straussCouponUrl: nil, xgiftcardCouponUrl: nil, xtraCouponUrl: nil, dateAdded: "2024-02-01", usedValue: 150, status: "פעיל", isAvailable: true, isForSale: false, isOneTime: false, purpose: nil, excludeSaving: false, autoDownloadDetails: nil, userId: 1, cvv: nil, cardExp: nil),
        Coupon(id: 3, code: "ENC789", description: "Wolt Coupon", value: 50, cost: 0, company: "Wolt", expiration: "2025-11-30", source: "sms", buyMeCouponUrl: nil, straussCouponUrl: nil, xgiftcardCouponUrl: nil, xtraCouponUrl: nil, dateAdded: "2024-03-01", usedValue: 0, status: "פעיל", isAvailable: true, isForSale: false, isOneTime: true, purpose: "Meal", excludeSaving: false, autoDownloadDetails: nil, userId: 1, cvv: nil, cardExp: nil)
    ]
    
    let mockCompanies = [
        Company(id: 1, name: "Shufersal", imagePath: "images/shufersal.png", companyCount: 2),
        Company(id: 2, name: "Wolt", imagePath: "images/wolt.png", companyCount: 1)
    ]
    
    let mockUser = User(id: 1, email: "test@test.com", password: nil, firstName: "Test", lastName: "User", age: 30, gender: "male", region: nil, isConfirmed: true, isAdmin: false, slots: 10, slotsAutomaticCoupons: 50, createdAt: "2024-01-01", profileDescription: nil, profileImage: nil, couponsSoldCount: 0, isDeleted: false, dismissedExpiringAlertAt: nil, dismissedMessageId: nil, googleId: nil, newsletterSubscription: false, telegramMonthlySummary: false, newsletterImage: nil, showWhatsappBanner: false, faceIdEnabled: false, pushToken: nil)

    return QuickUsageReportView(user: mockUser, coupons: mockCoupons, allCompanies: mockCompanies, onUsageReported: {})
}
