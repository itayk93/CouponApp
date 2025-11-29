import SwiftUI

struct MonthlySummariesListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MonthlySummariesListViewModel
    
    private let onSelect: (MonthlySummaryTrigger) -> Void
    
    init(user: User, onSelect: @escaping (MonthlySummaryTrigger) -> Void) {
        _viewModel = StateObject(wrappedValue: MonthlySummariesListViewModel(userId: user.id))
        self.onSelect = onSelect
    }
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    listSkeleton
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text("לא ניתן לטעון את רשימת הסיכומים")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("נסה שוב") {
                            Task { await viewModel.load(forceRefresh: true) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if viewModel.items.isEmpty {
                    VStack(spacing: 12) {
                        Text("אין סיכומים זמינים עדיין")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("הסיכום הראשון יופיע ברגע שהשרת ייצור סיכום חודשי. אם קיבלת התראה ולא רואה כאן, נסה לרענן.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("רענן") {
                            Task { await viewModel.load(forceRefresh: true) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            Button {
                                let trigger = MonthlySummaryTrigger(
                                    summaryId: item.id,
                                    month: item.month,
                                    year: item.year,
                                    style: item.style
                                )
                                MonthlySummaryCache.shared.savePending(trigger: trigger)
                                onSelect(trigger)
                            } label: {
                                HStack {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("📆 \(item.monthName) \(item.year)")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(styleLabel(for: item.style))
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text(dateString(item.generatedAt))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if item.isRead == false {
                                            Text("חדש")
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.15))
                                                .cornerRadius(10)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("סיכומים חודשיים")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("סגור") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await viewModel.load(forceRefresh: true) } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            await viewModel.load()
            if viewModel.items.isEmpty {
                preloadDemoIfNeeded()
            }
        }
    }
    
    private var listSkeleton: some View {
        List {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 56)
                    .redacted(reason: .placeholder)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "he_IL")
        return formatter.string(from: date)
    }
    
    private func styleLabel(for style: String) -> String {
        switch style.lowercased() {
        case "friendly": return "חברותי"
        case "creative": return "יצירתי"
        case "happy": return "שמח"
        case "humorous": return "הומוריסטי"
        case "motivational": return "מדרבן"
        default: return style
        }
    }
}

extension MonthlySummariesListView {
    private func preloadDemoIfNeeded() {
        MonthlySummaryCache.shared.seedDemoSummaryIfNeeded()
        if let updated = MonthlySummaryCache.shared.cachedList(), !updated.isEmpty {
            viewModel.items = updated
        }
    }
}
