-- תיקון ה-RPC Functions ל-Widget
-- הרץ את זה אחרי שתבדוק את מבנה הטבלאות

-- ==================================================
-- 1. מחיקת הפונקציות הקיימות
-- ==================================================
DROP FUNCTION IF EXISTS get_widget_coupons(INTEGER);
DROP FUNCTION IF EXISTS get_widget_companies();

-- ==================================================
-- 2. יצירת פונקציה חדשה לקופונים (מעודכנת)
-- ==================================================
CREATE OR REPLACE FUNCTION get_widget_coupons(p_user_id INTEGER)
RETURNS TABLE (
    id INTEGER,
    code TEXT,
    description TEXT,
    value DOUBLE PRECISION,
    cost DOUBLE PRECISION,
    company TEXT,
    expiration DATE,
    date_added TIMESTAMP WITH TIME ZONE,
    used_value DOUBLE PRECISION,
    status TEXT,
    is_one_time BOOLEAN,
    user_id INTEGER
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validate that the user exists
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Return coupons for this specific user only
    RETURN QUERY
    SELECT 
        c.id,
        c.code,
        c.description,
        c.value,
        c.cost,
        c.company,
        c.expiration,
        c.date_added,
        COALESCE(cu.used_value, 0) as used_value,
        c.status,
        c.is_one_time,
        c.user_id
    FROM coupon c
    LEFT JOIN (
        SELECT 
            coupon_id,
            SUM(value_used) as used_value
        FROM coupon_usage 
        GROUP BY coupon_id
    ) cu ON c.id = cu.coupon_id
    WHERE c.user_id = p_user_id
    ORDER BY c.date_added DESC;
END;
$$;

-- ==================================================
-- 3. יצירת פונקציה חדשה לחברות (מעודכנת)
-- ==================================================
CREATE OR REPLACE FUNCTION get_widget_companies()
RETURNS TABLE (
    id INTEGER,
    name CHARACTER VARYING,  -- שינוי מ-TEXT ל-VARCHAR
    image_path CHARACTER VARYING,  -- שינוי מ-TEXT ל-VARCHAR
    company_count BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Return all companies with coupon counts
    RETURN QUERY
    SELECT 
        c.id,
        c.name,
        c.image_path,
        COUNT(coupon.id) as company_count
    FROM companies c
    LEFT JOIN coupon ON c.name = coupon.company
    GROUP BY c.id, c.name, c.image_path
    ORDER BY company_count DESC, c.name;
END;
$$;

-- ==================================================
-- 4. הרשאות
-- ==================================================
GRANT EXECUTE ON FUNCTION get_widget_coupons(INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION get_widget_companies() TO anon;

-- ==================================================
-- 5. בדיקה
-- ==================================================
-- בדוק שהפונקציות נוצרו
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name IN ('get_widget_coupons', 'get_widget_companies');

-- בדוק הרשאות
SELECT routine_name, grantee, privilege_type
FROM information_schema.routine_privileges 
WHERE routine_name IN ('get_widget_coupons', 'get_widget_companies')
AND grantee = 'anon';
