//
//  SupabaseConfig.swift
//  CouponManagerApp
//
//  Created by itay karkason on 20/09/2025.
//

import Foundation

struct SupabaseConfig {
    // פרטי Supabase נטענים מקובץ התצורה הבטוח
    static let url = Secrets.supabaseURL
    static let anonKey = Secrets.supabaseAnonKey
}

// MARK: - הערה לפיתוח עתידי
/*
בגירסה מתקדמת יותר, כדאי להעביר את הערכים ל-environment variables
או לקובץ configuration נפרד שלא מועלה לגיט.

לעת עתה, זה עובד מצוין לבדיקה והפיתוח הראשוני.
*/
