-- Create RPC function for widget to get coupons
-- This function bypasses RLS and gets coupons for a specific user

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
SECURITY DEFINER -- This allows the function to bypass RLS
AS $$
BEGIN
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

-- Grant execute permission to anon role
GRANT EXECUTE ON FUNCTION get_widget_coupons(INTEGER) TO anon;

-- Test the function (replace with actual user ID)
-- SELECT * FROM get_widget_coupons(1);
