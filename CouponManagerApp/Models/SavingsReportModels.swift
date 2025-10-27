//
//  SavingsReportModels.swift
//  CouponManagerApp
//
//  Shared models for SavingsReportView
//

import Foundation

struct CompanySavings {
    let company: String
    let totalSavings: Double
    let totalValue: Double
    let activeCoupons: Int
    let usedCoupons: Int
    let totalCoupons: Int
}

struct SavingsStatistics {
    let totalSavings: Double
    let totalValue: Double
    let totalCoupons: Int
    let activeCoupons: Int
    let usedCoupons: Int
    let utilizationRate: Double
    let averageSavingsPerCoupon: Double
}

enum TimeframeFilter: CaseIterable {
    case thisMonth, thisYear, allTime, customRange
    
    // Keep only the three primary options visible in the UI
    static var allCases: [TimeframeFilter] { [.thisMonth, .thisYear, .allTime] }
    
    var displayName: String {
        switch self {
        case .thisMonth: return "החודש"
        case .thisYear: return "השנה"
        case .allTime: return "כל הזמן"
        case .customRange: return "טווח מותאם"
        }
    }
}
