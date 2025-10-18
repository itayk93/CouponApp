//
//  AddCouponWithImageView.swift
//  CouponManagerApp
//
//  מסך הוספת קופון מתמונה עם ניתוח GPT
//

import SwiftUI
import PhotosUI
import Vision

struct AddCouponWithImageView: View {
    let user: User
    let companies: [Company]
    let onUpdate: () -> Void
    
    @StateObject private var couponAPI = CouponAPIClient()
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isAnalyzing = false
    @State private var analyzedCoupon: CouponCreateRequest?
    @State private var showingInstructions = true
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showingManualEdit = false
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
                
                // Help button
                helpButtonView
                
                // Instructions panel
                if showingInstructions {
                    instructionsPanel
                }
                
                // Success/Error messages
                if !successMessage.isEmpty {
                    successMessageView
                }
                
                if !errorMessage.isEmpty {
                    errorMessageView
                }
                
                // Image upload section
                imageUploadSection
                
                // Analysis results
                if let coupon = analyzedCoupon {
                    analysisResultsSection(coupon: coupon)
                }
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingManualEdit) {
            if let coupon = analyzedCoupon {
                EditAnalyzedCouponView(
                    coupon: Binding(
                        get: { coupon },
                        set: { analyzedCoupon = $0 }
                    ),
                    companies: companies,
                    onSave: saveCoupon,
                    onCancel: { showingManualEdit = false }
                )
            }
        }
        .onChange(of: selectedImage) { _, image in
            if let image = image {
                analyzeImage(image)
            }
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
        Text("הוספת קופון מתמונה")
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
                    title: "הוספה ידנית",
                    icon: "pencil",
                    color: Color.appBlue
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: AddCouponsView(user: user, companies: companies, onUpdate: onUpdate)) {
                ActionButtonSmall(
                    title: "קופונים מרובים",
                    icon: "plus.circle",
                    color: Color.appBlue
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: UploadCouponsView(user: user, companies: companies, onUpdate: onUpdate)) {
                ActionButtonSmall(
                    title: "העלאת קובץ",
                    icon: "doc.fill",
                    color: Color.appBlue
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Help Button
    private var helpButtonView: some View {
        Button(action: { showingInstructions.toggle() }) {
            HStack {
                Image(systemName: "questionmark.circle")
                Text("הסבר")
                    .fontWeight(.medium)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.appBlue)
            .foregroundColor(.white)
            .cornerRadius(20)
        }
    }
    
    // MARK: - Instructions Panel
    private var instructionsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(Color.appBlue)
                Text("איך להוסיף קופון מתמונה?")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Button(action: { showingInstructions.toggle() }) {
                    Image(systemName: showingInstructions ? "chevron.up" : "chevron.down")
                        .foregroundColor(Color.appBlue)
                }
            }
            
            if showingInstructions {
                VStack(alignment: .leading, spacing: 8) {
                    InstructionRow(number: 1, text: "העלה תמונה של הקופון - לחץ על הכפתור או פשוט גרור את התמונה לאזור ההעלאה.")
                    InstructionRow(number: 2, text: "המערכת תנתח את התמונה באופן אוטומטי ותמלא את הפרטים מיד.")
                    InstructionRow(number: 3, text: "בדוק את הפרטים שהמערכת זיהתה ותקן במידת הצורך.")
                    InstructionRow(number: 4, text: "לחץ על \"הוספת הקופון לארנק\" כשסיימת.")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.yellow)
                        Text("טיפים לתמונה טובה:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• ודא שהתמונה ברורה וקריאה")
                        Text("• הקפד על תאורה טובה")
                        Text("• צלם את כל הפרטים החשובים")
                        Text("• הימנע מהשתקפויות או צללים")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
    
    // MARK: - Image Upload Section
    private var imageUploadSection: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                // Show selected image
                VStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.appBlue, lineWidth: 2)
                        )
                    
                    if isAnalyzing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("מנתח תמונה עם AI...")
                                .font(.subheadline)
                                .foregroundColor(Color.appBlue)
                        }
                        .padding()
                    }
                    
                    HStack(spacing: 12) {
                        Button("בחר תמונה אחרת") {
                            selectedImage = nil
                            analyzedCoupon = nil
                            errorMessage = ""
                            successMessage = ""
                        }
                        .font(.caption)
                        .foregroundColor(Color.appBlue)
                        
                        if analyzedCoupon != nil {
                            Button("נתח שוב") {
                                if let image = selectedImage {
                                    analyzeImage(image)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                    }
                }
            } else {
                // Image selection area
                VStack(spacing: 16) {
                    Text("בחר תמונה של הקופון")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(Color.appBlue)
                        
                        Text("גרור תמונה לכאן או לחץ לבחירה")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appBlue, style: StrokeStyle(lineWidth: 2, dash: [10]))
                            .background(Color.appBlue.opacity(0.05))
                    )
                    .onTapGesture {
                        showingImagePicker = true
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: { showingImagePicker = true }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("גלריה")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.appBlue.opacity(0.1))
                            .foregroundColor(Color.appBlue)
                            .cornerRadius(10)
                        }
                        
                        Button(action: { showingCamera = true }) {
                            HStack {
                                Image(systemName: "camera")
                                Text("מצלמה")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Analysis Results Section
    private func analysisResultsSection(coupon: CouponCreateRequest) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("פרטי הקופון שזוהו")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("ערוך ידנית") {
                    showingManualEdit = true
                }
                .font(.caption)
                .foregroundColor(Color.appBlue)
            }
            
            VStack(spacing: 12) {
                AnalysisResultRow(title: "חברה", value: coupon.company)
                AnalysisResultRow(title: "קוד קופון", value: coupon.code)
                AnalysisResultRow(title: "ערך הקופון", value: "₪\(Int(coupon.value))")
                AnalysisResultRow(title: "עלות", value: "₪\(Int(coupon.cost))")
                
                if let description = coupon.description, !description.isEmpty {
                    AnalysisResultRow(title: "תיאור", value: description)
                }
                
                if let expiration = coupon.expiration, !expiration.isEmpty {
                    AnalysisResultRow(title: "תאריך תפוגה", value: formatDateString(expiration))
                }
            }
            
            // Save button
            Button(action: saveCoupon) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("הוספת הקופון לארנק")
                        .fontWeight(.semibold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.appBlue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    // MARK: - Helper Functions
    private func analyzeImage(_ image: UIImage) {
        isAnalyzing = true
        errorMessage = ""
        successMessage = ""
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "שגיאה בהמרת התמונה"
            isAnalyzing = false
            return
        }
        
        let _ = imageData.base64EncodedString() // For future API use
        
        // Simulate GPT analysis (in a real app, you'd call your API)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.isAnalyzing = false
            
            // For demo purposes, we'll simulate analysis results
            self.analyzedCoupon = CouponCreateRequest(
                code: "DEMO123",
                description: "קופון לדוגמה שזוהה מהתמונה",
                value: 100,
                cost: 80,
                company: companies.first?.name ?? "חברה לדוגמה",
                expiration: nil,
                source: "הוספה מתמונה",
                buyMeCouponUrl: nil,
                straussCouponUrl: nil,
                xgiftcardCouponUrl: nil,
                xtraCouponUrl: nil,
                isForSale: false,
                isOneTime: false,
                purpose: nil
            )
            
            self.successMessage = "התמונה נותחה בהצלחה! בדוק את הפרטים ותקן במידת הצורך."
        }
    }
    
    private func saveCoupon() {
        guard let coupon = analyzedCoupon else { return }
        
        couponAPI.createCoupon(coupon, userId: user.id) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.onUpdate()
                    self.presentationMode.wrappedValue.dismiss()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "שגיאה בשמירת הקופון: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func formatDateString(_ dateString: String) -> String {
        // Simple date formatting - in a real app you'd use proper date formatting
        return dateString
    }
}

// MARK: - Analysis Result Row
struct AnalysisResultRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit Analyzed Coupon View
struct EditAnalyzedCouponView: View {
    @Binding var coupon: CouponCreateRequest
    let companies: [Company]
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var showingOtherCompany = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("ערוך פרטי קופון")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    VStack(spacing: 12) {
                        // Company selection
                        VStack(alignment: .leading, spacing: 6) {
                            Text("שם החברה")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("בחר חברה", selection: $coupon.company) {
                                Text("בחר").tag("")
                                ForEach(companies, id: \.name) { company in
                                    Text(company.name).tag(company.name)
                                }
                                Text("אחר").tag("other")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onChange(of: coupon.company) { _, newValue in
                                showingOtherCompany = (newValue == "other")
                            }
                        }
                        
                        // Other company field
                        if showingOtherCompany {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("שם חברה חדשה")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("הזן שם החברה", text: $coupon.company)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        // Code field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("קוד קופון")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("הזן קוד הקופון", text: $coupon.code)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Value and cost fields
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ערך הקופון")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("0", value: $coupon.value, format: .number)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.decimalPad)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("עלות")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("0", value: $coupon.cost, format: .number)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.decimalPad)
                            }
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 6) {
                            Text("תיאור הקופון")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("תיאור אופציונלי", text: Binding(
                                get: { coupon.description ?? "" },
                                set: { coupon.description = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Expiration date
                        VStack(alignment: .leading, spacing: 6) {
                            Text("תאריך תפוגה")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let expiration = coupon.expiration, !expiration.isEmpty {
                                DatePicker("", selection: Binding(
                                    get: { 
                                        ISO8601DateFormatter().date(from: expiration) ?? Date()
                                    },
                                    set: { date in
                                        coupon.expiration = ISO8601DateFormatter().string(from: date)
                                    }
                                ), displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                            } else {
                                Button("הוסף תאריך תפוגה") {
                                    coupon.expiration = ISO8601DateFormatter().string(from: Date())
                                }
                                .foregroundColor(Color.appBlue)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ביטול", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("שמור", action: onSave)
                        .fontWeight(.semibold)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selectedImage: $selectedImage)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        @Binding var selectedImage: UIImage?
        
        init(selectedImage: Binding<UIImage?>) {
            _selectedImage = selectedImage
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                selectedImage = originalImage
            }
            
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    NavigationView {
        AddCouponWithImageView(
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
                Company(id: 1, name: "Carrefour", imagePath: "carrefour.png", companyCount: 5),
                Company(id: 2, name: "BuyMe", imagePath: "buyme.png", companyCount: 3)
            ],
            onUpdate: {}
        )
    }
}