import Foundation

struct CouponSuggestion: Identifiable, Codable, Equatable {
    let id: UUID
    let couponId: String
    let confidence: Double
    let matchedText: String?
    let rationale: String?

    init(couponId: String, confidence: Double, matchedText: String? = nil, rationale: String? = nil, id: UUID = UUID()) {
        self.id = id
        self.couponId = couponId
        self.confidence = confidence
        self.matchedText = matchedText
        self.rationale = rationale
    }
}
