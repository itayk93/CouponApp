DROP FUNCTION IF EXISTS get_widget_coupons(integer);

CREATE OR REPLACE FUNCTION get_widget_coupons(p_user_id integer)
RETURNS SETOF coupon AS $$
BEGIN
  RETURN QUERY SELECT * FROM coupon WHERE user_id = p_user_id AND show_in_widget = true;
END;
$$ LANGUAGE plpgsql;