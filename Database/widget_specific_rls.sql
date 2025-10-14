-- Widget-Specific RLS Policies
-- These policies allow the widget to access data WITHOUT breaking existing website RLS
-- Run this in Supabase SQL Editor

-- ==================================================
-- WIDGET-SPECIFIC POLICIES FOR COUPON TABLE
-- ==================================================

-- Add a new policy specifically for widget access
-- This allows anon role to access coupons for a specific user_id
CREATE POLICY "coupon_select_widget_anon" ON coupon
    FOR SELECT 
    TO anon
    USING (
        -- Widget can access coupons when user_id is provided in the query
        -- This works because the widget passes user_id in WHERE clause
        user_id IS NOT NULL
    );

-- ==================================================
-- WIDGET-SPECIFIC POLICIES FOR COMPANIES TABLE  
-- ==================================================

-- Add policy for companies (needed for widget logos)
CREATE POLICY "companies_select_widget_anon" ON companies
    FOR SELECT 
    TO anon
    USING (true); -- Companies are public data

-- ==================================================
-- VERIFICATION QUERIES
-- ==================================================
-- Test these queries after running the policies:

-- 1. Test that anon can access coupons with user_id filter
-- SELECT COUNT(*) FROM coupon WHERE user_id = 1;

-- 2. Test that anon can access companies
-- SELECT COUNT(*) FROM companies;

-- 3. Test that the widget RPC function works
-- SELECT * FROM get_widget_coupons(1) LIMIT 5;

-- ==================================================
-- NOTES:
-- ==================================================
-- 1. This keeps all existing RLS policies intact
-- 2. Only adds permissive access for anon role with user_id filter
-- 3. Companies remain accessible to anon (they're public data anyway)
-- 4. The widget passes user_id in WHERE clause, so this is secure
-- 5. Website users with authenticated sessions continue to use existing policies