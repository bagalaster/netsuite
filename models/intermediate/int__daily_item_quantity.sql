{{ config(materialized='view') }}

WITH transaction_line_clean AS (
    SELECT EXTRACT(DATE FROM transaction_date) AS transaction_date_clean, *
    FROM {{ source("netsuite_transactions_raw", "transaction_line") }}
)

SELECT 
    transaction_date_clean AS date
    , location_id
    , bin_id
    , item_id
    , quantity
    , SUM(quantity) 
      OVER (
        PARTITION BY location_id, bin_id, item_id
        ORDER BY transaction_date ASC 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cum_quantity
FROM transaction_line_clean
