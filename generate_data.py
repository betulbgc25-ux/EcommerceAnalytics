import random
from datetime import datetime, timedelta
from faker import Faker
import pandas as pd
from sqlalchemy import create_engine

# Türkçe sahte veri üretici
fake = Faker("tr_TR")

# SQL Server Bağlantısı
SERVER = r"DESKTOP-MJE4B4H\SQLEXPRESS"
DATABASE = "EcommerceDB"
DRIVER = "ODBC Driver 17 for SQL Server"

connection_string = (
    f"mssql+pyodbc://@{SERVER}/{DATABASE}?driver={DRIVER}&trusted_connection=yes"
)
engine = create_engine(connection_string)

print("Veriler üretiliyor, lütfen bekleyin...")

# 1. Categories
categories = ["Elektronik", "Giyim", "Ev & Yaşam", "Kitap", "Spor"]
df_categories = pd.DataFrame({"CategoryName": categories})
df_categories.to_sql("Categories", engine, if_exists="append", index=False)

# 2. Customers (100 Müşteri)
customers = []
for _ in range(100):
    customers.append(
        {
            "FirstName": fake.first_name(),
            "LastName": fake.last_name(),
            "Email": fake.email(),
            "City": fake.city(),
            "Country": "Türkiye",
            "SignupDate": fake.date_time_between(
                start_date="-2y", end_date="now"
            ),
        }
    )
df_customers = pd.DataFrame(customers)
df_customers.to_sql("Customers", engine, if_exists="append", index=False)

# 3. Products (50 Ürün)
products = []
for i in range(50):
    products.append(
        {
            "ProductName": f"Ürün-{i+1}",
            "CategoryID": random.randint(1, len(categories)),
            "Price": round(random.uniform(50.0, 1500.0), 2),
            "StockQuantity": random.randint(10, 200),
        }
    )
df_products = pd.DataFrame(products)
df_products.to_sql("Products", engine, if_exists="append", index=False)

# 4. Orders & OrderItems (200 Sipariş)
orders = []
order_items = []

for order_id in range(1, 201):
    customer_id = random.randint(1, 100)
    order_date = fake.date_time_between(start_date="-1y", end_date="now")

    # Sipariş kalemi oluşturma (1-4 arası ürün)
    item_count = random.randint(1, 4)
    total_amount = 0

    for _ in range(item_count):
        product_id = random.randint(1, 50)
        quantity = random.randint(1, 3)
        unit_price = round(random.uniform(50.0, 500.0), 2)
        total_amount += quantity * unit_price

        order_items.append(
            {
                "OrderID": order_id,
                "ProductID": product_id,
                "Quantity": quantity,
                "UnitPrice": unit_price,
            }
        )

    orders.append(
        {
            "CustomerID": customer_id,
            "OrderDate": order_date,
            "TotalAmount": round(total_amount, 2),
        }
    )

df_orders = pd.DataFrame(orders)
df_orders.to_sql("Orders", engine, if_exists="append", index=False)

df_order_items = pd.DataFrame(order_items)
df_order_items.to_sql("OrderItems", engine, if_exists="append", index=False)

print("Tüm veriler SQL Server'a başarıyla yüklendi!")