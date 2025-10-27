//
//  SavingsReportComponents.swift
//  CouponManagerApp
//
//  Reusable view components for SavingsReportView
//

import SwiftUI

// MARK: - Company Breakdown Row (Original Design)
struct CompanyBreakdownRow: View {
    let companyData: CompanySavings
    
    var body: some View {
        VStack(spacing: 8) {
            // Header row with company name
            HStack {
                Text("\(companyData.totalCoupons)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("קופונים:")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(companyData.company)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            // Values row
            HStack {
                Text("₪\(Int(companyData.totalSavings))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                
                if companyData.totalSavings > 0 {
                    Text("(\(String(format: "%.0f", (companyData.totalSavings / max(companyData.totalValue + companyData.totalSavings, 1)) * 100))%)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Text("(₪\(Int(companyData.totalValue)) ערך זמין)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appBlue)
                }
                
                Spacer()
                
                Text("סך הכסף:")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Statistic Item Component
struct StatisticItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mini Stat Card (web‑like)
struct MiniStatCard: View {
  let title: String
  let value: String
  let description: String
  
  var body: some View {
    VStack(spacing: 6) {
      Text(title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(Color.appBlue)
        .multilineTextAlignment(.center)
      Text(value)
        .font(.system(size: 24, weight: .bold))
        .foregroundColor(.primary)
        .multilineTextAlignment(.center)
      Text(description)
        .font(.system(size: 12))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(16)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .overlay(
      Rectangle()
        .fill(Color.appBlue)
        .frame(width: 4)
        .cornerRadius(2)
      , alignment: .trailing
    )
    .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
  }
}

// MARK: - Legend Dot
struct LegendDot: View {
  let color: Color
  let text: String
  
  var body: some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 10, height: 10)
      Text(text)
    }
  }
}

