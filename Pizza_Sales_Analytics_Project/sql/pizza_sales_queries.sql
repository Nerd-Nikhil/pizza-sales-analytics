-- =====================================================================
-- Pizza Sales Analysis: SQL queries (MySQL 8.x)
-- Mirrors the KPIs and charts in the Python notebook, Excel and Power BI.
-- =====================================================================

-- 1. Database and table ---------------------------------------------------
CREATE DATABASE IF NOT EXISTS pizza_analytics;
USE pizza_analytics;

DROP TABLE IF EXISTS pizza_sales;
CREATE TABLE pizza_sales (
    pizza_id          INT PRIMARY KEY,
    order_id          INT NOT NULL,
    pizza_name_id     VARCHAR(50),
    quantity          INT,
    order_date        DATE,
    order_time        TIME,
    unit_price        DECIMAL(6,2),
    total_price       DECIMAL(8,2),
    pizza_size        VARCHAR(5),
    pizza_category    VARCHAR(20),
    pizza_ingredients TEXT,
    pizza_name        VARCHAR(60),
    INDEX idx_order (order_id),
    INDEX idx_date (order_date)
);

-- 2. Load the CSV. The source file uses Windows line endings (\r\n) and dd-mm-yyyy
--    dates, so set the line terminator and convert the date while loading.
-- (Requires local_infile enabled; adjust the path.)
-- LOAD DATA LOCAL INFILE 'data/pizza_sales.csv'
-- INTO TABLE pizza_sales
-- FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\r\n'
-- IGNORE 1 ROWS
-- (pizza_id, order_id, pizza_name_id, quantity, @order_date, order_time,
--  unit_price, total_price, pizza_size, pizza_category, pizza_ingredients, pizza_name)
-- SET order_date = STR_TO_DATE(@order_date, '%d-%m-%Y');

-- 3. Data quality checks ----------------------------------------------------
SELECT COUNT(*)                     AS total_rows,
       COUNT(DISTINCT pizza_id)     AS distinct_lines,
       MIN(order_date)              AS first_date,
       MAX(order_date)              AS last_date,
       COUNT(DISTINCT order_date)   AS trading_days,
       SUM(ABS(unit_price * quantity - total_price) > 0.01) AS price_mismatches
FROM pizza_sales;

-- 4. KPIs ---------------------------------------------------------------------
SELECT ROUND(SUM(total_price), 2) AS total_revenue FROM pizza_sales;

SELECT ROUND(SUM(total_price) / COUNT(DISTINCT order_id), 2) AS avg_order_value FROM pizza_sales;

SELECT SUM(quantity) AS total_pizzas_sold FROM pizza_sales;

SELECT COUNT(DISTINCT order_id) AS total_orders FROM pizza_sales;

SELECT ROUND(SUM(quantity) / COUNT(DISTINCT order_id), 2) AS avg_pizzas_per_order FROM pizza_sales;

-- 5. Hourly trend -----------------------------------------------------------------
SELECT HOUR(order_time)               AS order_hour,
       COUNT(DISTINCT order_id)       AS total_orders,
       SUM(quantity)                  AS pizzas_sold,
       ROUND(SUM(total_price), 2)     AS revenue
FROM pizza_sales
GROUP BY HOUR(order_time)
ORDER BY order_hour;

-- 6. Weekday trend (Monday first) ----------------------------------------------------
SELECT DAYNAME(order_date)            AS weekday,
       COUNT(DISTINCT order_id)       AS total_orders,
       ROUND(SUM(total_price), 2)     AS revenue,
       COUNT(DISTINCT order_date)     AS trading_days,
       ROUND(COUNT(DISTINCT order_id) / COUNT(DISTINCT order_date), 1) AS orders_per_trading_day
FROM pizza_sales
GROUP BY DAYNAME(order_date), WEEKDAY(order_date)
ORDER BY WEEKDAY(order_date);

-- 7. Monthly trend ----------------------------------------------------------------------
SELECT MONTH(order_date)              AS month_num,
       MONTHNAME(order_date)          AS month_name,
       COUNT(DISTINCT order_id)       AS total_orders,
       SUM(quantity)                  AS pizzas_sold,
       ROUND(SUM(total_price), 2)     AS revenue
FROM pizza_sales
GROUP BY MONTH(order_date), MONTHNAME(order_date)
ORDER BY month_num;

-- 8. Weekly trend (ISO week) -----------------------------------------------------------------
SELECT WEEK(order_date, 3)            AS iso_week,
       COUNT(DISTINCT order_id)       AS total_orders
FROM pizza_sales
GROUP BY WEEK(order_date, 3)
ORDER BY iso_week;

-- 9. Revenue share by category and by size -------------------------------------------------------
SELECT pizza_category,
       ROUND(SUM(total_price), 2) AS revenue,
       ROUND(100 * SUM(total_price) / (SELECT SUM(total_price) FROM pizza_sales), 2) AS revenue_pct
FROM pizza_sales
GROUP BY pizza_category
ORDER BY revenue DESC;

SELECT pizza_size,
       ROUND(SUM(total_price), 2) AS revenue,
       ROUND(100 * SUM(total_price) / (SELECT SUM(total_price) FROM pizza_sales), 2) AS revenue_pct
FROM pizza_sales
GROUP BY pizza_size
ORDER BY revenue DESC;

-- 10. Best and worst sellers (top / bottom 5) ------------------------------------------------------
-- By revenue
(SELECT 'Top 5' AS list, pizza_name, ROUND(SUM(total_price), 2) AS revenue
 FROM pizza_sales GROUP BY pizza_name ORDER BY revenue DESC LIMIT 5)
UNION ALL
(SELECT 'Bottom 5', pizza_name, ROUND(SUM(total_price), 2) AS revenue
 FROM pizza_sales GROUP BY pizza_name ORDER BY revenue ASC LIMIT 5);

-- By quantity
(SELECT 'Top 5' AS list, pizza_name, SUM(quantity) AS pizzas_sold
 FROM pizza_sales GROUP BY pizza_name ORDER BY pizzas_sold DESC LIMIT 5)
UNION ALL
(SELECT 'Bottom 5', pizza_name, SUM(quantity) AS pizzas_sold
 FROM pizza_sales GROUP BY pizza_name ORDER BY pizzas_sold ASC LIMIT 5);

-- By number of orders
(SELECT 'Top 5' AS list, pizza_name, COUNT(DISTINCT order_id) AS orders
 FROM pizza_sales GROUP BY pizza_name ORDER BY orders DESC LIMIT 5)
UNION ALL
(SELECT 'Bottom 5', pizza_name, COUNT(DISTINCT order_id) AS orders
 FROM pizza_sales GROUP BY pizza_name ORDER BY orders ASC LIMIT 5);

-- 11. Window functions: rank pizzas within each category and running revenue ----------------------------
SELECT pizza_category, pizza_name, revenue,
       RANK() OVER (PARTITION BY pizza_category ORDER BY revenue DESC) AS rank_in_category
FROM (
    SELECT pizza_category, pizza_name, ROUND(SUM(total_price), 2) AS revenue
    FROM pizza_sales
    GROUP BY pizza_category, pizza_name
) t
ORDER BY pizza_category, rank_in_category;

SELECT month_num, month_name, revenue,
       ROUND(SUM(revenue) OVER (ORDER BY month_num), 2) AS cumulative_revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month_num))
                  / LAG(revenue) OVER (ORDER BY month_num), 1) AS mom_change_pct
FROM (
    SELECT MONTH(order_date) AS month_num, MONTHNAME(order_date) AS month_name,
           SUM(total_price) AS revenue
    FROM pizza_sales
    GROUP BY MONTH(order_date), MONTHNAME(order_date)
) m
ORDER BY month_num;

-- 12. Basket size distribution ------------------------------------------------------------------------------
SELECT pizzas_in_order, COUNT(*) AS orders,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders
FROM (SELECT order_id, SUM(quantity) AS pizzas_in_order FROM pizza_sales GROUP BY order_id) b
GROUP BY pizzas_in_order
ORDER BY pizzas_in_order;
