//
//  GPTUsageTracker.swift
//  CouponManagerApp
//
//  מעקב שימוש ב-GPT לצורך סטטיסטיקות ועלויות
//

import Foundation
import Combine

class GPTUsageTracker: ObservableObject {
    static let shared = GPTUsageTracker()
    
    @Published var totalTextRequests = 0
    @Published var totalImageRequests = 0
    @Published var totalTokensUsed = 0
    @Published var estimatedCost = 0.0
    
    private let userDefaults = UserDefaults.standard
    
    // Pricing (per 1K tokens) - Updated as of GPT-4o-mini pricing
    private let textInputPricePerToken = 0.00015 / 1000  // $0.00015 per 1K input tokens
    private let textOutputPricePerToken = 0.0006 / 1000  // $0.0006 per 1K output tokens
    private let visionPricePerToken = 0.0025 / 1000      // $0.0025 per 1K tokens for vision
    
    private init() {
        loadStoredData()
    }
    
    // MARK: - Public Methods
    func trackTextRequest(inputTokens: Int, outputTokens: Int) {
        totalTextRequests += 1
        totalTokensUsed += inputTokens + outputTokens
        
        let cost = (Double(inputTokens) * textInputPricePerToken) + 
                  (Double(outputTokens) * textOutputPricePerToken)
        estimatedCost += cost
        
        saveToStorage()
        
        // Log for debugging
        print("GPT Text Request - Input: \(inputTokens), Output: \(outputTokens), Cost: $\(String(format: "%.4f", cost))")
    }
    
    func trackImageRequest(tokens: Int) {
        totalImageRequests += 1
        totalTokensUsed += tokens
        
        let cost = Double(tokens) * visionPricePerToken
        estimatedCost += cost
        
        saveToStorage()
        
        // Log for debugging
        print("GPT Vision Request - Tokens: \(tokens), Cost: $\(String(format: "%.4f", cost))")
    }
    
    func resetStats() {
        totalTextRequests = 0
        totalImageRequests = 0
        totalTokensUsed = 0
        estimatedCost = 0.0
        saveToStorage()
    }
    
    func getUsageStats() -> GPTUsageStats {
        return GPTUsageStats(
            textRequests: totalTextRequests,
            imageRequests: totalImageRequests,
            totalRequests: totalTextRequests + totalImageRequests,
            totalTokens: totalTokensUsed,
            estimatedCost: estimatedCost,
            averageCostPerRequest: totalTextRequests + totalImageRequests > 0 ? 
                estimatedCost / Double(totalTextRequests + totalImageRequests) : 0
        )
    }
    
    // MARK: - Private Methods
    private func loadStoredData() {
        totalTextRequests = userDefaults.integer(forKey: "gpt_text_requests")
        totalImageRequests = userDefaults.integer(forKey: "gpt_image_requests")
        totalTokensUsed = userDefaults.integer(forKey: "gpt_total_tokens")
        estimatedCost = userDefaults.double(forKey: "gpt_estimated_cost")
    }
    
    private func saveToStorage() {
        userDefaults.set(totalTextRequests, forKey: "gpt_text_requests")
        userDefaults.set(totalImageRequests, forKey: "gpt_image_requests")
        userDefaults.set(totalTokensUsed, forKey: "gpt_total_tokens")
        userDefaults.set(estimatedCost, forKey: "gpt_estimated_cost")
    }
}

// MARK: - Usage Stats Model
struct GPTUsageStats {
    let textRequests: Int
    let imageRequests: Int
    let totalRequests: Int
    let totalTokens: Int
    let estimatedCost: Double
    let averageCostPerRequest: Double
    
    var formattedCost: String {
        return String(format: "$%.4f", estimatedCost)
    }
    
    var formattedAverageCost: String {
        return String(format: "$%.4f", averageCostPerRequest)
    }
}

// MARK: - Enhanced OpenAI Client with Usage Tracking
extension OpenAIClient {
    func extractCouponFromTextWithTracking(_ text: String, companies: [Company] = []) async throws -> CouponExtractionResult {
        print("🔄 GPTUsageTracker: Starting text analysis with tracking...")
        let result = try await extractCouponFromText(text, companies: companies)
        
        // Estimate tokens (rough approximation: 1 token ≈ 4 characters)
        let inputTokens = text.count / 4
        let outputTokens = 100 // Estimated output tokens for coupon extraction
        
        GPTUsageTracker.shared.trackTextRequest(inputTokens: inputTokens, outputTokens: outputTokens)
        print("✅ GPTUsageTracker: Text analysis completed and tracked")
        
        return result
    }
    
    func extractCouponFromImageWithTracking(_ imageData: Data, companies: [Company] = []) async throws -> CouponExtractionResult {
        print("🔄 GPTUsageTracker: Starting image analysis with tracking...")
        let result = try await extractCouponFromImage(imageData, companies: companies)
        
        // Estimate tokens for image analysis (base cost + image size factor)
        let baseTokens = 200
        let imageSizeTokens = imageData.count / 1000 // Rough estimation
        let totalTokens = baseTokens + imageSizeTokens
        
        GPTUsageTracker.shared.trackImageRequest(tokens: totalTokens)
        print("✅ GPTUsageTracker: Image analysis completed and tracked")
        
        return result
    }
    
    func translateCompanyNameWithTracking(_ hebrewName: String) async throws -> String {
        print("🔄 GPTUsageTracker: Starting translation with tracking...")
        let result = try await translateCompanyName(hebrewName)
        
        // Estimate tokens for translation
        let inputTokens = hebrewName.count / 4
        let outputTokens = 20 // Small output for company name
        
        GPTUsageTracker.shared.trackTextRequest(inputTokens: inputTokens, outputTokens: outputTokens)
        print("✅ GPTUsageTracker: Translation completed and tracked")
        
        return result
    }
}

// MARK: - Usage Statistics View
import SwiftUI

struct GPTUsageStatsView: View {
    @StateObject private var tracker = GPTUsageTracker.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("סטטיסטיקות שימוש") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("בקשות טקסט")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(tracker.totalTextRequests)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("בקשות תמונה")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(tracker.totalImageRequests)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("סה״כ בקשות")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(tracker.totalTextRequests + tracker.totalImageRequests)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("סה״כ טוקנים")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(tracker.totalTokensUsed)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                Section("עלויות מוערכות") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("עלות כוללת")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(tracker.getUsageStats().formattedCost)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("ממוצע לבקשה")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(tracker.getUsageStats().formattedAverageCost)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.appBlue)
                        }
                    }
                }
                
                Section {
                    Button("איפוס סטטיסטיקות") {
                        tracker.resetStats()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("הערות חשובות:")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("• העלויות הן הערכה בלבד ועלולות להשתנות")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• המחירים מבוססים על תעריפי GPT-4o-mini הנוכחיים")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• ספירת הטוקנים היא הערכה גסה")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("סטטיסטיקות GPT")
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}