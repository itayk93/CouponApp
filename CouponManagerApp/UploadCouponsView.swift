//
//  UploadCouponsView.swift
//  CouponManagerApp
//
//  מסך העלאת קובץ קופונים
//

import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct UploadCouponsView: View {
    let user: User
    let companies: [Company]
    let onUpdate: () -> Void
    
    @StateObject private var couponAPI = CouponAPIClient()
    @State private var isLoading = false
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String = ""
    @State private var showingInstructions = true
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top navigation buttons
                topNavigationBar
                
                // Title
                headerView
                
                // Action buttons
                actionButtonsRow
                
                // Template download button
                templateDownloadButton
                
                // Success/Error messages
                if !successMessage.isEmpty {
                    successMessageView
                }
                
                if !errorMessage.isEmpty {
                    errorMessageView
                }
                
                // File upload section
                fileUploadSection
                
                // Instructions panel
                if showingInstructions {
                    instructionsPanel
                }
                
                // Submit button
                if selectedFileURL != nil {
                    submitButtonView
                }
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showingFilePicker) {
            #if canImport(UIKit)
            DocumentPicker(
                allowedContentTypes: [.commaSeparatedText, .spreadsheet],
                onDocumentPicked: { url in
                    selectedFileURL = url
                    selectedFileName = url.lastPathComponent
                }
            )
            #else
            Text("File picker not available on this platform")
            #endif
        }
    }
    
    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Header
    private var headerView: some View {
        Text("העלאת קובץ קופונים")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(Color.appBlue)
            .multilineTextAlignment(.center)
    }
    
    // MARK: - Action Buttons Row
    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: AddCouponView(user: user, companies: companies, preSelectedCompany: nil, onCouponAdded: onUpdate)) {
                ActionButtonSmall(
                    title: "קופון יחיד",
                    icon: "plus.circle",
                    color: Color.appBlue
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: AddCouponsView(user: user, companies: [], onUpdate: onUpdate)) {
                ActionButtonSmall(
                    title: "קופונים מרובים",
                    icon: "list.bullet",
                    color: Color.appBlue
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Template Download Button
    private var templateDownloadButton: some View {
        Button(action: downloadTemplate) {
            HStack {
                Image(systemName: "arrow.down.doc")
                Text("הורדת תבנית קופונים")
                    .fontWeight(.medium)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.1))
            .foregroundColor(.green)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Success Message
    private var successMessageView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(successMessage)
                .foregroundColor(.green)
                .font(.subheadline)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Error Message
    private var errorMessageView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.subheadline)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - File Upload Section
    private var fileUploadSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("בחר קובץ קופונים")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("*")
                        .foregroundColor(.red)
                }
                
                Button(action: { showingFilePicker = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: selectedFileURL == nil ? "doc.badge.plus" : "doc.fill")
                            .font(.system(size: 40))
                            .foregroundColor(selectedFileURL == nil ? .gray : Color.appBlue)
                        
                        if selectedFileURL == nil {
                            VStack(spacing: 4) {
                                Text("לחץ לבחירת קובץ")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("או גרור קובץ לכאן")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            VStack(spacing: 4) {
                                Text("קובץ נבחר:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(selectedFileName)
                                    .font(.headline)
                                    .foregroundColor(Color.appBlue)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedFileURL == nil ? Color.gray.opacity(0.5) : Color.appBlue, 
                                  style: StrokeStyle(lineWidth: 2, dash: selectedFileURL == nil ? [10] : []))
                            .background(Color(.systemGray6).opacity(0.5))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // File format info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Color.appBlue)
                Text("פורמטים נתמכים: Excel (.xlsx, .xls), CSV (.csv)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Instructions Panel
    private var instructionsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: { showingInstructions.toggle() }) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Color.appBlue)
                        Text("איך להעלות קובץ קופונים?")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: showingInstructions ? "chevron.up" : "chevron.down")
                            .foregroundColor(Color.appBlue)
                    }
                }
            }
            
            if showingInstructions {
                VStack(alignment: .leading, spacing: 12) {
                    InstructionRow(number: 1, text: "הורד את תבנית הקופונים על ידי לחיצה על כפתור \"הורדת תבנית קופונים\".")
                    InstructionRow(number: 2, text: "מלא את התבנית עם פרטי הקופונים שלך (חברה, קוד, ערך, עלות, וכו').")
                    InstructionRow(number: 3, text: "שמור את הקובץ בפורמט Excel (.xlsx) או CSV (.csv).")
                    InstructionRow(number: 4, text: "לחץ על \"בחר קובץ\" והעלה את הקובץ שמילאת.")
                    InstructionRow(number: 5, text: "לחץ על \"העלאת הקובץ\" להוספת כל הקופונים לארנק שלך.")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("שדות חובה בתבנית:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• שם החברה")
                        Text("• קוד הקופון")
                        Text("• ערך הקופון")
                        Text("• עלות הקופון")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
                }
                .padding(.top, 8)
                
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                    Text("טיפ: השתמש בתבנית הרשמית כדי להבטיח שהקובץ יעלה בהצלחה.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Submit Button
    private var submitButtonView: some View {
        Button(action: uploadFile) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "icloud.and.arrow.up")
                }
                Text(isLoading ? "מעלה קובץ..." : "העלאת הקובץ")
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.appBlue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
    
    // MARK: - Helper Functions
    private func downloadTemplate() {
        // In a real app, you would download from your server
        // For now, we'll show a success message
        successMessage = "תבנית הקופונים הורדה בהצלחה"
        errorMessage = ""
        
        // Clear message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            successMessage = ""
        }
    }
    
    private func uploadFile() {
        guard let fileURL = selectedFileURL else { return }
        
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        // Simulate file upload
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            
            // For demo purposes, we'll simulate success
            if fileURL.pathExtension.lowercased() == "csv" || 
               fileURL.pathExtension.lowercased() == "xlsx" ||
               fileURL.pathExtension.lowercased() == "xls" {
                
                self.successMessage = "הקובץ הועלה בהצלחה! נוספו קופונים חדשים לארנק שלך."
                self.onUpdate()
                
                // Clear selection
                self.selectedFileURL = nil
                self.selectedFileName = ""
                
                // Auto dismiss after success
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.presentationMode.wrappedValue.dismiss()
                }
            } else {
                self.errorMessage = "פורמט קובץ לא נתמך. השתמש בקבצי Excel או CSV בלבד."
            }
        }
    }
}

// MARK: - Document Picker
#if canImport(UIKit)
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void
        
        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}
#endif

#Preview {
    NavigationView {
        UploadCouponsView(
            user: User(
                id: 1,
                email: "test@test.com",
                password: nil,
                firstName: "טסט",
                lastName: "יוזר",
                age: 30,
                gender: "male",
                region: nil,
                isConfirmed: true,
                isAdmin: false,
                slots: 5,
                slotsAutomaticCoupons: 50,
                createdAt: "2024-01-01T00:00:00Z",
                profileDescription: nil,
                profileImage: nil,
                couponsSoldCount: 0,
                isDeleted: false,
                dismissedExpiringAlertAt: nil,
                dismissedMessageId: nil,
                googleId: nil,
                newsletterSubscription: true,
                telegramMonthlySummary: true,
                newsletterImage: nil,
                showWhatsappBanner: false,
                faceIdEnabled: false,
                pushToken: nil
            ),
            companies: [
                Company(id: 13, name: "Wolt", imagePath: "Wolt.png", companyCount: 0),
                Company(id: 16, name: "מקדונלדס", imagePath: "McDonalds.png", companyCount: 5)
            ],
            onUpdate: {}
        )
    }
}