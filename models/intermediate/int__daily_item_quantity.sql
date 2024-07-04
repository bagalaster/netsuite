{{ config(materialized='view') }}

WITH transaction_line_clean AS (
    SELECT EXTRACT(DATE FROM transaction_date) AS transaction_date_clean, *
    FROM {{ source("netsuite_transactions_raw", "transaction_line") }}
),

daily_changes AS (
    SELECT
        transaction_date_clean AS date
        , location_id
        , bin_id
        , item_id
        , inventory_status_id
        , SUM(quantity) AS quantity
    FROM transaction_line_clean
    GROUP BY transaction_date_clean, location_id, bin_id, item_id, inventory_status_id
)

SELECT 
    date
    , location_id
    , bin_id
    , item_id
    , inventory_status_id
    , SUM(quantity) 
      OVER (
        PARTITION BY location_id, bin_id, item_id, inventory_status_id
        ORDER BY date ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS quantity
FROM daily_changes
