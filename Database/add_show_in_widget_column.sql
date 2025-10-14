ALTER TABLE coupon
ADD COLUMN show_in_widget BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN coupon.show_in_widget IS 'Flag to indicate if the coupon should be shown in the widget.';