//
//  CompanyQuickAddCard.swift
//  CouponManagerApp
//
//  כרטיס הוספת קופון מהירה לחברה
//

import SwiftUI

struct CompanyQuickAddCard: View {
    let company: Company
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            // Show only logo if available, otherwise show only company name
            AsyncImage(url: imageURL) { image in
                // Show only the logo when loaded successfully
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } placeholder: {
                // Show only company name when no logo available
                VStack {
                    Text(company.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 70, height: 70)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var imageURL: URL? {
        // Convert the image path to a URL for the server
        let baseURL = "https://www.couponmasteril.com/static/"
        return URL(string: baseURL + company.imagePath)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Company with logo
        CompanyQuickAddCard(company: Company(id: 1, name: "Carrefour", imagePath: "company_logos/carrefour.png", companyCount: 5)) {
            print("Tapped")
        }
        
        // Company without logo (fallback to name)
        CompanyQuickAddCard(company: Company(id: 2, name: "Test Company", imagePath: "invalid/path.png", companyCount: 0)) {
            print("Tapped")
        }
    }
    .frame(width: 100)
}