-- Debug queries for Carrefour coupon (ID should be around 732 based on the URL)

-- 1. Find the exact coupon
SELECT id, code, company, value, used_value, user_id 
FROM coupon 
WHERE company ILIKE '%carrefour%' 
ORDER BY id DESC 
LIMIT 5;

-- 2. Check coupon_usage table
SELECT * 
FROM coupon_usage 
WHERE coupon_id IN (
    SELECT id FROM coupon WHERE company ILIKE '%carrefour%' ORDER BY id DESC LIMIT 5
)
ORDER BY timestamp DESC;

-- 3. Check coupon_transaction table  
SELECT * 
FROM coupon_transaction 
WHERE coupon_id IN (
    SELECT id FROM coupon WHERE company ILIKE '%carrefour%' ORDER BY id DESC LIMIT 5
)
ORDER BY transaction_date DESC;

-- 4. Test the function directly with coupon ID 732
SELECT * FROM get_consolidated_transactions(732);

-- 5. Check if the function exists
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name = 'get_consolidated_transactions';