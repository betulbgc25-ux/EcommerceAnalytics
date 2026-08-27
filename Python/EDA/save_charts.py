import os
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
from prophet import Prophet
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

sns.set_theme(style="whitegrid")
assets_dir = os.path.join("Presentation", "Assets")
os.makedirs(assets_dir, exist_ok=True)
clean_dir = os.path.join("Data", "Clean")

# 1. Master Veri
df = pd.read_csv(os.path.join(clean_dir, "master_orders_clean.csv"))
df["order_purchase_timestamp"] = pd.to_datetime(df["order_purchase_timestamp"])

# A. Aylık Satış Trendi Grafiği
df["year_month"] = (
    df["order_purchase_timestamp"].dt.to_period("M").astype(str)
)
monthly = df.groupby("year_month")["total_price"].sum().reset_index()

plt.figure(figsize=(10, 5))
plt.plot(
    monthly["year_month"],
    monthly["total_price"],
    marker="o",
    color="#1A365D",
    linewidth=2.5,
)
plt.title("Aylık Toplam Satış Trendi (Ciro)", fontsize=13, fontweight="bold")
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig(
    os.path.join(assets_dir, "1_aylik_satis_trendi.png"),
    dpi=300,
    bbox_inches="tight",
)
plt.close()

# B. En Çok Gelir Getiren İlk 10 Kategori
top_cat = (
    df.groupby("category_name")["total_price"]
    .sum()
    .sort_values(ascending=False)
    .head(10)
    .reset_index()
)
plt.figure(figsize=(10, 5))
sns.barplot(data=top_cat, x="total_price", y="category_name", palette="Blues_r")
plt.title("En Çok Gelir Getiren İlk 10 Kategori", fontsize=13, fontweight="bold")
plt.tight_layout()
plt.savefig(
    os.path.join(assets_dir, "2_en_cok_gelir_getiren_kategoriler.png"),
    dpi=300,
    bbox_inches="tight",
)
plt.close()

# C. En Çok Müşteri Bulunan İlk 10 Şehir
top_cities = df["customer_city"].value_counts().head(10).reset_index()
top_cities.columns = ["city", "count"]
plt.figure(figsize=(10, 5))
sns.barplot(data=top_cities, x="count", y="city", palette="viridis")
plt.title("En Çok Sipariş Veren İlk 10 Şehir", fontsize=13, fontweight="bold")
plt.tight_layout()
plt.savefig(
    os.path.join(assets_dir, "3_sehir_dagilimi.png"), dpi=300, bbox_inches="tight"
)
plt.close()

# D. Müşteri Segmentasyonu Grafiği (RFM + KMeans)
rfm = pd.read_csv(os.path.join(clean_dir, "rfm_segments.csv"))
plt.figure(figsize=(9, 4.5))
sns.countplot(
    data=rfm,
    y="segment",
    palette="mako",
    order=rfm["segment"].value_counts().index,
)
plt.title(
    "Müşteri Segmentleri Dağılımı (K-Means)", fontsize=13, fontweight="bold"
)
plt.tight_layout()
plt.savefig(
    os.path.join(assets_dir, "4_musteri_segmentleri.png"),
    dpi=300,
    bbox_inches="tight",
)
plt.close()

# E. Prophet Gelecek Satış Tahmin Grafiği
daily_sales = (
    df.groupby(df["order_purchase_timestamp"].dt.date)["total_price"]
    .sum()
    .reset_index()
)
daily_sales.columns = ["ds", "y"]
daily_sales["ds"] = pd.to_datetime(daily_sales["ds"])

model = Prophet(
    yearly_seasonality=True, weekly_seasonality=True, daily_seasonality=False
)
model.fit(daily_sales)
future = model.make_future_dataframe(periods=30)
forecast = model.predict(future)

hist_rec = daily_sales.tail(60)
fore_fut = forecast.tail(30)

plt.figure(figsize=(11, 5))
plt.plot(
    hist_rec["ds"],
    hist_rec["y"],
    label="Gerçekleşen Satışlar",
    color="#1f77b4",
    linewidth=2,
)
plt.plot(
    fore_fut["ds"],
    fore_fut["yhat"],
    label="30 Günlük Gelecek Tahmini",
    color="#d62728",
    linewidth=2.5,
    linestyle="--",
)
plt.fill_between(
    fore_fut["ds"],
    fore_fut["yhat_lower"],
    fore_fut["yhat_upper"],
    color="#d62728",
    alpha=0.2,
)
plt.title(
    "Önümüzdeki 30 Günlük Satış Tahmini (Prophet)", fontsize=13, fontweight="bold"
)
plt.legend(loc="upper left")
plt.tight_layout()
plt.savefig(
    os.path.join(assets_dir, "5_gelecek_satis_tahmini.png"),
    dpi=300,
    bbox_inches="tight",
)
plt.close()

print(
    "🎉 TÜM GRAFİKLER 'Presentation/Assets/' KLASÖRÜNE YÜKSEK KALİTEDE (PNG)"
    " KAYDEDİLDİ!"
)