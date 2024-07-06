# NetSuite Transaction Data Modeling

This repository contains the code for a DBT project modeling daily inventory quantities from the provided transactional data. 
All tables are hosted/built in BigQuery.

## Details/Answers/Commentary

### Daily Inventory Table

The daily inventory quantities are modeled in a table called `inventory_daily`, which contains the required columns.

This table contains 1 row per date between the minimum and maximum dates for which rows exist in the `transaction_line`
table for each `(location, bin, item, status)` combination. We could have alternatively only kept rows for dates on which
there were quantity or cost changes for each `(location, bin, item, status)` combination. This would significantly reduce
the size of the table, but we chose to expand out to all dates to minimize code complexity and to make analysis easier.

### Source data formatting

In most circumstances, we would include some kind of `clean` or `staging` layer after the raw source data where
data formatting logic would live. In this case, the provided data did not seem to need very much formatting, so to simplify,
we included tests for key validity/referential integrity directly on the source tables and rolled the limited "cleaning"
tasks into the transformation done into CTEs in the construction of the intermediate objects.

### Data quality

A couple of notes about data quality

- Inventory appears to go negative for some `(location, bin, item, status)` combinations, which can be traced back to
the original transaction lines. I can think of a couple explanations
  - We are missing some transactions representing the missing quantity
  - The operator or systems recording these transactions sometimes make mistakes that are later rectified

I strongly suspect the second case is true, given that the several cases I spot checked seemed to correct themselves later.
Regardless, this requires more investigation upstream of the provided transactions.
```sql
SELECT transaction_date, transaction_id, transaction_line_id, quantity 
FROM `netsuite_transactions.transaction_line`
WHERE item_id = 780 AND location_id = 207 AND bin_id = 428 AND inventory_status_id = 1
ORDER BY transaction_date
```
- There are 3703 items present in the `item` table and 28 locations present in the `locations` table for which we have no cost data.
Additionally, there are 20 location/item pairs for which there is no cost data in `costs`. We have a `value` of `NULL` for all such pairs
in `inventory_daily`. All location/item pairs for which ther is cost data in `costs` have complete cost data (i.e. the dates cover the entire period
for which there are transactions for that location/item pair)
```sql
-- Items with no pricing data
SELECT i.id, COUNT(cost) AS cnt
FROM `netsuite_transactions.item` i
LEFT JOIN `netsuite_transactions.costs` c
ON i.id = c.item_id
GROUP BY i.id
HAVING cnt = 0

-- Locations with no pricing data
SELECT l.id, COUNT(cost) AS cnt
FROM `netsuite_transactions.location` l
LEFT JOIN `netsuite_transactions.costs` c
ON l.id = c.item_id
GROUP BY l.id
HAVING cnt = 0 

-- Location/Item pairs in `transaction_line` with no pricing data
SELECT item_id, location_id
FROM `netsuite_transactions.inventory_daily`
WHERE value IS NULL
GROUP BY item_id, location_id
HAVING (item_id, location_id) NOT IN (
  SELECT (location_id, item_id) FROM `netsuite_transactions.costs`
)

-- Location/Item pairs in `transaction_line` with incomoplete pricing data
SELECT item_id, location_id
FROM `netsuite_transactions.inventory_daily`
WHERE value IS NULL
GROUP BY item_id, location_id
HAVING (item_id, location_id) IN (
  SELECT (location_id, item_id) FROM `netsuite_transactions.costs`
)
```

### Answers to questions

a. What is the quantity, and location/bin/status combos of item 355576 on
date 2022-11-21?
  - There is only 1 location/bin/status combo `(location_id=211, bin_id=16671, inventory_status_id=1)`, and the quantity for 2022-11-21 is 33
  ```sql
  SELECT date, item_id, location_id, bin_id, inventory_status_id, date, quantity
  FROM `netsuite_transactions.inventory_daily` 
  WHERE item_id = 355576 AND date = '2022-11-21'
  ```
b. What is the total value of item 209372 on Date 2022-06-05?
  - $65,051.74
  ```sql
SELECT date, item_id, ROUND(SUM(value), 2) AS total_value
FROM `netsuite_transactions.inventory_daily`
WHERE item_id = 209372 AND date = '2022-06-05'
GROUP BY date, item_id
  ```
c. What is the total value of inventory in Location
c7a95e433e878be525d03a08d6ab666b on 2022-01-01?
  - $5,948,198.55
  ```sql
  SELECT date, location, ROUND(SUM(value), 2) AS total_value
  FROM `netsuite_transactions.inventory_daily`
  WHERE location = 'c7a95e433e878be525d03a08d6ab666b' AND date = '2022-01-01'
  GROUP BY date, location
  ```

### Other Analysis

- Here is a graph of total value of inventory over time. It looks like there is a big drop from 2021-06-29 to 2021-06-30

<img width="808" alt="Screenshot 2024-07-06 at 10 00 02" src="https://github.com/bagalaster/netsuite/assets/35353673/094ce983-b558-47e9-88d9-9f0a6352f2c3">

- Here is a breakdown of that value by location. Most of the inventory value appears to be housed at a single location. Also, it looks like most of the drop in inventory value at 2021-06-30
comes from a single location (starting with `ec5b809`).

```sql
SELECT date, location_id, location, SUM(COALESCE(value, 0)) AS total_value
FROM `netsuite_transactions.inventory_daily`
GROUP BY date, location_id, location
```

<img width="797" alt="Screenshot 2024-07-06 at 09 58 38" src="https://github.com/bagalaster/netsuite/assets/35353673/8191ff75-bb5a-457c-90db-506ff2ec833b">

- At that location, it looks like most of the value lost comes from just two items (starting with `10e990` and `5a1b51`).

```sql
SELECT date, location, item_id, item, SUM(COALESCE(value, 0)) AS total_value
FROM `netsuite_transactions.inventory_daily`
WHERE location LIKE 'ec5b809%' AND date BETWEEN '2021-06-28' AND '2021-07-01'
GROUP BY date, location, item_id, item
```

<img width="797" alt="Screenshot 2024-07-06 at 10 10 53" src="https://github.com/bagalaster/netsuite/assets/35353673/a6534cfc-25c4-43b1-967f-5623f1c32d82">



