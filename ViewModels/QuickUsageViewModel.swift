import Foundation
import Combine

struct Coupon: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let code: String?
    let merchant: String?
}

@MainActor
final class QuickUsageViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var activeCoupons: [Coupon] = []
    @Published var suggestions: [CouponSuggestion] = []
    @Published var selectedCouponIds: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let aiService = AIQuickUsageService()

    // TODO: inject real data source for active coupons
    func loadActiveCoupons(_ coupons: [Coupon]) {
        self.activeCoupons = coupons
    }

    func analyze() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let dto = activeCoupons.map { ActiveCouponDTO(id: $0.id, title: $0.title, code: $0.code, merchant: $0.merchant) }
            let result = try await aiService.analyzeUsedCoupons(from: inputText, activeCoupons: dto)
            self.suggestions = result
            self.selectedCouponIds = Set(result.map { $0.couponId })
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // Hook to actual usage reporting
    func confirmSelection(reportUsage: @escaping (_ couponIds: [String]) async throws -> Void) async {
        let chosen = Array(selectedCouponIds)
        guard !chosen.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await reportUsage(chosen)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
