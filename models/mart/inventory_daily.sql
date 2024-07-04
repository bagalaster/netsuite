{{ config(materialized='table' )}}

WITH quantity_time_series AS (
    SELECT * FROM GAP_FILL(
        (SELECT * FROM {{ ref('int__daily_item_quantity') }}),
        ts_column => 'date',
        bucket_width => INTERVAL 1 DAY,
        partitioning_columns => ['item_id', 'location_id', 'bin_id', 'inventory_status_id'],
        value_columns => [('cum_quantity', 'locf')]
    )
)

-- Fill in days where there is no change in quantity or price
SELECT
    q.date
    , i.name AS item
    , l.name AS location
    , b.name AS bin
    , s.name AS status
    , q.cum_quantity AS quantity
    , q.cum_quantity * ci.cost AS value
FROM quantity_time_series q
LEFT JOIN {{ source('netsuite_transactions_raw', 'item') }} i
ON q.item_id = i.id
LEFT JOIN {{ source('netsuite_transactions_raw', 'location') }} l
ON q.location_id = l.id
LEFT JOIN {{ source('netsuite_transactions_raw', 'bin') }} b
ON q.bin_id = b.id
LEFT JOIN {{ source('netsuite_transactions_raw', 'inventory_status') }} s
ON q.inventory_status_id = s.id
LEFT JOIN {{ ref('int__cost_intervals') }} ci
ON
    q.location_id = ci.location_id
    AND q.item_id = ci.item_id
    AND q.date BETWEEN ci.effective_start_date AND ci.effective_end_date