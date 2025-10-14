//
//  OpenAIClient.swift
//  CouponManagerApp
//
//  OpenAI API Client for GPT-4o text and vision analysis
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct OpenAIClient {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Text Analysis (SMS/Text input)
    func extractCouponFromText(_ text: String, companies: [Company] = []) async throws -> CouponExtractionResult {
        // Special handling for Strauss URLs and BuyMe URLs
        let isStraussCoupon = text.contains("cc.strauss-group.com") || text.contains("strauss-group.com")
        let isBuyMeCoupon = text.lowercased().contains("buyme.co.il") || text.lowercased().contains("buyme") || isStraussCoupon
        
        // Create companies list for matching
        let companiesStr = companies.map { $0.name }.joined(separator: ", ")
        let companiesGuidance = companies.isEmpty ? 
            "זהה חברות מוכרות כמו: WOLT, וולט, Wolt, KFC, McDonald's, Pizza Hut, Domino's, BUYME" : 
            "אלו הן רשימת החברות הקיימות במאגר שלנו: \(companiesStr)\n\nאנא זהה את החברה מהטקסט:\n- בצע התאמה ללא תלות ברישיות (CASE-INSENSITIVE) - לדוגמא: WOLT, wolt, Wolt, וולט כולם מתייחסים לאותה חברה\n- אם שם החברה שזיהית דומה (לא משנה אותיות גדולות/קטנות) לאחת החברות ברשימה, השתמש בשם החברה כפי שהוא מופיע ברשימה בדיוק\n- אם לא קיימת התאמה מספקת, השתמש בשם החברה המקורי שזיהית.\n\n**הנחיה מיוחדת**: אם הטקסט מכיל קישור של strauss-group.com או BUYME, החברה היא 'BUYME' ללא קשר לתוכן הטקסט."
        
        // Add special instruction for Strauss/BUYME detection
        let straussGuidance = isStraussCoupon ? 
            "\n\n**זיהוי אוטומטי**: נמצא קישור של Strauss Group - מדובר בקופון BUYME. קבע שהחברה היא 'BUYME'." : ""
        
        let prompt = """
        בהתבסס על המידע הבא:
        \(text)
        
        \(companiesGuidance)\(straussGuidance)
        
        אנא ספק פלט JSON עם המפתחות הבאים:
        - code: קוד הקופון
        - description: תיאור הקופון (כלול את כל הטקסט המקורי)
        - value: ערך הקופון במספר (לדוגמא: 100.0)
        - cost: כמה שילמתי על הקופון במספר (לדוגמא: 75.0) - חפש ביטויים כמו "שילמתי", "עלה לי", "קניתי ב"
        - company: שם החברה שבה משתמשים בקופון (לדוגמא: WOLT, מקדונלדס, KFC)
        - expiration: תאריך תפוגה בפורמט YYYY-MM-DD
        - source: מי שלח את הקופון (לדוגמא: "ביטוח ישיר", "בזק", "כרטיסי אשראי")
        
        הנחיות חשובות לזיהוי:
        - **company**: איפה משתמשים בקופון - זהה מהוראות השימוש או מהטקסט
          * דוגמא: "קופון ל-WOLT" → company: "WOLT"
          * דוגמא: "תו קנייה ב-מקדונלדס" → company: "מקדונלדס"
        - **source**: מי שלח את הקופון - חפש ביטויים כמו:
          * "מבית ביטוח ישיר" → source: "ביטוח ישיר"
          * "מועדון ישיר מבית ביטוח ישיר" → source: "ביטוח ישיר"  
          * "שלום מבזק" → source: "בזק"
          * בתחילת ההודעה
        - אם לא מוצא מידע, השאר ריק (null)
        
        בנוסף - הנחיות חשובות:
        - **value**: ערך הקופון עצמו ("תו קנייה בשווי 100 ₪" → 100.0)
        - **cost**: כמה שילמתי עליו ("שילמתי על זה 75 שקל" → 75.0)
        - **expiration**: המר תאריכים בדקדקנות:
          * "04-10-2030" → "2030-10-04" (dd-mm-yyyy → yyyy-mm-dd)
          * "31/12/2025" → "2025-12-31" (dd/mm/yyyy → yyyy-mm-dd)
          * "תוקף: 15.1.2024" → "2024-01-15"
        - **description**: כלול את כל הטקסט המקורי ללא שינוי
        """
        
        let messages = [
            ChatMessage(role: "system", content: createSystemPromptForText()),
            ChatMessage(role: "user", content: prompt)
        ]
        
        let request = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: messages,
            temperature: 0.1,
            maxTokens: 1000
        )
        
        let result = try await sendChatRequest(request)
        
        // Apply company name matching post-processing for text analysis
        var fixedResult = result
        
        // Special handling for Strauss URLs and BuyMe URLs - force BUYME company
        if isStraussCoupon || isBuyMeCoupon {
            print("🏢 Strauss/BuyMe URL detected - auto-setting company to BUYME")
            // Extract URLs from text
            let straussUrl = extractStraussUrl(from: text)
            let buyMeUrl = extractBuyMeUrl(from: text)
            let autoDownloadDetails = determineAutoDownloadDetails(for: "BUYME")
            fixedResult = CouponExtractionResult(
                code: result.code,
                description: result.description,
                value: result.value,
                cost: result.cost,
                company: "BUYME",
                expiration: result.expiration,
                source: result.source ?? (isStraussCoupon ? "Strauss" : "BuyMe"),
                straussUrl: straussUrl,
                buyMeUrl: buyMeUrl,
                detectedUrls: result.detectedUrls,
                autoDownloadDetails: autoDownloadDetails
            )
        } else if let detectedCompany = result.company, !companies.isEmpty {
            print("🔍 Trying to match company: '\(detectedCompany)' against \(companies.count) companies")
            print("🏢 Available companies: \(companies.map { $0.name })")
            if let matchedCompany = matchCompanyName(detectedCompany, from: companies) {
                print("✅ Found match: '\(detectedCompany)' → '\(matchedCompany)'")
                let autoDownloadDetails = determineAutoDownloadDetails(for: matchedCompany)
                fixedResult = CouponExtractionResult(
                    code: result.code,
                    description: result.description,
                    value: result.value,
                    cost: result.cost,
                    company: matchedCompany,
                    expiration: result.expiration,
                    source: result.source,
                    straussUrl: result.straussUrl,
                    buyMeUrl: result.buyMeUrl,
                    detectedUrls: result.detectedUrls,
                    autoDownloadDetails: autoDownloadDetails
                )
            } else {
                print("❌ No match found for: '\(detectedCompany)'")
                // Still determine auto download details for the detected company
                let autoDownloadDetails = determineAutoDownloadDetails(for: detectedCompany)
                if autoDownloadDetails != nil {
                    fixedResult = CouponExtractionResult(
                        code: result.code,
                        description: result.description,
                        value: result.value,
                        cost: result.cost,
                        company: result.company,
                        expiration: result.expiration,
                        source: result.source,
                        straussUrl: result.straussUrl,
                        detectedUrls: result.detectedUrls,
                        autoDownloadDetails: autoDownloadDetails
                    )
                }
            }
        } else {
            print("⚠️ No company detected or companies list is empty. Detected: \(result.company ?? "nil"), Companies count: \(companies.count)")
        }
        
        return fixedResult
    }
    
    // MARK: - Image Analysis (GPT Vision)
    func extractCouponFromImage(_ imageData: Data, companies: [Company] = []) async throws -> CouponExtractionResult {
        let base64Image = imageData.base64EncodedString()
        
        // Create companies guidance for image analysis
        let companiesStr = companies.map { $0.name }.joined(separator: ", ")
        let companiesGuidance = companies.isEmpty ? 
            "נתח את התמונה וחלץ את פרטי הקופון. זהה את החברה שבה משתמשים בקופון ומי שלח אותו" : 
            "נתח את התמונה וחלץ את פרטי הקופון. חברות קיימות במאגר: \(companiesStr)\n\nהנחיות זיהוי:\n- **company**: זהה איפה משתמשים בקופון (WOLT, מקדונלדס וכו')\n- **source**: זהה מי שלח את הקופון (ביטוח ישיר, בזק וכו')\n- התאם שמות לרשימה אם דומה (CASE-INSENSITIVE)"
        
        let messages = [
            ChatMessage(role: "system", content: createSystemPromptForImage()),
            ChatMessage(
                role: "user", 
                content: [
                    ChatContent(type: "text", text: companiesGuidance),
                    ChatContent(type: "image_url", imageUrl: ImageURL(url: "data:image/jpeg;base64,\(base64Image)"))
                ]
            )
        ]
        
        let request = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: messages,
            temperature: 0.3,
            maxTokens: 1000
        )
        
        let result = try await sendChatRequest(request)
        
        // Apply company name matching post-processing for image analysis
        var fixedResult = result
        if let detectedCompany = result.company, !companies.isEmpty {
            if let matchedCompany = matchCompanyName(detectedCompany, from: companies) {
                let autoDownloadDetails = determineAutoDownloadDetails(for: matchedCompany)
                fixedResult = CouponExtractionResult(
                    code: result.code,
                    description: result.description,
                    value: result.value,
                    cost: result.cost,
                    company: matchedCompany,
                    expiration: result.expiration,
                    source: result.source,
                    straussUrl: result.straussUrl,
                    buyMeUrl: result.buyMeUrl,
                    detectedUrls: result.detectedUrls,
                    autoDownloadDetails: autoDownloadDetails
                )
            } else {
                // Still determine auto download details for the detected company
                let autoDownloadDetails = determineAutoDownloadDetails(for: detectedCompany)
                if autoDownloadDetails != nil {
                    fixedResult = CouponExtractionResult(
                        code: result.code,
                        description: result.description,
                        value: result.value,
                        cost: result.cost,
                        company: result.company,
                        expiration: result.expiration,
                        source: result.source,
                        straussUrl: result.straussUrl,
                        detectedUrls: result.detectedUrls,
                        autoDownloadDetails: autoDownloadDetails
                    )
                }
            }
        }
        
        return fixedResult
    }
    
    // MARK: - Company Name Translation
    func translateCompanyName(_ hebrewName: String) async throws -> String {
        let prompt = """
        תרגם את שם החברה הבא מעברית לאנגלית. תחזיר רק את השם באנגלית, ללא הסברים:
        "\(hebrewName)"
        """
        
        let messages = [
            ChatMessage(role: "user", content: prompt)
        ]
        
        let request = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: messages,
            temperature: 0.1,
            maxTokens: 50
        )
        
        let response = try await sendChatRequest(request)
        return response.company ?? hebrewName
    }
    
    // MARK: - Private Methods
    private func determineAutoDownloadDetails(for company: String?) -> String? {
        guard let company = company?.lowercased() else { return nil }
        
        // Apply the mapping rules as specified
        if company.contains("buyme") {
            return "BuyMe"
        } else if company.contains("goodpharm") {
            return "Multipass"
        } else if company.contains("carrefour") {
            return "Multipass"
        }
        
        return nil
    }
    
    private func extractStraussUrl(from text: String) -> String? {
        // Use regex to find Strauss URLs
        let pattern = "https?://[\\w.-]*strauss[\\w.-]*\\.com[^\\s]*"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: text.utf16.count)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                let url = String(text[Range(match.range, in: text)!])
                print("🔗 Extracted Strauss URL: \(url)")
                return url
            }
        } catch {
            print("❌ Error extracting Strauss URL: \(error)")
        }
        return nil
    }
    
    private func extractBuyMeUrl(from text: String) -> String? {
        // Use regex to find BuyMe URLs
        let pattern = "https?://[\\w.-]*buyme\\.co\\.il[^\\s]*"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: text.utf16.count)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                let url = String(text[Range(match.range, in: text)!])
                print("🔗 Extracted BuyMe URL: \(url)")
                return url
            }
        } catch {
            print("❌ Error extracting BuyMe URL: \(error)")
        }
        return nil
    }
    
    private func matchCompanyName(_ detectedName: String, from companies: [Company]) -> String? {
        print("🔎 matchCompanyName: Trying to match '\(detectedName)'")
        
        // Direct exact match first
        if let exactMatch = companies.first(where: { $0.name == detectedName }) {
            print("✅ Exact match found: '\(detectedName)' == '\(exactMatch.name)'")
            return exactMatch.name
        }
        
        // Case-insensitive match
        if let caseMatch = companies.first(where: { $0.name.lowercased() == detectedName.lowercased() }) {
            print("✅ Case-insensitive match found: '\(detectedName.lowercased())' == '\(caseMatch.name.lowercased())'")
            return caseMatch.name
        }
        
        // Fuzzy match for common variations
        let cleanDetected = detectedName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        print("🧹 Cleaned detected name: '\(cleanDetected)'")
        if let fuzzyMatch = companies.first(where: { company in
            let cleanCompany = company.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            print("🧹 Comparing with cleaned company: '\(cleanCompany)'")
            return cleanCompany == cleanDetected 
        }) {
            print("✅ Fuzzy match found: '\(cleanDetected)' == '\(fuzzyMatch.name)'")
            return fuzzyMatch.name
        }
        
        print("❌ No match found for '\(detectedName)'")
        return nil
    }
    
    private func sendChatRequest(_ request: ChatCompletionRequest) async throws -> CouponExtractionResult {
        return try await withRetry(maxAttempts: 3) {
            try await performSingleRequest(request)
        }
    }
    
    private func performSingleRequest(_ request: ChatCompletionRequest) async throws -> CouponExtractionResult {
        print("🚀 OpenAI API Request Starting...")
        print("📍 Model: \(request.model)")
        print("📍 Base URL: \(baseURL)")
        
        // Check if API key exists and is properly formatted
        if apiKey.isEmpty {
            print("❌ CRITICAL: API Key is empty!")
            throw OpenAIError.invalidURL
        }
        
        let keyPrefix = String(apiKey.prefix(7))
        let keySuffix = String(apiKey.suffix(4))
        print("📍 API Key: \(keyPrefix)...\(keySuffix) (length: \(apiKey.count))")
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            print("❌ Failed to create URL from: \(baseURL)/chat/completions")
            throw OpenAIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 60
        
        let encoder = JSONEncoder()
        do {
            urlRequest.httpBody = try encoder.encode(request)
            print("📍 Request body size: \(urlRequest.httpBody?.count ?? 0) bytes")
        } catch {
            print("❌ Failed to encode request: \(error)")
            throw error
        }
        
        print("🌐 Sending request to OpenAI...")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        print("📥 Received response from OpenAI")
        print("📍 Response data size: \(data.count) bytes")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response type")
            throw OpenAIError.invalidResponse
        }
        
        print("📍 HTTP Status Code: \(httpResponse.statusCode)")
        print("📍 Response Headers: \(httpResponse.allHeaderFields)")
        
        // Log response body for debugging (first 500 characters)
        if let responseString = String(data: data, encoding: .utf8) {
            let preview = String(responseString.prefix(500))
            print("📍 Response Body Preview: \(preview)")
            if responseString.count > 500 {
                print("📍 (Response truncated - total length: \(responseString.count) characters)")
            }
        }
        
        if httpResponse.statusCode == 429 {
            print("⚠️ Rate limit exceeded (429). Will retry after delay.")
            
            // Try to extract rate limit headers
            if let remainingRequests = httpResponse.value(forHTTPHeaderField: "x-ratelimit-remaining-requests") {
                print("📍 Remaining requests: \(remainingRequests)")
            }
            if let resetTime = httpResponse.value(forHTTPHeaderField: "x-ratelimit-reset-requests") {
                print("📍 Rate limit resets at: \(resetTime)")
            }
            
            throw OpenAIError.rateLimitExceeded
        }
        
        if httpResponse.statusCode == 401 {
            print("❌ AUTHENTICATION ERROR (401): API key might be invalid or expired")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📍 Auth Error Details: \(responseString)")
            }
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ HTTP Error: \(httpResponse.statusCode)")
            
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any] {
                print("📍 OpenAI Error Details:")
                if let message = error["message"] as? String {
                    print("   Message: \(message)")
                }
                if let type = error["type"] as? String {
                    print("   Type: \(type)")
                }
                if let code = error["code"] as? String {
                    print("   Code: \(code)")
                }
            }
            
            throw OpenAIError.httpError(httpResponse.statusCode)
        }
        
        print("✅ Successful response received, parsing JSON...")
        
        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
        
        guard let content = chatResponse.choices.first?.message.content else {
            print("❌ No content found in response choices")
            throw OpenAIError.noContent
        }
        
        print("✅ Content extracted, parsing coupon data...")
        print("📍 GPT Response Content: \(content)")
        
        let result = try parseCouponResponse(content)
        print("✅ Successfully parsed coupon: \(result.company ?? "Unknown") - \(result.code ?? "No code")")
        
        return result
    }
    
    private func withRetry<T>(maxAttempts: Int, operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch let error as OpenAIError where error == .rateLimitExceeded {
                lastError = error
                print("⏳ Attempt \(attempt)/\(maxAttempts) failed with rate limit. Waiting...")
                
                if attempt < maxAttempts {
                    let delaySeconds = min(pow(2.0, Double(attempt - 1)), 60.0)
                    try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            } catch {
                throw error
            }
        }
        
        throw lastError ?? OpenAIError.invalidResponse
    }
    
    private func parseCouponResponse(_ content: String) throws -> CouponExtractionResult {
        // Parse JSON response from GPT
        guard let data = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(CouponExtractionResult.self, from: data)
        } catch {
            print("❌ Failed to parse GPT response as JSON:")
            print("Raw content: \(content)")
            print("Error: \(error)")
            
            // Try to extract JSON from response if it's wrapped in code blocks or text
            var cleanContent = content
            
            // Remove code block markers if present
            if content.contains("```json") || content.contains("```") {
                cleanContent = content.replacingOccurrences(of: "```json", with: "")
                cleanContent = cleanContent.replacingOccurrences(of: "```", with: "")
                cleanContent = cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🧹 Cleaned JSON content: \(cleanContent)")
            }
            
            // Try parsing the cleaned content first
            if let cleanData = cleanContent.data(using: .utf8) {
                do {
                    return try decoder.decode(CouponExtractionResult.self, from: cleanData)
                } catch {
                    print("❌ Failed to parse cleaned content: \(error)")
                }
            }
            
            // Fallback: Try to extract JSON from response if it's wrapped in text
            if let jsonStart = content.range(of: "{"),
               let jsonEnd = content.range(of: "}", options: .backwards) {
                let jsonString = String(content[jsonStart.lowerBound...jsonEnd.upperBound])
                if let jsonData = jsonString.data(using: .utf8) {
                    do {
                        return try decoder.decode(CouponExtractionResult.self, from: jsonData)
                    } catch {
                        print("❌ Failed to parse extracted JSON: \(error)")
                    }
                }
            }
            
            throw OpenAIError.decodingError
        }
    }
    
    private func createSystemPromptForText() -> String {
        return """
        אתה עוזר לחילוץ פרטי קופונים מטקסטים ו-SMS. נתח את הטקסט וחלץ את המידע הבא:
        
        החזר תשובה בפורמט JSON הבא:
        {
            "code": "קוד הקופון",
            "description": "תיאור הקופון - כלול את כל הטקסט המקורי",
            "value": 100.0,
            "cost": 75.0,
            "company": "החברה שבה משתמשים בקופון (WOLT, מקדונלדס וכו')",
            "expiration": "YYYY-MM-DD",
            "source": "מי שלח את הקופון (ביטוח ישיר, בזק וכו')"
        }
        
        הנחיות חשובות:
        - עבור תיאור: כלול את כל הטקסט המקורי של ההודעה
        - עבור חברה: זהה איפה משתמשים בקופון (לא מי שלח אותו)
        - עבור מקור: זהה מי שלח את הקופון על ידי חיפוש ביטויים כמו:
          * "מבית [שם חברה]", "רכשת הטבה מ[שם חברה]", "שלום מ[שם חברה]"
        - עבור ערך: ערך הקופון ("בשווי 100 ₪" → 100.0)
        - עבור עלות: כמה שילמתי ("שילמתי על זה 75 שקל" → 75.0)
        - עבור תאריך תפוגה: המר בדקדקנות:
          * "04-10-2030" → "2030-10-04"
          * "31/12/2025" → "2025-12-31"
          * "15.1.2024" → "2024-01-15"
        - אם לא מצאת מידע מסוים, השתמש ב-null
        """
    }
    
    private func createSystemPromptForImage() -> String {
        return """
        אתה עוזר לחילוץ פרטי קופונים מתמונות. נתח את התמונה וחלץ את המידע הבא:
        - קוד הקופון
        - תיאור הקופון
        - ערך הקופון (בשקלים)
        - שם החברה שהנפיקה את הקופון (לא יעד השימוש)
        - תאריך תפוגה
        
        החזר תשובה בפורמט JSON הבא:
        {
            "code": "קוד הקופון",
            "description": "תיאור הקופון",
            "value": 100.0,
            "cost": 75.0,
            "company": "החברה שבה משתמשים בקופון (WOLT, מקדונלדס וכו')",
            "expiration": "YYYY-MM-DD",
            "source": "מי שלח/הנפיק את הקופון (ביטוח ישיר, בזק וכו')"
        }
        
        הנחיות חשובות:
        - **company**: זהה איפה משתמשים בקופון (לא מי שלח אותו)
        - **source**: זהה מי שלח את הקופון על ידי חיפוש:
          * לוגו של החברה השולחת
          * טקסט כמו "מבית [שם חברה]", "שלום מ[שם חברה]" 
          * שם החברה בראש התמונה או בתחתית
        - לדוגמא: אם רואה לוגו "ביטוח ישיר" וקופון ל-WOLT → company: "WOLT", source: "ביטוח ישיר"
        - אם לא ברור מי הנפיק את הקופון, השאר ריק (null)
        - אם לא מצאת מידע מסוים, השתמש ב-null
        """
    }
}

// MARK: - Data Models
struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: ChatMessageContent
    
    init(role: String, content: String) {
        self.role = role
        self.content = .string(content)
    }
    
    init(role: String, content: [ChatContent]) {
        self.role = role
        self.content = .array(content)
    }
}

enum ChatMessageContent: Codable {
    case string(String)
    case array([ChatContent])
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([ChatContent].self) {
            self = .array(array)
        } else {
            throw DecodingError.typeMismatch(ChatMessageContent.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid content type"))
        }
    }
}

struct ChatContent: Codable {
    let type: String
    let text: String?
    let imageUrl: ImageURL?
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }
    
    init(type: String, text: String) {
        self.type = type
        self.text = text
        self.imageUrl = nil
    }
    
    init(type: String, imageUrl: ImageURL) {
        self.type = type
        self.text = nil
        self.imageUrl = imageUrl
    }
}

struct ImageURL: Codable {
    let url: String
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: ResponseMessage
}

struct ResponseMessage: Codable {
    let content: String?
}

struct CouponExtractionResult: Codable {
    let code: String?
    let description: String?
    let value: Double?
    let cost: Double?
    let company: String?
    let expiration: String?
    let source: String?
    let straussUrl: String?
    let buyMeUrl: String?
    let detectedUrls: [String]?
    let autoDownloadDetails: String?
    
    init(code: String?, description: String?, value: Double?, cost: Double?, company: String?, expiration: String?, source: String?, straussUrl: String? = nil, buyMeUrl: String? = nil, detectedUrls: [String]? = nil, autoDownloadDetails: String? = nil) {
        self.code = code
        self.description = description
        self.value = value
        self.cost = cost
        self.company = company
        self.expiration = expiration
        self.source = source
        self.straussUrl = straussUrl
        self.buyMeUrl = buyMeUrl
        self.detectedUrls = detectedUrls
        self.autoDownloadDetails = autoDownloadDetails
    }
}

// MARK: - Error Types
enum OpenAIError: Error, LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case noContent
    case httpError(Int)
    case decodingError
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "כתובת URL לא תקינה"
        case .invalidResponse:
            return "תגובה לא תקינה מהשרת"
        case .noContent:
            return "אין תוכן בתגובה"
        case .httpError(let code):
            if code == 429 {
                return "יותר מדי בקשות - נסה שוב בעוד כמה דקות"
            }
            return "שגיאת רשת: \(code)"
        case .decodingError:
            return "שגיאה בעיבוד התגובה"
        case .rateLimitExceeded:
            return "חרגת ממגבלת הבקשות - מנסה שוב..."
        }
    }
}