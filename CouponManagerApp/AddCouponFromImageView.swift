//
//  AddCouponFromImageView.swift
//  CouponManagerApp
//
//  מסך הוספת קופון מתמונה עם ניתוח GPT Vision
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct AddCouponFromImageView: View {
    let user: User
    let companies: [Company]
    let onCouponAdded: () -> Void
    
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isAnalyzing = false
    @State private var analysisResult: CouponExtractionResult?
    @State private var showingManualEntry = false
    @State private var showingAddCouponView = false
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    
    // Manual entry fields
    @State private var manualCode = ""
    @State private var manualDescription = ""
    @State private var manualValue = ""
    @State private var manualCompany = ""
    @State private var manualExpiration = Date()
    @State private var manualCost = ""
    
    private let openAIClient = OpenAIClient(apiKey: Config.openAIAPIKey)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    if !showingManualEntry {
                        // Image Selection Section
                        imageSelectionSection
                        
                        // Selected Image Display
                        if let image = selectedImage {
                            selectedImageSection(image)
                        }
                        
                        // מסך תוצאות הניתוח הוסר - מעבר ישיר לעריכה ידנית
                        
                        // Action Buttons
                        actionButtonsSection
                    } else {
                        // Manual Entry Form
                        manualEntrySection
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("הוספת קופון מתמונה")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ביטול") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if showingManualEntry {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("שמור") {
                            saveManualCoupon()
                        }
                        .disabled(!isManualFormValid)
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            GPTImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingCamera) {
            GPTImagePicker(image: $selectedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingAddCouponView) {
            AddCouponView(
                user: user,
                companies: companies,
                onCouponAdded: {
                    onCouponAdded()
                    presentationMode.wrappedValue.dismiss()
                },
                prefilledData: analysisResult
            )
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40))
                .foregroundColor(Color.appBlue)
            
            Text("צלם או בחר תמונה של הקופון")
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("המערכת תנתח את התמונה ותמלא את הפרטים אוטומטית")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Image Selection Section
    private var imageSelectionSection: some View {
        VStack(spacing: 16) {
            Text("בחר תמונה")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                // Camera Button
                Button(action: { showingCamera = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("מצלמה")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appBlue)
                    .cornerRadius(12)
                }
                
                // Photo Library Button
                Button(action: { showingImagePicker = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(.title2)
                        Text("גלריה")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Selected Image Section
    private func selectedImageSection(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("תמונה שנבחרה")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
                
                Spacer()
                
                Button("החלף תמונה") {
                    selectedImage = nil
                    analysisResult = nil
                    errorMessage = nil
                }
                .font(.caption)
                .foregroundColor(Color.appBlue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Analysis Result Section
    private func analysisResultSection(_ result: CouponExtractionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("תוצאות הניתוח")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("ערוך ידנית") {
                    populateManualFields(from: result)
                    showingManualEntry = true
                }
                .font(.caption)
                .foregroundColor(Color.appBlue)
            }
            
            VStack(spacing: 12) {
                if let code = result.code {
                    resultRow(title: "קוד:", value: code)
                }
                
                if let description = result.description {
                    resultRow(title: "תיאור:", value: description)
                }
                
                if let value = result.value {
                    resultRow(title: "ערך:", value: "₪\(Int(value))")
                }
                
                if let company = result.company {
                    resultRow(title: "חברה:", value: company)
                }
                
                if let expiration = result.expiration {
                    resultRow(title: "תפוגה:", value: formatDate(expiration))
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func resultRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: analyzeImage) {
                HStack {
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isAnalyzing ? "מנתח..." : "נתח עם GPT Vision")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedImage == nil ? Color.gray : Color.appBlue)
                .cornerRadius(12)
            }
            .disabled(selectedImage == nil || isAnalyzing)
            
            Button("הוספה ידנית") {
                showingAddCouponView = true
            }
            .foregroundColor(Color.appBlue)
        }
    }
    
    // MARK: - Manual Entry Section
    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("הוספה ידנית")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                formField(title: "קוד קופון", text: $manualCode, placeholder: "לדוגמה: SAVE20")
                formField(title: "תיאור", text: $manualDescription, placeholder: "תיאור הקופון")
                formField(title: "ערך (₪)", text: $manualValue, placeholder: "100", keyboardType: .decimalPad)
                formField(title: "חברה", text: $manualCompany, placeholder: "שם החברה")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("תאריך תפוגה")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    DatePicker("", selection: $manualExpiration, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .environment(\.locale, Locale(identifier: "he"))
                }
                
                formField(title: "עלות (₪) - אופציונלי", text: $manualCost, placeholder: "80", keyboardType: .decimalPad)
            }
            
            HStack(spacing: 12) {
                Button("ביטול") {
                    showingManualEntry = false
                    clearManualFields()
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                
                Button("שמור") {
                    saveManualCoupon()
                }
                .disabled(!isManualFormValid)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isManualFormValid ? Color.green : Color.gray)
                .cornerRadius(12)
            }
        }
    }
    
    private func formField(title: String, text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
            
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    // MARK: - Helper Properties
    private var isManualFormValid: Bool {
        !manualCode.isEmpty && !manualDescription.isEmpty && !manualValue.isEmpty && !manualCompany.isEmpty
    }
    
    // MARK: - Helper Functions
    private func analyzeImage() {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await openAIClient.extractCouponFromImageWithTracking(imageData, companies: companies)
                
                await MainActor.run {
                    self.analysisResult = result
                    self.isAnalyzing = false
                    
                    // מעבר לטופס הרגיל עם הפרטים שזוהו
                    self.showingAddCouponView = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "שגיאה בניתוח התמונה: \(error.localizedDescription)"
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func saveCouponFromAnalysis() {
        guard let result = analysisResult else { return }
        
        // Create coupon from analysis result
        let coupon = createCouponFromResult(result)
        saveCoupon(coupon)
    }
    
    private func saveManualCoupon() {
        let coupon = Coupon(
            id: 0,
            code: manualCode,
            description: manualDescription,
            value: Double(manualValue) ?? 0,
            cost: Double(manualCost) ?? 0,
            company: manualCompany,
            expiration: formatDateForAPI(manualExpiration),
            source: "manual_image",
            buyMeCouponUrl: nil,
            straussCouponUrl: nil,
            xgiftcardCouponUrl: nil,
            xtraCouponUrl: nil,
            dateAdded: ISO8601DateFormatter().string(from: Date()),
            usedValue: 0,
            status: "פעיל",
            isAvailable: true,
            isForSale: false,
            isOneTime: false,
            purpose: nil,
            excludeSaving: false,
            autoDownloadDetails: nil,
            userId: user.id,
            cvv: nil,
            cardExp: nil
        )
        
        saveCoupon(coupon)
    }
    
    private func saveCoupon(_ coupon: Coupon) {
        // TODO: Implement actual API call to save coupon
        print("Saving coupon: \(coupon)")
        onCouponAdded()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func createCouponFromResult(_ result: CouponExtractionResult) -> Coupon {
        return Coupon(
            id: 0,
            code: result.code ?? "",
            description: result.description ?? "",
            value: result.value ?? 0,
            cost: 0,
            company: result.company ?? "",
            expiration: result.expiration ?? "",
            source: result.source ?? "gpt_image",
            buyMeCouponUrl: nil,
            straussCouponUrl: nil,
            xgiftcardCouponUrl: nil,
            xtraCouponUrl: nil,
            dateAdded: ISO8601DateFormatter().string(from: Date()),
            usedValue: 0,
            status: "פעיל",
            isAvailable: true,
            isForSale: false,
            isOneTime: false,
            purpose: nil,
            excludeSaving: false,
            autoDownloadDetails: nil,
            userId: user.id,
            cvv: nil,
            cardExp: nil
        )
    }
    
    private func populateManualFields(from result: CouponExtractionResult) {
        manualCode = result.code ?? ""
        manualDescription = result.description ?? ""
        manualValue = result.value != nil ? String(Int(result.value!)) : ""
        manualCompany = result.company ?? ""
        
        if let expiration = result.expiration {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            manualExpiration = formatter.date(from: expiration) ?? Date()
        }
    }
    
    private func clearManualFields() {
        manualCode = ""
        manualDescription = ""
        manualValue = ""
        manualCompany = ""
        manualExpiration = Date()
        manualCost = ""
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: date)
        }
        
        return dateString
    }
    
    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Image Picker for GPT Analysis
struct GPTImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: GPTImagePicker
        
        init(_ parent: GPTImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    AddCouponFromImageView(
        user: User(
            id: 1,
            email: "test@example.com",
            password: nil,
            firstName: "Test",
            lastName: "User",
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
            faceIdEnabled: false
        ),
        companies: [
            Company(id: 13, name: "Wolt", imagePath: "Wolt.png", companyCount: 0),
            Company(id: 16, name: "מקדונלדס", imagePath: "McDonalds.png", companyCount: 5)
        ],
        onCouponAdded: {
            print("Coupon added")
        }
    )
}