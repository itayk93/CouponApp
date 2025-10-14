-- Create stored procedure to get consolidated transaction data for a coupon
-- This replicates the EXACT logic from the web version

CREATE OR REPLACE FUNCTION get_consolidated_transactions(coupon_id_param INTEGER)
RETURNS TABLE (
    source_table TEXT,
    id INTEGER,
    coupon_id INTEGER,
    transaction_timestamp TIMESTAMPTZ,
    transaction_amount DECIMAL,
    details TEXT,
    action TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH CouponFilter AS (
        SELECT DISTINCT coupon_id
        FROM coupon_transaction
        WHERE source = 'Multipass'
    ),
    CombinedData AS (
        SELECT
            'coupon_usage' AS source_table,
            id,
            coupon_id,
            -used_amount AS transaction_amount,
            timestamp AS transaction_timestamp,
            action,
            details,
            NULL  AS location,
            0     AS recharge_amount,
            NULL  AS reference_number,
            NULL  AS source
        FROM coupon_usage
        WHERE details NOT LIKE '%Multipass%'
        UNION ALL
        SELECT
            'coupon_transaction' AS source_table,
            id,
            coupon_id,
            -usage_amount + recharge_amount AS transaction_amount,
            transaction_date AS transaction_timestamp,
            source AS action,
            CASE WHEN location IS NOT NULL AND location <> ''
                 THEN location ELSE NULL END AS details,
            location,
            recharge_amount,
            reference_number,
            source
        FROM coupon_transaction
    ),
    SummedData AS (
        SELECT
            source_table, id, coupon_id, transaction_timestamp,
            transaction_amount, details, action
        FROM CombinedData
        WHERE coupon_id = coupon_id_param
          AND (
              coupon_id NOT IN (SELECT coupon_id FROM CouponFilter)
              OR (source_table = 'coupon_transaction' AND action = 'Multipass')
          )
        UNION ALL
        SELECT
            'sum_row'        AS source_table,
            NULL             AS id,
            coupon_id,
            NULL             AS transaction_timestamp,
            SUM(transaction_amount) AS transaction_amount,
            'יתרה בקופון'   AS details,
            NULL             AS action
        FROM CombinedData
        WHERE coupon_id = coupon_id_param
          AND (
              coupon_id NOT IN (SELECT coupon_id FROM CouponFilter)
              OR (source_table = 'coupon_transaction' AND action = 'Multipass')
          )
        GROUP BY coupon_id
    )
    SELECT source_table, id, coupon_id, transaction_timestamp,
           transaction_amount, details, action
    FROM   SummedData
    ORDER  BY CASE WHEN transaction_timestamp IS NULL THEN 1 ELSE 0 END,
             transaction_timestamp ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_consolidated_transactions(INTEGER) TO authenticated;