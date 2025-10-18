import SwiftUI

struct QuickUsageView: View {
    @StateObject private var vm = QuickUsageViewModel()

    var reportUsage: (_ couponIds: [String]) async throws -> Void
    var loadActiveCoupons: () -> [Coupon]

    var body: some View {
        VStack(spacing: 12) {
            Text("דיווח מהיר על שימוש בקופון")
                .font(.title2)
                .bold()

            TextEditor(text: $vm.inputText)
                .frame(minHeight: 120)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary, lineWidth: 1))
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            HStack {
                Button(action: { Task { await vm.analyze() } }) {
                    if vm.isLoading {
                        ProgressView()
                    } else {
                        Label("ניתוח עם GPT-4o-mini", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button(role: .none, action: { Task { await vm.confirmSelection(reportUsage: reportUsage) } }) {
                    Label("אשר שימוש", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(vm.selectedCouponIds.isEmpty)
            }

            if let err = vm.errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            List {
                Section(header: Text("קופונים פעילים")) {
                    ForEach(vm.activeCoupons) { coupon in
                        HStack(alignment: .top, spacing: 8) {
                            Toggle(isOn: Binding(
                                get: { vm.selectedCouponIds.contains(coupon.id) },
                                set: { newVal in
                                    if newVal { vm.selectedCouponIds.insert(coupon.id) } else { vm.selectedCouponIds.remove(coupon.id) }
                                }
                            )) { VStack(alignment: .leading) {
                                Text(coupon.title).font(.headline)
                                if let code = coupon.code, !code.isEmpty { Text("קוד: \(code)").font(.subheadline).foregroundColor(.secondary) }
                                if let merchant = coupon.merchant, !merchant.isEmpty { Text("בית עסק: \(merchant)").font(.subheadline).foregroundColor(.secondary) }
                                if let s = vm.suggestions.first(where: { $0.couponId == coupon.id }) {
                                    Text(String(format: "התאמה: %.0f%%", s.confidence * 100)).font(.caption).foregroundColor(.blue)
                                    if let m = s.matchedText, !m.isEmpty { Text("זיהוי: \(m)").font(.caption2).foregroundColor(.secondary) }
                                }
                            } }
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            vm.loadActiveCoupons(loadActiveCoupons())
        }
    }
}

// Preview stub
struct QuickUsageView_Previews: PreviewProvider {
    static var previews: some View {
        QuickUsageView(
            reportUsage: { _ in },
            loadActiveCoupons: { [
                Coupon(id: "c1", title: "10% הנחה", code: "SAVE10", merchant: "Shop A"),
                Coupon(id: "c2", title: "1+1", code: nil, merchant: "Cafe B")
            ] }
        )
    }
}
