//
//  FilterSheetView.swift
//  CouponManagerApp
//
//  מסך סינון וסידור קופונים
//

import SwiftUI

struct FilterSheetView: View {
    @Binding var selectedFilter: CouponFilter
    @Binding var selectedSort: CouponSort
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Section
                filterSection
                
                Divider()
                    .padding(.vertical)
                
                // Sort Section
                sortSection
                
                Spacer()
                
                // Apply Button
                applyButton
            }
            .padding()
            .navigationTitle("סינון וסידור")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ביטול") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("איפוס") {
                        selectedFilter = .all
                        selectedSort = .dateAdded
                    }
                }
            }
        }
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("סינון לפי סטטוס")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(CouponFilter.allCases, id: \.self) { filter in
                    FilterOptionRow(
                        title: filter.displayName,
                        icon: filterIcon(for: filter),
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
        }
    }
    
    // MARK: - Sort Section
    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("סדר לפי")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(CouponSort.allCases, id: \.self) { sort in
                    FilterOptionRow(
                        title: sort.displayName,
                        icon: sortIcon(for: sort),
                        isSelected: selectedSort == sort
                    ) {
                        selectedSort = sort
                    }
                }
            }
        }
    }
    
    // MARK: - Apply Button
    private var applyButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Text("החל")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appBlue)
                .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Functions
    private func filterIcon(for filter: CouponFilter) -> String {
        switch filter {
        case .all:
            return "list.bullet"
        case .active:
            return "checkmark.circle.fill"
        case .expired:
            return "exclamationmark.triangle.fill"
        case .fullyUsed:
            return "checkmark.circle"
        case .forSale:
            return "tag.fill"
        }
    }
    
    private func sortIcon(for sort: CouponSort) -> String {
        switch sort {
        case .dateAdded:
            return "calendar.badge.plus"
        case .expiration:
            return "calendar.badge.exclamationmark"
        case .value:
            return "dollarsign.circle.fill"
        case .remainingValue:
            return "banknote.fill"
        case .company:
            return "building.2.fill"
        }
    }
}

// MARK: - Filter Option Row
struct FilterOptionRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? Color.appBlue : .secondary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appBlue)
                }
            }
            .padding()
            .background(isSelected ? Color.appBlue.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.appBlue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    FilterSheetView(
        selectedFilter: .constant(.all),
        selectedSort: .constant(.dateAdded)
    )
}