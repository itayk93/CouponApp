-- Debug Query for Savings Report Issue (על מה חסכת)
-- This query helps identify why savings data is not showing up

-- ==================================================
-- 1. CHECK USER AUTHENTICATION
-- ==================================================
-- First, check if you're properly authenticated
SELECT 
    auth.uid() as current_user_id,
    auth.jwt() ->> 'sub' as jwt_user_id;

-- ==================================================
-- 2. CHECK TOTAL COUPON COUNT
-- ==================================================
-- Check how many total coupons the user has
SELECT 
    COUNT(*) as total_coupons,
    COUNT(CASE WHEN is_for_sale = false THEN 1 END) as not_for_sale_coupons,
    COUNT(CASE WHEN exclude_saving = false THEN 1 END) as savings_eligible_coupons,
    COUNT(CASE WHEN is_for_sale = false AND exclude_saving = false THEN 1 END) as savings_report_coupons
FROM coupon 
WHERE user_id::text = auth.uid()::text;

-- ==================================================
-- 3. CHECK SAVINGS CALCULATION FIELDS
-- ==================================================
-- Check the key fields used for savings calculation
SELECT 
    id,
    company,
    value,
    cost,
    used_value,
    is_for_sale,
    exclude_saving,
    status,
    date_added,
    -- Calculated savings (same logic as in the iOS app)
    CASE 
        WHEN cost > 0 THEN GREATEST(0, value - cost)
        ELSE used_value
    END as calculated_savings
FROM coupon 
WHERE user_id::text = auth.uid()::text
    AND is_for_sale = false 
    AND exclude_saving = false
ORDER BY date_added DESC
LIMIT 10;

-- ==================================================
-- 4. CHECK AGGREGATE SAVINGS BY COMPANY
-- ==================================================
-- This mimics the exact logic used in the iOS app
SELECT 
    company,
    COUNT(*) as total_coupons,
    SUM(CASE 
        WHEN cost > 0 THEN GREATEST(0, value - cost)
        ELSE used_value
    END) as total_savings,
    SUM(value - used_value) as total_remaining_value,
    SUM(CASE WHEN used_value > 0 THEN 1 ELSE 0 END) as used_coupons_count,
    AVG(CASE 
        WHEN cost > 0 THEN GREATEST(0, value - cost)
        ELSE used_value
    END) as avg_savings_per_coupon
FROM coupon 
WHERE user_id::text = auth.uid()::text
    AND is_for_sale = false 
    AND exclude_saving = false
GROUP BY company
ORDER BY total_savings DESC;

-- ==================================================
-- 5. CHECK DATE FILTERING (THIS MONTH)
-- ==================================================
-- Check coupons added this month (same logic as iOS app)
SELECT 
    company,
    COUNT(*) as coupons_this_month,
    SUM(CASE 
        WHEN cost > 0 THEN GREATEST(0, value - cost)
        ELSE used_value
    END) as savings_this_month
FROM coupon 
WHERE user_id::text = auth.uid()::text
    AND is_for_sale = false 
    AND exclude_saving = false
    AND DATE_TRUNC('month', date_added::date) = DATE_TRUNC('month', CURRENT_DATE)
GROUP BY company
ORDER BY savings_this_month DESC;

-- ==================================================
-- 6. IDENTIFY POTENTIAL ISSUES
-- ==================================================
-- Check for common issues that prevent savings from showing
SELECT 
    'Issue Analysis' as analysis_type,
    COUNT(*) as total_user_coupons,
    COUNT(CASE WHEN is_for_sale = true THEN 1 END) as for_sale_coupons,
    COUNT(CASE WHEN exclude_saving = true THEN 1 END) as excluded_from_savings,
    COUNT(CASE WHEN cost = 0 AND used_value = 0 THEN 1 END) as zero_savings_coupons,
    COUNT(CASE WHEN is_for_sale = false AND exclude_saving = false 
              AND (cost > 0 OR used_value > 0) THEN 1 END) as valid_savings_coupons
FROM coupon 
WHERE user_id::text = auth.uid()::text;

-- ==================================================
-- 7. CHECK RLS POLICIES EFFECTIVENESS
-- ==================================================
-- This should return the same results as the direct query above
-- If it returns different results, there might be an RLS issue
SELECT 
    'RLS Policy Test' as test_type,
    COUNT(*) as accessible_coupons
FROM coupon
-- No WHERE clause - this tests if RLS is working properly
-- Should only return coupons for the authenticated user
;