-- בדיקת Widget מעודכנת
-- הרץ את זה אחרי שתקן את הפונקציות

-- ==================================================
-- 1. בדיקת מבנה הטבלאות
-- ==================================================

-- בדיקת מבנה טבלת users
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- בדיקת מבנה טבלת coupon
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'coupon' 
ORDER BY ordinal_position;

-- בדיקת מבנה טבלת companies
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'companies' 
ORDER BY ordinal_position;

-- ==================================================
-- 2. בדיקת נתונים קיימים
-- ==================================================

-- בדיקת users קיימים
SELECT * FROM users LIMIT 5;

-- בדיקת user IDs שיש להם קופונים
SELECT DISTINCT user_id, COUNT(*) as coupon_count 
FROM coupon 
GROUP BY user_id 
ORDER BY coupon_count DESC 
LIMIT 10;

-- בדיקת קופונים קיימים
SELECT COUNT(*) as total_coupons FROM coupon;
SELECT COUNT(*) as total_companies FROM companies;

-- ==================================================
-- 3. בדיקת הפונקציות החדשות
-- ==================================================

-- בדוק שהפונקציות נוצרו
SELECT routine_name, routine_type, data_type
FROM information_schema.routines 
WHERE routine_name IN ('get_widget_coupons', 'get_widget_companies');

-- בדוק הרשאות
SELECT routine_name, grantee, privilege_type
FROM information_schema.routine_privileges 
WHERE routine_name IN ('get_widget_coupons', 'get_widget_companies')
AND grantee = 'anon';

-- ==================================================
-- 4. בדיקת הפונקציות עם נתונים אמיתיים
-- ==================================================

-- מצא user ID שיש לו קופונים
SELECT user_id, COUNT(*) as coupon_count 
FROM coupon 
GROUP BY user_id 
HAVING COUNT(*) > 0
ORDER BY coupon_count DESC 
LIMIT 1;

-- השתמש ב-user ID שמצאת למעלה (החלף X ב-ID האמיתי)
-- SELECT * FROM get_widget_coupons(X) LIMIT 5;

-- בדיקת חברות
SELECT * FROM get_widget_companies() LIMIT 10;

-- ==================================================
-- 5. בדיקה ישירה של הנתונים
-- ==================================================

-- בדיקה ישירה של קופונים (החלף X ב-user ID אמיתי)
-- SELECT 
--     c.id,
--     c.code,
--     c.company,
--     c.value,
--     c.status,
--     c.user_id
-- FROM coupon c
-- WHERE c.user_id = X  -- החלף X ב-user ID אמיתי
-- ORDER BY c.date_added DESC
-- LIMIT 5;

-- בדיקה ישירה של חברות
SELECT * FROM companies LIMIT 10;

-- ==================================================
-- 6. בדיקת RLS
-- ==================================================

-- בדוק אם RLS מופעל
SELECT schemaname, tablename, rowsecurity
FROM pg_tables 
WHERE tablename IN ('coupon', 'companies', 'users')
ORDER BY tablename;

-- בדוק מדיניות RLS קיימות
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename IN ('coupon', 'companies', 'users')
ORDER BY tablename, policyname;
