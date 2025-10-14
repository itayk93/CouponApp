-- Create RPC function to calculate total remaining value for a user
-- This avoids loading all coupons into memory

CREATE OR REPLACE FUNCTION get_user_total_remaining(user_id_param integer)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_remaining numeric := 0;
BEGIN
    -- Calculate total remaining value for user's coupons
    -- Exclude coupons that are for sale or marked to exclude from savings
    SELECT COALESCE(SUM(GREATEST(value - used_value, 0)), 0)
    INTO total_remaining
    FROM coupon
    WHERE user_id = user_id_param
    AND (is_for_sale IS NULL OR is_for_sale = false)
    AND (exclude_saving IS NULL OR exclude_saving = false);
    
    RETURN total_remaining;
END;
$$;

-- Grant execute permission to anon and authenticated roles
GRANT EXECUTE ON FUNCTION get_user_total_remaining(integer) TO anon;
GRANT EXECUTE ON FUNCTION get_user_total_remaining(integer) TO authenticated;