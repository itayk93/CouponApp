import Foundation

enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Missing OpenAI API Key"
        case .invalidResponse: return "Invalid response from AI service"
        case .decodingFailed: return "Failed to decode AI response"
        }
    }
}

struct ActiveCouponDTO: Codable {
    let id: String
    let title: String
    let code: String?
    let merchant: String?
}

struct AISuggestionResponse: Codable {
    struct Item: Codable {
        let couponId: String
        let confidence: Double
        let matchedText: String?
        let rationale: String?
    }
    let suggestions: [Item]
}

final class AIQuickUsageService {
    private let session: URLSession
    private let model: String = "gpt-4o-mini"

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func apiKey() -> String? {
        // 1) Try env var
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty { return key }
        // 2) Try Info.plist (via Config.xcconfig)
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !key.isEmpty { return key }
        return nil
    }

    func analyzeUsedCoupons(from text: String, activeCoupons: [ActiveCouponDTO]) async throws -> [CouponSuggestion] {
        guard let apiKey = apiKey() else { throw AIServiceError.missingAPIKey }

        let systemPrompt = """
        You are an assistant that extracts which coupons were used from a user-provided text. You must:
        - Consider only the provided active coupons list.
        - Return a JSON response in the exact schema:
          { "suggestions": [ { "couponId": "<string>", "confidence": <0..1>, "matchedText": "<string>", "rationale": "<string>" } ] }
        - confidence is 0..1 (double). Include only coupons with confidence >= 0.3.
        - couponId must be one of the provided active coupons' id.
        - Keep suggestions concise.
        """

        let activeList = activeCoupons.map { [
            "id": $0.id,
            "title": $0.title,
            "code": $0.code ?? "",
            "merchant": $0.merchant ?? ""
        ] }

        let userPayload: [String: Any] = [
            "text": text,
            "active_coupons": activeList
        ]

        let userPromptData = try JSONSerialization.data(withJSONObject: userPayload, options: [.sortedKeys])
        let userPrompt = String(data: userPromptData, encoding: .utf8) ?? "{}"

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
            throw AIServiceError.invalidResponse
        }

        // Parse OpenAI chat completion JSON
        struct OpenAIResponse: Codable { struct Choice: Codable { struct Message: Codable { let content: String } let message: Message }; let choices: [Choice] }
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: respData)
        guard let content = decoded.choices.first?.message.content.data(using: .utf8) else {
            throw AIServiceError.decodingFailed
        }
        let suggestions = try JSONDecoder().decode(AISuggestionResponse.self, from: content)
        return suggestions.suggestions.map { CouponSuggestion(couponId: $0.couponId, confidence: $0.confidence, matchedText: $0.matchedText, rationale: $0.rationale) }
    }
}
