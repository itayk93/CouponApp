import SwiftUI
import UIKit

struct MonthlySummaryView: View {
    @StateObject private var viewModel: MonthlySummaryViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    private let month: Int
    private let year: Int
    private let summaryId: String?
    private let onOpenStatistics: ((MonthlySummaryModel) -> Void)?
    private let onClose: () -> Void
    
    @State private var showShareSheet = false
    @State private var heroPulse = false
    
    init(
        userId: Int,
        month: Int,
        year: Int,
        summaryId: String?,
        onOpenStatistics: ((MonthlySummaryModel) -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: MonthlySummaryViewModel(userId: userId))
        self.month = month
        self.year = year
        self.summaryId = summaryId
        self.onOpenStatistics = onOpenStatistics
        self.onClose = onClose
    }
    
    var body: some View {
        ZStack {
            gradientBackground
            VStack(spacing: 12) {
                header
                
                if viewModel.isLoading {
                    loadingState
                } else if let error = viewModel.errorMessage {
                    errorState(message: error)
                } else if let summary = viewModel.summary {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            hero(summary: summary)
                            summaryText(summary: summary)
                            statsGrid(summary: summary)
                            highlights(summary: summary)
                            ctaButtons(summary: summary)
                        }
                        .padding(.bottom, 12)
                    }
                } else {
                    Text("אין נתונים להצגה כעת")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            if viewModel.summary == nil {
                await viewModel.load(month: month, year: year, summaryId: summaryId)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let summary = viewModel.summary {
                SummaryShareSheet(activityItems: [summary.summaryText])
            }
        }
    }
    
    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.cyan]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .offset(x: -140, y: -320)
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .offset(x: 120, y: -260)
            }
        )
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .trailing, spacing: 4) {
                Text("סיכום חודשי")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(monthName(for: month)) \(year)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
    
    private func hero(summary: MonthlySummaryModel) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .trailing, spacing: 6) {
                    Text("📆 סיכום \(summary.monthName) \(summary.year)")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(styleLabel(for: summary.style))
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.blue.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(14)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.title)
                            .foregroundColor(.white)
                            .scaleEffect(heroPulse ? 1.05 : 0.95)
                            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: heroPulse)
                    )
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(18)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .onAppear { heroPulse = true }
    }
    
    private func summaryText(summary: MonthlySummaryModel) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text("תמצית AI")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            Text(summary.summaryText)
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(14)
        }
    }
    
    private func statsGrid(summary: MonthlySummaryModel) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("מדדי מפתח")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 12) {
                statCard(title: "קופונים חדשים", value: "\(summary.stats.newCouponsCount)", icon: "sparkles")
                statCard(
                    title: "ניצול קופונים חדשים",
                    value: "\(summary.stats.usedNewCouponsCount)/\(summary.stats.newCouponsCount)",
                    icon: "bolt.fill",
                    subtitle: "\(Int(summary.stats.usagePercentage))% שימוש"
                )
                statCard(title: "חיסכון חודשי", value: currency(summary.stats.totalSavings), icon: "shekelsign.circle.fill")
                statCard(title: "ערך פעיל", value: currency(summary.stats.totalActiveValue), icon: "creditcard.fill")
            }
        }
    }
    
    private func statCard(title: String, value: String, icon: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.85))
            }
            
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .background(Color.white.opacity(0.12))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func highlights(summary: MonthlySummaryModel) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("נקודות בולטות")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            VStack(alignment: .trailing, spacing: 8) {
                if !summary.stats.popularCompanies.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(summary.stats.popularCompanies.prefix(3)) { company in
                            Text("\(company.name) • \(company.usageCount)")
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                HStack {
                    if summary.stats.expiringNextMonth > 0 {
                        Text("⚠️ \(summary.stats.expiringNextMonth) קופונים יפוגו בחודש הבא")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                
                if !summary.stats.expiringCompanies.isEmpty {
                    Text(summary.stats.expiringCompanies.prefix(3).joined(separator: " • "))
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                HStack {
                    Label(changeText(value: summary.stats.couponsChange, prefix: "שינוי קופונים"), systemImage: summary.stats.couponsChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundColor(summary.stats.couponsChange >= 0 ? .green : .red)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Label(savingsChangeText(summary.stats.savingsChange), systemImage: summary.stats.savingsChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundColor(summary.stats.savingsChange >= 0 ? .green : .red)
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(14)
        }
    }
    
    private func ctaButtons(summary: MonthlySummaryModel) -> some View {
        VStack(spacing: 10) {
            Button(action: {
                onOpenStatistics?(summary)
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Spacer(minLength: 0)
                    Text("פתח סטטיסטיקות")
                        .fontWeight(.semibold)
                    Image(systemName: "chart.pie.fill")
                }
                .foregroundColor(.blue)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(12)
            }
            
            HStack(spacing: 10) {
                Button {
                    showShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Spacer(minLength: 0)
                        Text("שיתוף")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
                }
                
                Button(action: onClose) {
                    HStack {
                        Image(systemName: "xmark")
                        Spacer(minLength: 0)
                        Text("סגור")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var loadingState: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 80)
                    .shimmering(active: true)
            }
        }
    }
    
    private func errorState(message: String) -> some View {
        VStack(spacing: 10) {
            Text("שגיאה בטעינת הסיכום")
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            Button("נסה שוב") {
                Task {
                    await viewModel.load(month: month, year: year, summaryId: summaryId, forceRefresh: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color.white)
            .foregroundColor(.blue)
            .cornerRadius(12)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
    }
    
    private func changeText(value: Int, prefix: String) -> String {
        let arrow = value >= 0 ? "עליה" : "ירידה"
        return "\(prefix): \(arrow) \(abs(value))"
    }
    
    private func savingsChangeText(_ value: Double) -> String {
        let direction = value >= 0 ? "עליה" : "ירידה"
        return "שינוי חיסכון: \(direction) \(currency(abs(value)))"
    }
    
    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₪"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₪\(Int(value))"
    }
    
    private func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        return formatter.monthSymbols[(month - 1) % formatter.monthSymbols.count].capitalized
    }
    
    private func styleLabel(for style: String) -> String {
        switch style.lowercased() {
        case "friendly": return "חברותי"
        case "creative": return "יצירתי"
        case "happy": return "שמֵח"
        case "humorous": return "הומוריסטי"
        case "motivational": return "מדרבן"
        default: return style
        }
    }
}

private struct SummaryShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension View {
    func shimmering(active: Bool) -> some View {
        modifier(ShimmerModifier(isActive: active))
    }
}

private struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.6), Color.white.opacity(0.2)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(20))
                        .offset(x: isActive ? geometry.size.width : -geometry.size.width)
                        .animation(
                            isActive
                            ? .linear(duration: 1.2).repeatForever(autoreverses: false)
                            : .default,
                            value: isActive
                        )
                }
                .clipped()
            )
    }
}
