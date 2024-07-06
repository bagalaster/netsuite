{{ config(materialized='view') }}


SELECT 
    date AS effective_start_date
    , LEAD(DATE_SUB(date, INTERVAL 1 DAY), 1, DATE '2099-01-01') 
      OVER (PARTITION BY location_id, item_id ORDER BY date ASC) 
      AS effective_end_date
    , location_id
    , item_id
    , cost
FROM {{ source("netsuite_transactions", "raw__costs") }}