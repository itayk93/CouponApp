import Foundation
import Combine

@MainActor
final class MonthlySummaryViewModel: ObservableObject {
    @Published var summary: MonthlySummaryModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAcknowledged = false
    
    private let userId: Int
    private let service: MonthlySummaryService
    
    init(userId: Int, service: MonthlySummaryService = MonthlySummaryService()) {
        self.userId = userId
        self.service = service
    }
    
    func load(month: Int, year: Int, summaryId: String? = nil, forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await service.fetchSummary(
                month: month,
                year: year,
                userId: userId,
                summaryId: summaryId,
                forceRefresh: forceRefresh
            )
            summary = result
            await acknowledgeIfNeeded(result.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func reload() async {
        guard let summary = summary else { return }
        await load(month: summary.month, year: summary.year, summaryId: summary.id, forceRefresh: true)
    }
    
    private func acknowledgeIfNeeded(_ id: String) async {
        guard !isAcknowledged else { return }
        if (try? await service.acknowledge(summaryId: id, userId: userId, read: true)) == true {
            isAcknowledged = true
        }
    }
}

@MainActor
final class MonthlySummariesListViewModel: ObservableObject {
    @Published var items: [MonthlySummaryListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userId: Int
    private let service: MonthlySummaryService
    
    init(userId: Int, service: MonthlySummaryService = MonthlySummaryService()) {
        self.userId = userId
        self.service = service
    }
    
    func load(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await service.fetchList(limit: 12, userId: userId, forceRefresh: forceRefresh)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
