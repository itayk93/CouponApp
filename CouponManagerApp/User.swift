//
//  User.swift
//  CouponManagerApp
//
//  Created by itay karkason on 20/09/2025.
//

import Foundation

struct User: Codable {
    let id: Int
    let email: String
    let password: String?  // שונה ל-optional כי יכול להיות null
    let firstName: String?
    let lastName: String?
    let age: Int?
    let gender: String?
    let region: String?
    let isConfirmed: Bool
    let isAdmin: Bool
    let slots: Int
    let slotsAutomaticCoupons: Int
    let createdAt: String?
    let profileDescription: String?
    let profileImage: String?
    let couponsSoldCount: Int
    let isDeleted: Bool
    let dismissedExpiringAlertAt: String?
    let dismissedMessageId: Int?
    let googleId: String?
    let newsletterSubscription: Bool
    let telegramMonthlySummary: Bool
    let newsletterImage: String?
    let showWhatsappBanner: Bool
    let faceIdEnabled: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, email, password, age, gender, region, slots
        case firstName = "first_name"
        case lastName = "last_name"
        case isConfirmed = "is_confirmed"
        case isAdmin = "is_admin"
        case slotsAutomaticCoupons = "slots_automatic_coupons"
        case createdAt = "created_at"
        case profileDescription = "profile_description"
        case profileImage = "profile_image"
        case couponsSoldCount = "coupons_sold_count"
        case isDeleted = "is_deleted"
        case dismissedExpiringAlertAt = "dismissed_expiring_alert_at"
        case dismissedMessageId = "dismissed_message_id"
        case googleId = "google_id"
        case newsletterSubscription = "newsletter_subscription"
        case telegramMonthlySummary = "telegram_monthly_summary"
        case newsletterImage = "newsletter_image"
        case showWhatsappBanner = "show_whatsapp_banner"
        case faceIdEnabled = "face_id_enabled"
    }
}