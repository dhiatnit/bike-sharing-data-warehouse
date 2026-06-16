-- ============================================================
-- Analytical queries against the bike-sharing star schema (dwh)
-- Each query demonstrates joining facts to conformed dimensions.
-- Results shown in comments were produced on the seeded dataset
-- (8,000 rides / 6,473 payments).
-- ============================================================

-- 1. Peak demand by hour of day
--    Drives staffing / rebalancing decisions.
SELECT EXTRACT(HOUR FROM start_time)::int AS hour_of_day,
       COUNT(*)                            AS rides
FROM   dwh.fact_ride
GROUP  BY 1
ORDER  BY rides DESC;

-- 2. Weekday vs weekend usage and average trip length
SELECT CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
       COUNT(*)                          AS rides,
       ROUND(AVG(f.ride_duration_minutes), 1) AS avg_minutes
FROM   dwh.fact_ride f
JOIN   dwh.dim_date  d ON f.start_date_key = d.date_key
GROUP  BY 1
ORDER  BY rides DESC;
-- Weekday | 5846 | 21.3
-- Weekend | 2154 | 21.4

-- 3. Busiest start stations (where to add capacity)
SELECT s.address,
       s.zone,
       COUNT(*) AS rides
FROM   dwh.fact_ride   f
JOIN   dwh.dim_station s ON f.start_station_key = s.station_key
GROUP  BY 1, 2
ORDER  BY rides DESC
LIMIT  10;

-- 4. Revenue by subscription plan
SELECT COALESCE(p.name, '(pay-as-you-go)') AS plan,
       COUNT(*)                            AS payments,
       ROUND(SUM(f.amount), 2)             AS revenue
FROM   dwh.fact_payment             f
LEFT JOIN dwh.dim_subscription_plan p ON f.subscription_plan_key = p.subscription_plan_key
GROUP  BY 1
ORDER  BY revenue DESC NULLS LAST;

-- 5. Payment health: paid vs pending vs failed
SELECT st.status_name,
       COUNT(*)               AS payments,
       ROUND(SUM(f.amount), 2) AS total_amount
FROM   dwh.fact_payment       f
JOIN   dwh.dim_payment_status st ON f.payment_status_key = st.payment_status_key
GROUP  BY 1
ORDER  BY payments DESC;
-- paid    | 5594 | 39592.71
-- pending |  587 |  7781.67
-- failed  |  292 |  1619.04

-- 6. Monthly ride trend (time-series via the date dimension)
SELECT d.year_num,
       d.month_num,
       d.month_name,
       COUNT(*) AS rides
FROM   dwh.fact_ride f
JOIN   dwh.dim_date  d ON f.start_date_key = d.date_key
GROUP  BY 1, 2, 3
ORDER  BY d.year_num, d.month_num;

-- 7. Net flow per station (arrivals - departures) to find rebalancing needs
WITH departures AS (
    SELECT start_station_key AS station_key, COUNT(*) AS out_rides
    FROM dwh.fact_ride GROUP BY 1),
arrivals AS (
    SELECT end_station_key AS station_key, COUNT(*) AS in_rides
    FROM dwh.fact_ride GROUP BY 1)
SELECT s.address,
       COALESCE(a.in_rides, 0)  AS arrivals,
       COALESCE(p.out_rides, 0) AS departures,
       COALESCE(a.in_rides, 0) - COALESCE(p.out_rides, 0) AS net_flow
FROM   dwh.dim_station s
LEFT JOIN arrivals   a ON a.station_key = s.station_key
LEFT JOIN departures p ON p.station_key = s.station_key
ORDER  BY net_flow DESC;
