-- CTE (Customer Revenue)

WITH CustomerRevenue AS
(
    SELECT
        c.Customer_ID,
        SUM(f.Quantity * f.Price) AS TotalRevenue
    FROM Fact_Transactions f
    JOIN Dim_Customers c
        ON f.CustomerKey = c.CustomerKey
    GROUP BY c.Customer_ID
)

SELECT *
FROM CustomerRevenue
ORDER BY TotalRevenue DESC;


-- Window Function (Running Total of Sales)

SELECT
    t.InvoiceDate,
    SUM(f.Quantity * f.Price) AS DailyRevenue,

    SUM(SUM(f.Quantity * f.Price)) 
        OVER (ORDER BY t.InvoiceDate) AS RunningRevenue

FROM Fact_Transactions f
JOIN Dim_Time t
    ON f.TimeKey = t.TimeKey

GROUP BY t.InvoiceDate
ORDER BY t.InvoiceDate;

-- Rank and Over (Top Customers)

SELECT
    c.Customer_ID,
    SUM(f.Quantity * f.Price) AS TotalRevenue,

    RANK() OVER (
        ORDER BY SUM(f.Quantity * f.Price) DESC
    ) AS CustomerRank

FROM Fact_Transactions f
JOIN Dim_Customers c
    ON f.CustomerKey = c.CustomerKey

GROUP BY c.Customer_ID
ORDER BY CustomerRank;

-- LAG (Compare Sales With Previous Day)

SELECT
    t.InvoiceDate,
    SUM(f.Quantity * f.Price) AS DailyRevenue,

    LAG(SUM(f.Quantity * f.Price))
        OVER (ORDER BY t.InvoiceDate) AS PreviousDayRevenue

FROM Fact_Transactions f
JOIN Dim_Time t
    ON f.TimeKey = t.TimeKey

GROUP BY t.InvoiceDate
ORDER BY t.InvoiceDate;

-- Rolling Average (7-Day Sales Trend)

SELECT
    t.InvoiceDate,
    SUM(f.Quantity * f.Price) AS DailyRevenue,

    AVG(SUM(f.Quantity * f.Price)) 
        OVER (
            ORDER BY t.InvoiceDate
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS Rolling7DayAverage

FROM Fact_Transactions f
JOIN Dim_Time t
    ON f.TimeKey = t.TimeKey

GROUP BY t.InvoiceDate
ORDER BY t.InvoiceDate;


-- Cohort Analysis (Customer First Purchase Month)

-- Calculate RFM values

WITH CustomerFirstPurchase AS
(
    SELECT
        c.CustomerKey,
        MIN(t.InvoiceDate) AS FirstPurchaseDate
    FROM Fact_Transactions f
    JOIN Dim_Customers c ON f.CustomerKey = c.CustomerKey
    JOIN Dim_Time t ON f.TimeKey = t.TimeKey
    GROUP BY c.CustomerKey
)

SELECT
    YEAR(FirstPurchaseDate) AS CohortYear,
    MONTH(FirstPurchaseDate) AS CohortMonth,
    COUNT(CustomerKey) AS Customers
FROM CustomerFirstPurchase
GROUP BY
    YEAR(FirstPurchaseDate),
    MONTH(FirstPurchaseDate)
ORDER BY CohortYear, CohortMonth;


-- RFM Scoring (Recency, Frequency, Monetary)

WITH RFM_Base AS
(
SELECT
    c.Customer_ID,

    MAX(t.InvoiceDate) AS LastPurchaseDate,

    COUNT(f.TransactionKey) AS Frequency,

    SUM(f.Quantity * f.Price) AS Monetary

FROM Fact_Transactions f

JOIN Dim_Customers c
    ON f.CustomerKey = c.CustomerKey

JOIN Dim_Time t
    ON f.TimeKey = t.TimeKey

GROUP BY c.Customer_ID
)

SELECT *
FROM RFM_Base;


## RFM Scores

WITH RFM_Base AS
(
SELECT
    c.Customer_ID,
    MAX(t.InvoiceDate) AS LastPurchaseDate,
    COUNT(f.TransactionKey) AS Frequency,
    SUM(f.Quantity * f.Price) AS Monetary
FROM Fact_Transactions f
JOIN Dim_Customers c ON f.CustomerKey = c.CustomerKey
JOIN Dim_Time t ON f.TimeKey = t.TimeKey
GROUP BY c.Customer_ID
)

SELECT
    Customer_ID,

    NTILE(5) OVER (ORDER BY LastPurchaseDate DESC) AS RecencyScore,
    NTILE(5) OVER (ORDER BY Frequency DESC) AS FrequencyScore,
    NTILE(5) OVER (ORDER BY Monetary DESC) AS MonetaryScore

FROM RFM_Base;


-- Customer Segmentation Logic

WITH RFM AS
(
SELECT
    c.Customer_ID,
    SUM(f.Quantity * f.Price) AS Monetary,
    COUNT(*) AS Frequency
FROM Fact_Transactions f
JOIN Dim_Customers c
    ON f.CustomerKey = c.CustomerKey
GROUP BY c.Customer_ID
)

SELECT
    Customer_ID,
    Monetary,
    Frequency,

    CASE
        WHEN Monetary > 10000 THEN 'VIP'
        WHEN Monetary > 5000 THEN 'Loyal'
        WHEN Monetary > 1000 THEN 'Regular'
        ELSE 'Low Value'
    END AS CustomerSegment

FROM RFM
ORDER BY Monetary DESC;



-- Pareto Analysis — Top Products Driving 80% of Revenue

WITH ProductRevenue AS
(
    SELECT
        p.StockCode,
        p.Description,
        SUM(f.Quantity * f.Price) AS Revenue
    FROM Fact_Transactions f
    JOIN Dim_Products p
        ON f.ProductKey = p.ProductKey
    WHERE f.Quantity > 0
    GROUP BY p.StockCode, p.Description
),

RevenueRank AS
(
    SELECT
        *,
        SUM(Revenue) OVER () AS TotalRevenue,
        SUM(Revenue) OVER (ORDER BY Revenue DESC) AS RunningRevenue
    FROM ProductRevenue
)

SELECT
    StockCode,
    Description,
    Revenue,
    RunningRevenue,
    RunningRevenue / TotalRevenue AS RevenueShare
FROM RevenueRank
ORDER BY Revenue DESC;


-- Customer Lifetime Value (CLV) Ranking

SELECT
    c.Customer_ID,
    co.Country,
    SUM(f.Quantity * f.Price) AS LifetimeValue,

    RANK() OVER (
        ORDER BY SUM(f.Quantity * f.Price) DESC
    ) AS CustomerRank

FROM Fact_Transactions f

JOIN Dim_Customers c
    ON f.CustomerKey = c.CustomerKey

JOIN Dim_Country co
    ON f.CountryKey = co.CountryKey

WHERE f.Quantity > 0

GROUP BY
    c.Customer_ID,
    co.Country

ORDER BY LifetimeValue DESC;


-- Month-to-Month Growth (Revenue Trend)

WITH MonthlyRevenue AS
(
    SELECT
        t.Year,
        t.Month,
        SUM(f.Quantity * f.Price) AS Revenue
    FROM Fact_Transactions f
    JOIN Dim_Time t
        ON f.TimeKey = t.TimeKey
    WHERE f.Quantity > 0
    GROUP BY t.Year, t.Month
)

SELECT
    Year,
    Month,
    Revenue,

    LAG(Revenue) OVER (
        ORDER BY Year, Month
    ) AS PreviousMonthRevenue,

    Revenue - LAG(Revenue) OVER (
        ORDER BY Year, Month
    ) AS RevenueGrowth

FROM MonthlyRevenue
ORDER BY Year, Month;



-- Top Country Markets

SELECT
    co.Country,
    SUM(f.Quantity * f.Price) AS Revenue,
    COUNT(DISTINCT f.CustomerKey) AS Customers
FROM Fact_Transactions f

JOIN Dim_Country co
    ON f.CountryKey = co.CountryKey

WHERE f.Quantity > 0

GROUP BY co.Country
ORDER BY Revenue DESC;


