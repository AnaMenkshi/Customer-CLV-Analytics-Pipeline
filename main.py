import pandas as pd
from sqlalchemy import create_engine
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, r2_score
import matplotlib.pyplot as plt
import seaborn as sns



# 1 CONNECT TO SQL SERVER

server = "YOUR_SERVER_NAME"
database = "Ecommerce_Intelligence_DB"

connection_string = (
    f"mssql+pyodbc://@{server}/{database}"
    "?driver=ODBC+Driver+17+for+SQL+Server"
)

engine = create_engine(connection_string)



# 2 EXTRACT CUSTOMER FEATURES FROM SQL

query = """

SELECT
    c.Customer_ID,

    COUNT(f.TransactionKey) AS PurchaseFrequency,

    SUM(f.Quantity * f.Price) AS TotalRevenue,

    AVG(f.Quantity * f.Price) AS AvgOrderValue,

    MAX(t.InvoiceDate) AS LastPurchaseDate,

    COUNT(DISTINCT p.ProductKey) AS UniqueProducts,

    COUNT(DISTINCT co.CountryKey) AS CountriesPurchased

FROM Fact_Transactions f

JOIN Dim_Customers c
    ON f.CustomerKey = c.CustomerKey

JOIN Dim_Time t
    ON f.TimeKey = t.TimeKey

JOIN Dim_Products p
    ON f.ProductKey = p.ProductKey

JOIN Dim_Country co
    ON f.CountryKey = co.CountryKey

WHERE f.Quantity > 0

GROUP BY c.Customer_ID

"""

df = pd.read_sql(query, engine)

print("Dataset Shape:", df.shape)
print(df.head())



# 3 FEATURE ENGINEERING


df["LastPurchaseDate"] = pd.to_datetime(df["LastPurchaseDate"])

today = df["LastPurchaseDate"].max()

df["RecencyDays"] = (today - df["LastPurchaseDate"]).dt.days

df = df.drop(columns=["LastPurchaseDate"])



# 4 TARGET VARIABLE ANALYSIS


print("\nTarget Variable Statistics (TotalRevenue)")
print(df["TotalRevenue"].describe())

plt.figure(figsize=(8, 5))
sns.histplot(df["TotalRevenue"], bins=50, kde=True)
plt.title("Customer Total Revenue Distribution")
plt.xlabel("Total Revenue")
plt.ylabel("Number of Customers")
plt.show()



# 5 TARGET VARIABLE (CLV)


X = df.drop(columns=["Customer_ID", "TotalRevenue"])
y = df["TotalRevenue"]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)



# 6 MACHINE LEARNING MODEL


model = RandomForestRegressor(
    n_estimators=200,
    max_depth=10,
    random_state=42
)

model.fit(X_train, y_train)


# 7 MODEL EVALUATION


predictions = model.predict(X_test)

mae = mean_absolute_error(y_test, predictions)
r2 = r2_score(y_test, predictions)

print("\nModel Performance")
print("MAE:", mae)
print("R2 Score:", r2)



# 8 ACTUAL VS PREDICTED VISUALIZATION


plt.figure(figsize=(7, 7))
plt.scatter(y_test, predictions, alpha=0.5)
plt.xlabel("Actual Revenue")
plt.ylabel("Predicted Revenue")
plt.title("Actual vs Predicted Customer Revenue")

plt.plot(
    [y_test.min(), y_test.max()],
    [y_test.min(), y_test.max()],
    color="red"
)

plt.show()



# 9 RESIDUAL ERROR ANALYSIS


residuals = y_test - predictions

plt.figure(figsize=(8, 5))
sns.histplot(residuals, bins=50, kde=True)
plt.title("Prediction Error Distribution")
plt.xlabel("Prediction Error")
plt.show()



# 10 FEATURE IMPORTANCE


importance = pd.Series(
    model.feature_importances_,
    index=X.columns
).sort_values(ascending=False)

print("\nFeature Importance:")
print(importance)

plt.figure(figsize=(8, 5))
sns.barplot(x=importance.values, y=importance.index)
plt.title("Feature Importance")
plt.show()



# 11 CUSTOMER LIFETIME VALUE PREDICTION


df["Predicted_CLV"] = model.predict(X)

print(df.head())



# 12 CUSTOMER SEGMENTATION (CLV TIERS)


df["CLV_Segment"] = pd.qcut(
    df["Predicted_CLV"],
    q=4,
    labels=["Low Value", "Medium Value", "High Value", "VIP"]
)

print("\nCustomer Segment Distribution")
print(df["CLV_Segment"].value_counts())



# 13 SAVE PREDICTIONS BACK TO SQL


df_predictions = df[["Customer_ID", "Predicted_CLV", "CLV_Segment"]]

df_predictions.to_sql(
    "ML_Customer_CLV_Predictions",
    engine,
    if_exists="replace",
    index=False
)

print("\nPredictions exported to SQL Server.")


