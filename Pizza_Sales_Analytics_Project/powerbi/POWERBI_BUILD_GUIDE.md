# Power BI Dashboard: Build Guide

Power BI files (.pbix) can only be created in Power BI Desktop, so this guide gives you everything needed to build the dashboard and match the Python, SQL and Excel numbers.

## 1. Load data
Home > Get Data > Text/CSV > `data/pizza_sales.csv` > Transform Data.

In Power Query:
- Change `order_date` to **Date** using *Using Locale > English (United Kingdom)* (the source dates are dd-mm-yyyy; US locale will misread them).
- Change `order_time` to **Time**.
- Remove `pizza_ingredients` and `pizza_name_id` if you don't use them.
- Close & Apply.

## 2. Calendar and helper columns (Modeling > New column)
```DAX
Month Num    = MONTH(pizza_sales[order_date])
Month Name   = FORMAT(pizza_sales[order_date], "MMMM")
Weekday Num  = WEEKDAY(pizza_sales[order_date], 2)
Weekday Name = FORMAT(pizza_sales[order_date], "dddd")
Order Hour   = HOUR(pizza_sales[order_time])
```
Then sort `Month Name` by `Month Num` and `Weekday Name` by `Weekday Num` (Column tools > Sort by column).

## 3. DAX measures
```DAX
Total Revenue        = SUM(pizza_sales[total_price])
Total Orders         = DISTINCTCOUNT(pizza_sales[order_id])
Total Pizzas Sold    = SUM(pizza_sales[quantity])
Avg Order Value      = DIVIDE([Total Revenue], [Total Orders], 0)
Avg Pizzas per Order = DIVIDE([Total Pizzas Sold], [Total Orders], 0)
Revenue Share        = DIVIDE([Total Revenue], CALCULATE([Total Revenue], ALL(pizza_sales)), 0)
```
Format Revenue and AOV as currency, Revenue Share as percentage.

## 4. Report layout
| Area | Visual | Fields |
|---|---|---|
| Top row | 5 Cards | Total Revenue, Total Orders, Total Pizzas Sold, Avg Order Value, Avg Pizzas per Order |
| Left | Line chart | Axis = Order Hour, Values = Total Orders |
| Left-mid | Column chart | Axis = Weekday Name, Values = Total Orders |
| Centre | Column chart | Axis = Month Name, Values = Total Revenue |
| Right | Donut | Legend = pizza_category, Values = Total Revenue |
| Right-mid | Bar | Axis = pizza_size, Values = Revenue Share |
| Bottom (page 2) | Bar charts | Axis = pizza_name, Values = Total Revenue, filter **Top N = 5** and **Bottom N = 5** (Filters pane > Top N) |
| Side | Slicers | order_date, pizza_category, pizza_size |

## 5. Check against the other tools
With no slicers selected the cards must read: **$817,860 | 21,350 | 49,574 | $38.31 | 2.32**. If Total Orders is off, make sure it is a *distinct* count of `order_id`, since each order has several rows.
