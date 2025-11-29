import Foundation

enum MonthlySummaryError: LocalizedError {
    case missingAuthToken
    case invalidResponse
    case decodingFailed
    case badURL
    
    var errorDescription: String? {
        switch self {
        case .missingAuthToken:
            return "Missing authentication token for monthly summary request."
        case .invalidResponse:
            return "Monthly summary request failed."
        case .decodingFailed:
            return "Could not parse monthly summary data."
        case .badURL:
            return "Invalid monthly summary URL."
        }
    }
}

final class MonthlySummaryService {
    private let baseURL: URL
    private let session: URLSession
    private let cache: MonthlySummaryCache
    
    init(
        baseURL: URL = URL(string: "https://couponmasteril.com")!,
        session: URLSession = .shared,
        cache: MonthlySummaryCache = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.cache = cache
    }
    
    func fetchSummary(
        month: Int,
        year: Int,
        userId: Int,
        summaryId: String? = nil,
        forceRefresh: Bool = false,
        allowFallback: Bool = true
    ) async throws -> MonthlySummaryModel {
        if !forceRefresh, let cached = cache.cachedSummary(month: month, year: year) {
            return cached
        }
        
        var components = URLComponents(url: baseURL.appendingPathComponent("api/mobile/monthly-summary"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "month", value: String(format: "%02d", month)),
            URLQueryItem(name: "year", value: "\(year)")
        ]
        
        if allowFallback {
            components?.queryItems?.append(URLQueryItem(name: "fallback", value: "true"))
        }
        
        guard let url = components?.url else {
            throw MonthlySummaryError.badURL
        }
        
        var request = try makeRequest(url: url, userId: userId)
        if let summaryId = summaryId {
            request.setValue(summaryId, forHTTPHeaderField: "X-Summary-Id")
        }
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MonthlySummaryError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let summary = try? decoder.decode(MonthlySummaryModel.self, from: data) else {
            throw MonthlySummaryError.decodingFailed
        }
        
        cache.save(summary: summary)
        AppLogger.log("📈 Monthly summary loaded \(summary.id) (\(summary.month)/\(summary.year))")
        return summary
    }
    
    func fetchList(limit: Int = 12, userId: Int, forceRefresh: Bool = false) async throws -> [MonthlySummaryListItem] {
        if !forceRefresh, let cached = cache.cachedList() {
            return cached
        }
        
        var components = URLComponents(url: baseURL.appendingPathComponent("api/mobile/monthly-summary/list"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        
        guard let url = components?.url else { throw MonthlySummaryError.badURL }
        
        let request = try makeRequest(url: url, userId: userId)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 {
                cache.save(list: [])
                return []
            }
            guard (200..<300).contains(http.statusCode) else {
                throw MonthlySummaryError.invalidResponse
            }
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let items = try? decoder.decode([MonthlySummaryListItem].self, from: data) else {
            throw MonthlySummaryError.decodingFailed
        }
        
        cache.save(list: items)
        return items
    }
    
    @discardableResult
    func acknowledge(summaryId: String, userId: Int, read: Bool = true) async throws -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/mobile/monthly-summary/ack"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request = try makeRequest(url: request.url!, userId: userId, requireAuth: true)
        } catch MonthlySummaryError.missingAuthToken {
            return false
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: ["summary_id": summaryId, "read": read])
        
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return false
        }
        return true
    }
    
    private func makeRequest(url: URL, userId: Int, requireAuth: Bool = false) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(userId)", forHTTPHeaderField: "X-User-Id")
        
        if let token = authToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if requireAuth {
            throw MonthlySummaryError.missingAuthToken
        }
        
        return request
    }
    
    private func authToken() -> String? {
        if let shared = AppGroupManager.shared.sharedUserDefaults?.string(forKey: "userToken"), !shared.isEmpty {
            return shared
        }
        if let local = UserDefaults.standard.string(forKey: "userToken"), !local.isEmpty {
            return local
        }
        return nil
    }
}
