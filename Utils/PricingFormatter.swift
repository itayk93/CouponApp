import Foundation

/// Helper to format currency and percentage inputs while dropping `.00` for whole numbers.
struct PricingFormatter {
    static func string(from value: Double) -> String {
        let rounded = (value * 100).rounded() / 100

        if rounded == 0 {
            return "0"
        }

        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(rounded))
        }

        return String(format: "%.2f", rounded)
    }
}
