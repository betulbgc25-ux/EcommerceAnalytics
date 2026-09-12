from datetime import datetime
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
from sqlalchemy import create_engine

# SQL Server Bağlantısı
SERVER = r"DESKTOP-MJE4B4H\SQLEXPRESS"
DATABASE = "EcommerceDB"
DRIVER = "ODBC Driver 17 for SQL Server"

connection_string = (
    f"mssql+pyodbc://@{SERVER}/{DATABASE}?driver={DRIVER}&trusted_connection=yes"
)
engine = create_engine(connection_string)

print("SQL verileri çekiliyor...")

# SQL'den Müşteri ve Sipariş Verilerini Çekme
query = """
SELECT 
    c.CustomerID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    o.OrderID,
    o.OrderDate,
    o.TotalAmount
FROM Customers c
JOIN Orders o ON c.CustomerID = o.CustomerID
"""

df = pd.read_sql(query, engine)
df["OrderDate"] = pd.to_datetime(df["OrderDate"])

# RFM Hesaplama
today_date = df["OrderDate"].max() + pd.Timedelta(days=1)

rfm = (
    df.groupby("CustomerID")
    .agg(
        {
            "OrderDate": lambda date: (today_date - date.max()).days,  # Recency
            "OrderID": "count",  # Frequency
            "TotalAmount": "sum",  # Monetary
        }
    )
    .reset_index()
)

rfm.columns = ["CustomerID", "Recency", "Frequency", "Monetary"]

# RFM Skorlama (1-5 Arası)
rfm["R_Score"] = pd.qcut(rfm["Recency"], 5, labels=[5, 4, 3, 2, 1])
rfm["F_Score"] = pd.qcut(
    rfm["Frequency"].rank(method="first"), 5, labels=[1, 2, 3, 4, 5]
)
rfm["M_Score"] = pd.qcut(rfm["Monetary"], 5, labels=[1, 2, 3, 4, 5])

rfm["RFM_Score"] = (
    rfm["R_Score"].astype(str)
    + rfm["F_Score"].astype(str)
    + rfm["M_Score"].astype(str)
)

# Segmentasyon Haritası
seg_map = {
    r"[1-2][1-2]": "Hibernating (Uykuda)",
    r"[1-2][3-4]": "At_Risk (Risk Altında)",
    r"[1-2]5": "Can't Loose Them (Kaybedilmemeli)",
    r"3[1-2]": "About_to_Sleep (Uyumak Üzere)",
    r"33": "Need_Attention (İlgi Gerekli)",
    r"[3-4][4-5]": "Loyal_Customers (Sadık Müşteriler)",
    r"41": "Promising (Gelecek Vaadeden)",
    r"51": "New_Customers (Yeni Müşteriler)",
    r"[4-5][2-3]": "Potential_Loyalists (Potansiyel Sadık)",
    r"5[4-5]": "Champions (Şampiyonlar)",
}

rfm["Segment"] = (
    rfm["R_Score"].astype(str) + rfm["F_Score"].astype(str)
).replace(seg_map, regex=True)

print("\n--- RFM ANALİZ SONUÇLARI (İLK 10 MÜŞTERİ) ---")
print(rfm[["CustomerID", "Recency", "Frequency", "Monetary", "Segment"]].head(10))

# Segment Dağılımını Görselleştirme
plt.figure(figsize=(12, 6))
sns.countplot(
    data=rfm,
    y="Segment",
    order=rfm["Segment"].value_counts().index,
    palette="viridis",
)
plt.title("Müşteri Segment Dağılımı (RFM Analizi)")
plt.xlabel("Müşteri Sayısı")
plt.ylabel("Segment")
plt.tight_layout()
plt.savefig("rfm_segments.png")
print("\nSegment grafiği 'rfm_segments.png' olarak kaydedildi!")