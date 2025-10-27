//
//  Coupon+DateAdded.swift
//  CouponManagerApp
//
//  Date parsing helpers for Coupon
//

import Foundation

extension Coupon {
    // Parse `date_added` robustly: supports fractional seconds, timezone offsets, and date-only strings.
    var dateAddedAsDate: Date? {
        // 1) ISO8601 with fractional seconds (e.g., 2024-10-18T12:34:56.123456Z or +00:00)
        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoWithFraction.date(from: dateAdded) {
            return d
        }

        // 2) ISO8601 without fractional seconds
        let isoNoFraction = ISO8601DateFormatter()
        isoNoFraction.formatOptions = [.withInternetDateTime]
        if let d = isoNoFraction.date(from: dateAdded) {
            return d
        }

        // 3) Common fallback formats from DB exports (keep POSIX to avoid locale issues)
        let posix = Locale(identifier: "en_US_POSIX")
        let df = DateFormatter()
        df.locale = posix
        df.timeZone = TimeZone(secondsFromGMT: 0)

        let candidates = [
            // With fractional seconds
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",   // e.g., 2025-10-07T06:36:20.927853
            "yyyy-MM-dd HH:mm:ss.SSSSSS",     // e.g., 2025-10-07 06:36:20.927853
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss.SSS",
            // Plain seconds without timezone
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",   // 2024-10-18T12:34:56+00:00
            "yyyy-MM-dd HH:mm:ssXXXXX",    // 2024-10-18 12:34:56+00:00
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",  // 2024-10-18T12:34:56+00:00 (alt)
            "yyyy-MM-dd HH:mm:ssZZZZZ",     // 2024-10-18 12:34:56+00:00 (alt)
            "yyyy-MM-dd'T'HH:mm:ssZ",       // 2024-10-18T12:34:56Z or +0000
            "yyyy-MM-dd HH:mm:ssZ",        // 2024-10-18 12:34:56Z or +0000
            "yyyy-MM-dd"                    // 2024-10-18
        ]

        for format in candidates {
            df.dateFormat = format
            if let d = df.date(from: dateAdded) {
                return d
            }
        }

        return nil
    }
}
