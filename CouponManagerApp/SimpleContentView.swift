//
//  SimpleContentView.swift
//  CouponManagerApp
//
//  Simple version for testing
//

import SwiftUI

struct SimpleContentView: View {
    @State private var userData: String = "טוען..."
    @State private var isLoading = true
    @State private var passwordInput: String = ""
    @State private var passwordResult: String = ""
    @State private var currentUser: User?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("מנהל קופונים")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("מתחבר ל-Supabase...")
                            .padding(.top)
                    }
                } else {
                    ScrollView {
                        Text(userData)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .textSelection(.enabled)
                    }
                }
                
                Button("טען מחדש") {
                    loadData()
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                // Password verification section
                if currentUser != nil {
                    Divider()
                    
                    VStack(spacing: 15) {
                        Text("🔐 בדיקת סיסמה")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        SecureField("הכנס את הסיסמה שלך", text: $passwordInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                checkPassword()
                            }
                        
                        Button("בדוק סיסמה") {
                            checkPassword()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(passwordInput.isEmpty)
                        
                        if !passwordResult.isEmpty {
                            Text(passwordResult)
                                .padding()
                                .background(passwordResult.contains("✅") ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                .cornerRadius(10)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .navigationTitle("קופונים")
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        isLoading = true
        
        let apiClient = APIClient()
        apiClient.fetchUser { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let users):
                    if let user = users.first {
                        self.currentUser = user
                        userData = """
                        ✅ התחברות ל-Supabase הצליחה!
                        
                        📋 פרטי משתמש:
                        ID: \(user.id)
                        אימייל: \(user.email)
                        שם: \(user.firstName ?? "לא מוגדר") \(user.lastName ?? "לא מוגדר")
                        גיל: \(user.age?.description ?? "לא מוגדר")
                        מנהל: \(user.isAdmin ? "כן" : "לא")
                        קופונים: \(user.slots)
                        
                        🔐 Hash: \(String((user.password ?? "").prefix(50)))...
                        """
                    } else {
                        userData = "❌ לא נמצא משתמש עם ID=1"
                    }
                case .failure(let error):
                    userData = "❌ שגיאה: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func checkPassword() {
        guard let user = currentUser else {
            passwordResult = "❌ אין משתמש לבדיקה"
            return
        }
        
        print("🔍 Testing password: '\(passwordInput)' against hash")
        
        let isValid = PasswordManager.checkPassword(passwordInput, againstHash: user.password)
        
        if isValid {
            passwordResult = "✅ הסיסמה נכונה! זה אכן הסיסמה שלך."
        } else {
            passwordResult = "❌ הסיסמה שגויה. נסה שוב."
        }
        
        // נקה את השדה לאחר הבדיקה
        passwordInput = ""
    }
}

#Preview {
    SimpleContentView()
}