CREATE OR REPLACE FUNCTION public.mark_coupon_as_used_rpc(p_coupon_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_coupon_value FLOAT;
BEGIN
    -- Get the coupon's value
    SELECT value INTO v_coupon_value FROM public.coupon WHERE id = p_coupon_id;

    -- Update the coupon status and used_value
    UPDATE public.coupon
    SET
        used_value = value, -- Set used_value to the full value of the coupon
        status = 'נוצל'
    WHERE
        id = p_coupon_id;

    -- Add a record to coupon_usage for analytics, mimicking the web app's logic
    INSERT INTO public.coupon_usage(coupon_id, used_amount, action, details)
    VALUES (p_coupon_id, v_coupon_value, 'mark_as_used', 'Marked as fully used from iOS app');
END;
$function$
;