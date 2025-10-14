-- בדיקת מבנה הטבלאות
-- הרץ את זה כדי לראות את המבנה הנכון

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

-- בדיקת users קיימים
SELECT * FROM users LIMIT 5;

-- בדיקת קופונים קיימים
SELECT COUNT(*) as total_coupons FROM coupon;
SELECT COUNT(*) as total_companies FROM companies;

-- בדיקת user IDs שיש להם קופונים
SELECT DISTINCT user_id, COUNT(*) as coupon_count 
FROM coupon 
GROUP BY user_id 
ORDER BY coupon_count DESC 
LIMIT 10;
