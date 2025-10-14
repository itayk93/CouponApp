//
//  APIClient.swift
//  CouponManagerApp
//
//  Created by itay karkason on 20/09/2025.
//

import Foundation

class APIClient {
    // השתמש בקונפיגורציה מהקובץ הנפרד
    private let supabaseURL = SupabaseConfig.url
    private let supabaseKey = SupabaseConfig.anonKey
    
    func fetchUser(completion: @escaping (Result<[User], Error>) -> Void) {
        // יוצר URL לשליפה מטבלת users ב-Supabase - משתמש עם ID=1
        guard let url = URL(string: "\(supabaseURL)/rest/v1/users?id=eq.1&select=*") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        print("🔗 Connecting to: \(url.absoluteString)")
        print("🔑 Using key: \(String(supabaseKey.prefix(20)))...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(URLError(.badServerResponse)))
                }
                return
            }
            
            // הדפסה לבדיקה
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Status Code: \(httpResponse.statusCode)")
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📨 Response from Supabase: \(jsonString)")
                print("📏 Response length: \(data.count) bytes")
            }
            
            do {
                let users = try JSONDecoder().decode([User].self, from: data)
                DispatchQueue.main.async {
                    completion(.success(users))
                }
            } catch {
                print("Decoding error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}