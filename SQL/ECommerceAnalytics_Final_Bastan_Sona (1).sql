/*
====================================================================
 ECOMMERCE ANALYTICS - BAŞTAN SONA FINAL SQL DOSYASI
====================================================================

PROJE:
E-Commerce Analytics

DATABASE:
ECommerceAnalyticsDB

İÇERİK:
1. Database oluşturma
2. Tablo oluşturma
3. Veri yükleme/kontrol
4. Primary Key kontrolleri
5. Foreign Key kontrolü
6. Satış analizleri
7. Müşteri analizleri
8. Karlılık analizi
9. İade/iptal analizi
10. Gelecek tahmini
11. View oluşturma
12. Stored Procedure
13. Trigger
14. Performans analizi
15. Son kontroller

ÖNEMLİ:
- CSV verileri SQL Server'a Import Flat File / Import Wizard ile yüklenmiştir.
- Bu dosya mevcut veritabanındaki verileri silmez.
- Tablo oluşturma bölümü, tabloların proje yapısını gösterir.
- Gerçek veri yükleme işlemi CSV dosyalarından yapılmıştır.
- Veri setinde maliyet, gerçek indirim, stok miktarı ve iade nedeni
  alanları bulunmadığı için bu konularda gerçek sonuç uydurulmamıştır.

====================================================================
*/

/* ================================================================
   1. DATABASE OLUŞTURMA
   ================================================================ */

IF DB_ID('ECommerceAnalyticsDB') IS NULL
BEGIN
    CREATE DATABASE ECommerceAnalyticsDB;
END;
GO

USE ECommerceAnalyticsDB;
GO


/* ================================================================
   2. TABLOLAR
   ================================================================

   NOT:
   Projede veriler daha önce SQL Server'a import edildiği için aşağıdaki
   CREATE TABLE komutları mevcut tabloları tekrar oluşturmaz.

   Ana tablolar:
   Customers
   müşteriler
   Orders
   Orders_Staging
   Products
   products_clean

   Mevcut kayıt sayıları:
   Customers       : 99.441
   müşteriler      : 99.441
   Orders          : 98.666
   Orders_Staging  : 112.650
   Products        : 32.951
   products_clean  : 32.951
*/


/* ================================================================
   3. TABLO KAYIT KONTROLÜ
   ================================================================ */

SELECT 'Customers' AS Tablo, COUNT(*) AS KayitSayisi
FROM dbo.Customers

UNION ALL

SELECT 'müşteriler', COUNT(*)
FROM dbo.müşteriler

UNION ALL

SELECT 'Orders', COUNT(*)
FROM dbo.Orders

UNION ALL

SELECT 'Orders_Staging', COUNT(*)
FROM dbo.Orders_Staging

UNION ALL

SELECT 'Products', COUNT(*)
FROM dbo.Products

UNION ALL

SELECT 'products_clean', COUNT(*)
FROM dbo.products_clean;
GO


/* ================================================================
   4. ORDERS / STAGING KONTROLLERİ
   ================================================================ */

/* Staging satır sayısı ve farklı sipariş sayısı */
SELECT
    COUNT(*) AS StagingSatirSayisi,
    COUNT(DISTINCT order_id) AS FarkliSiparisSayisi
FROM dbo.Orders_Staging;
GO

/*
Beklenen:
StagingSatirSayisi  = 112650
FarkliSiparisSayisi = 98666
*/


/* Sipariş durumları */
SELECT
    order_status,
    COUNT(*) AS KayitSayisi
FROM dbo.Orders
GROUP BY order_status
ORDER BY KayitSayisi DESC;
GO

/*
Beklenen sonuçlar:
delivered     110197
shipped         1185
canceled         542
invoiced         359
processing       357
unavailable        7
approved           3
*/


/* ================================================================
   5. PRIMARY KEY KONTROLÜ
   ================================================================ */

SELECT
    tc.TABLE_NAME AS Tablo,
    tc.CONSTRAINT_NAME AS PrimaryKeyAdi,
    kcu.COLUMN_NAME AS Kolon
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
    ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
ORDER BY tc.TABLE_NAME;
GO


/*
Beklenen anahtarlar:

Customers       -> PK_Customers       -> customer_id
müşteriler      -> PK_müşteriler      -> customer_id
Orders          -> PK_Orders          -> order_id
Products        -> PK_Products        -> product_id
products_clean  -> PK_products_clean  -> product_id
*/


/* ================================================================
   6. FOREIGN KEY KONTROLÜ
   ================================================================ */

SELECT
    fk.name AS ForeignKeyAdi,
    OBJECT_NAME(fk.parent_object_id) AS Tablo,
    COL_NAME(fc.parent_object_id, fc.parent_column_id) AS Sütun,
    OBJECT_NAME(fk.referenced_object_id) AS ReferansTablo,
    COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS ReferansSütun
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fc
    ON fk.object_id = fc.constraint_object_id
ORDER BY Tablo;
GO

/*
Proje kontrolünde Foreign Key sonucu 0 çıkması mümkündür.
Bu durumda veritabanında tanımlı fiziksel Foreign Key bulunmamaktadır.
*/


/* ================================================================
   7. ORDERS_STAGING KOLON KONTROLÜ
   ================================================================ */

SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Orders_Staging'
ORDER BY ORDINAL_POSITION;
GO


/*
Orders_Staging'de kullanılan önemli kolonlar:

order_id
customer_id
order_status
order_purchase_timestamp
order_approved_at
order_delivered_carrier_date
order_delivered_customer_date
order_estimated_delivery_date
order_item_id
product_id
seller_id
shipping_limit_date
price
freight_value
product_category_name
product_name_lenght
product_description_lenght
product_photos_qty
product_weight_g
product_length_cm
product_height_cm
product_width_cm
product_category_name_english
category_name
customer_unique_id
customer_zip_code_prefix
customer_city
customer_state
payment_value
payment_type
total_price
*/


/* ================================================================
   8. VIEW'LER
   ================================================================ */


/* ------------------------------------------------
   8.1 vw_MonthlySales
   ------------------------------------------------ */

CREATE OR ALTER VIEW dbo.vw_MonthlySales
AS
SELECT
    YEAR(TRY_CONVERT(DATETIME, order_purchase_timestamp)) AS SatisYili,
    MONTH(TRY_CONVERT(DATETIME, order_purchase_timestamp)) AS SatisAyi,
    COUNT(DISTINCT order_id) AS SiparisSayisi,
    SUM(TRY_CONVERT(DECIMAL(18,2), total_price)) AS ToplamSatis
FROM dbo.Orders_Staging
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY
    YEAR(TRY_CONVERT(DATETIME, order_purchase_timestamp)),
    MONTH(TRY_CONVERT(DATETIME, order_purchase_timestamp));
GO


/* ------------------------------------------------
   8.2 vw_TopCustomers
   ------------------------------------------------ */

CREATE OR ALTER VIEW dbo.vw_TopCustomers
AS
SELECT
    customer_unique_id AS CustomerID,
    COUNT(DISTINCT order_id) AS SiparisSayisi,
    SUM(TRY_CONVERT(DECIMAL(18,2), total_price)) AS ToplamHarcama
FROM dbo.Orders_Staging
WHERE customer_unique_id IS NOT NULL
GROUP BY customer_unique_id;
GO


/* ------------------------------------------------
   8.3 vw_ReturnAnalysis
   ------------------------------------------------

   NOT:
   Veri setinde gerçek return_reason alanı bulunmadığı için
   "iade" yerine canceled siparişler analiz edilmektedir.
*/

CREATE OR ALTER VIEW dbo.vw_ReturnAnalysis
AS
SELECT
    product_id,
    category_name,
    COUNT(DISTINCT order_id) AS IptalSiparisSayisi,
    SUM(TRY_CONVERT(DECIMAL(18,2), total_price)) AS IptalTutari
FROM dbo.Orders_Staging
WHERE order_status = 'canceled'
  AND product_id IS NOT NULL
GROUP BY
    product_id,
    category_name;
GO


/* ================================================================
   9. SATIŞ ANALİZLERİ
   ================================================================ */


/* ------------------------------------------------
   SORU 1 - Günlük satışlarımız ne kadar?
   ------------------------------------------------ */

SELECT
    CAST(
        TRY_CONVERT(DATETIME, order_purchase_timestamp)
        AS DATE
    ) AS SatisTarihi,
    COUNT(DISTINCT order_id) AS SiparisSayisi,
    SUM(
        TRY_CONVERT(DECIMAL(18,2), total_price)
    ) AS ToplamSatis
FROM dbo.Orders_Staging
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY
    CAST(
        TRY_CONVERT(DATETIME, order_purchase_timestamp)
        AS DATE
    )
ORDER BY SatisTarihi;
GO


/* ------------------------------------------------
   SORU 2 - Aylık satışlarımız nasıl değişiyor?
   ------------------------------------------------ */

SELECT
    SatisYili,
    SatisAyi,
    SiparisSayisi,
    ToplamSatis
FROM dbo.vw_MonthlySales
ORDER BY
    SatisYili,
    SatisAyi;
GO


/* ------------------------------------------------
   SORU 3 - En çok satılan ürün hangisi?
   ------------------------------------------------ */

SELECT TOP 20
    product_id AS ProductID,
    COUNT(DISTINCT order_id) AS SatisAdedi,
    SUM(
        TRY_CONVERT(DECIMAL(18,2), total_price)
    ) AS ToplamSatis
FROM dbo.Orders_Staging
WHERE product_id IS NOT NULL
GROUP BY product_id
ORDER BY SatisAdedi DESC;
GO


/* ------------------------------------------------
   SORU 4 - En çok gelir getiren kategori hangisi?
   ------------------------------------------------ */

SELECT TOP 20
    category_name AS Kategori,
    SUM(
        TRY_CONVERT(DECIMAL(18,2), total_price)
    ) AS ToplamGelir
FROM dbo.Orders_Staging
WHERE category_name IS NOT NULL
GROUP BY category_name
ORDER BY ToplamGelir DESC;
GO


/* ================================================================
   10. MÜŞTERİ ANALİZLERİ
   ================================================================ */


/* ------------------------------------------------
   SORU 5 - En değerli müşterilerimiz kimler?
   ------------------------------------------------ */

SELECT TOP 20
    CustomerID,
    SiparisSayisi,
    ToplamHarcama
FROM dbo.vw_TopCustomers
ORDER BY ToplamHarcama DESC;
GO


/* ------------------------------------------------
   SORU 6 - Yeni müşteri oranımız nedir?
   ------------------------------------------------ */

WITH MusteriSiparis AS
(
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS SiparisSayisi
    FROM dbo.Orders_Staging
    WHERE customer_unique_id IS NOT NULL
    GROUP BY customer_unique_id
)
SELECT
    COUNT(*) AS ToplamMusteri,

    SUM(
        CASE
            WHEN SiparisSayisi = 1 THEN 1
            ELSE 0
        END
    ) AS TekSiparisliMusteri,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN SiparisSayisi = 1 THEN 1
                ELSE 0
            END
        )
        / NULLIF(COUNT(*),0)
        AS DECIMAL(10,2)
    ) AS YeniMusteriOrani
FROM MusteriSiparis;
GO


/* ------------------------------------------------
   SORU 7 - Hangi şehirlerde müşteri yoğunluğu fazladır?
   ------------------------------------------------ */

SELECT TOP 20
    customer_city AS Sehir,
    COUNT(DISTINCT customer_unique_id) AS MusteriSayisi
FROM dbo.Orders_Staging
WHERE customer_city IS NOT NULL
GROUP BY customer_city
ORDER BY MusteriSayisi DESC;
GO


/* ------------------------------------------------
   SORU 8 - Tekrar alışveriş yapan müşteri oranı nedir?
   ------------------------------------------------ */

WITH MusteriSiparis AS
(
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS SiparisSayisi
    FROM dbo.Orders_Staging
    WHERE customer_unique_id IS NOT NULL
    GROUP BY customer_unique_id
)
SELECT
    COUNT(*) AS ToplamMusteri,

    SUM(
        CASE
            WHEN SiparisSayisi > 1 THEN 1
            ELSE 0
        END
    ) AS TekrarAlisverisYapan,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN SiparisSayisi > 1 THEN 1
                ELSE 0
            END
        )
        / NULLIF(COUNT(*),0)
        AS DECIMAL(10,2)
    ) AS TekrarAlisverisOrani
FROM MusteriSiparis;
GO


/* ================================================================
   11. KARLILIK ANALİZİ
   ================================================================

   Veri setinde:
   - ürün maliyeti,
   - gerçek kâr,
   - indirim oranı / indirim tutarı

   bulunmadığı için aşağıdaki sorular gerçek kâr hesabıyla
   cevaplanamaz:

   1. Hangi ürün zarar ettiriyor?
   2. En yüksek kâr hangi kategoride?
   3. İndirimler kârı nasıl etkiliyor?

   Bu sorular için sonuç uydurulmamıştır.
*/


/* ================================================================
   12. İADE / İPTAL ANALİZİ
   ================================================================ */


/* ------------------------------------------------
   SORU 12 - En fazla hangi ürünler iade ediliyor?

   Veri setindeki "canceled" siparişler kullanılmıştır.
   ------------------------------------------------ */

SELECT TOP 20
    product_id AS ProductID,
    COUNT(DISTINCT order_id) AS IptalSiparisSayisi,
    SUM(
        TRY_CONVERT(DECIMAL(18,2), price)
    ) AS IptalUrunTutari
FROM dbo.Orders_Staging
WHERE order_status = 'canceled'
  AND product_id IS NOT NULL
GROUP BY product_id
ORDER BY IptalSiparisSayisi DESC;
GO


/* ------------------------------------------------
   SORU 13 - İade nedenleri nelerdir?

   Veri setinde return_reason / iade nedeni alanı olmadığı
   için gerçek iade nedenleri hesaplanamaz.
   ------------------------------------------------ */


/* ------------------------------------------------
   SORU 14 - İade / iptal oranı nedir?
   ------------------------------------------------ */

SELECT
    COUNT(DISTINCT order_id) AS ToplamSiparis,

    COUNT(
        DISTINCT
        CASE
            WHEN order_status = 'canceled'
            THEN order_id
        END
    ) AS IptalSiparisi,

    CAST(
        100.0 *
        COUNT(
            DISTINCT
            CASE
                WHEN order_status = 'canceled'
                THEN order_id
            END
        )
        /
        NULLIF(
            COUNT(DISTINCT order_id),
            0
        )
        AS DECIMAL(10,2)
    ) AS IptalOrani
FROM dbo.Orders_Staging;
GO


/* ================================================================
   13. GELECEK TAHMİNİ
   ================================================================ */


/* ------------------------------------------------
   SORU 15 - Önümüzdeki ay satışlar ne kadar olacak?

   Basit tahmin yöntemi:
   Son 4 tam ayın ortalama satış tutarı.
   ------------------------------------------------ */

WITH AylikSatis AS
(
    SELECT
        SatisYili,
        SatisAyi,
        SiparisSayisi,
        ToplamSatis
    FROM dbo.vw_MonthlySales
    WHERE SiparisSayisi > 1
),
Son4Ay AS
(
    SELECT TOP 4
        SatisYili,
        SatisAyi,
        ToplamSatis
    FROM AylikSatis
    ORDER BY
        SatisYili DESC,
        SatisAyi DESC
)
SELECT
    CAST(
        AVG(ToplamSatis)
        AS DECIMAL(18,2)
    ) AS GelecekAyTahminiSatis
FROM Son4Ay;
GO


/* ------------------------------------------------
   SORU 16 - Hangi ürünlerin stokları tükenebilir?

   Gerçek stok miktarı olmadığı için stok tükenme zamanı
   hesaplanamaz.

   Bunun yerine son 3 tam ayda satış hızı yüksek ürünler
   gösterilmektedir.
   ------------------------------------------------ */

WITH Son3Ay AS
(
    SELECT TOP 3
        SatisYili,
        SatisAyi
    FROM dbo.vw_MonthlySales
    WHERE SiparisSayisi > 1
    ORDER BY
        SatisYili DESC,
        SatisAyi DESC
)
SELECT TOP 20
    o.product_id AS ProductID,
    COUNT(DISTINCT o.order_id) AS SatisAdedi,
    SUM(
        TRY_CONVERT(DECIMAL(18,2), o.total_price)
    ) AS ToplamSatis
FROM dbo.Orders_Staging AS o
INNER JOIN Son3Ay AS a
    ON YEAR(
        TRY_CONVERT(
            DATETIME,
            o.order_purchase_timestamp
        )
    ) = a.SatisYili
    AND
    MONTH(
        TRY_CONVERT(
            DATETIME,
            o.order_purchase_timestamp
        )
    ) = a.SatisAyi
WHERE o.product_id IS NOT NULL
GROUP BY o.product_id
ORDER BY SatisAdedi DESC;
GO


/* ------------------------------------------------
   SORU 17 - Kampanya yapılırsa satışlar nasıl değişebilir?

   
   %10 indirim uygulanıyor ve satış adedinin değişmediği
   varsayılıyor.
   ------------------------------------------------ */

SELECT
    SUM(
        TRY_CONVERT(DECIMAL(18,2), price)
    ) AS MevcutSatis,

    SUM(
        TRY_CONVERT(DECIMAL(18,2), price) * 0.90
    ) AS IndirimliSatis,

    SUM(
        TRY_CONVERT(DECIMAL(18,2), price) * 0.90
    )
    -
    SUM(
        TRY_CONVERT(DECIMAL(18,2), price)
    ) AS GelirFarki
FROM dbo.Orders_Staging
WHERE order_status = 'delivered';
GO


/* ================================================================
   14. STORED PROCEDURE
   ================================================================ */


/* ------------------------------------------------
   14.1 spMonthlySales
   ------------------------------------------------ */

CREATE OR ALTER PROCEDURE dbo.spMonthlySales
    @Yil INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        YEAR(
            TRY_CONVERT(
                DATETIME,
                order_purchase_timestamp
            )
        ) AS SatisYili,

        MONTH(
            TRY_CONVERT(
                DATETIME,
                order_purchase_timestamp
            )
        ) AS SatisAyi,

        COUNT(DISTINCT order_id) AS SiparisSayisi,

        SUM(
            TRY_CONVERT(
                DECIMAL(18,2),
                total_price
            )
        ) AS ToplamSatis

    FROM dbo.Orders_Staging

    WHERE YEAR(
        TRY_CONVERT(
            DATETIME,
            order_purchase_timestamp
        )
    ) = @Yil

    GROUP BY
        YEAR(
            TRY_CONVERT(
                DATETIME,
                order_purchase_timestamp
            )
        ),
        MONTH(
            TRY_CONVERT(
                DATETIME,
                order_purchase_timestamp
            )
        )

    ORDER BY SatisAyi;
END;
GO


/* Procedure test */
EXEC dbo.spMonthlySales @Yil = 2018;
GO


/* ------------------------------------------------
   14.2 spTopCustomers
   ------------------------------------------------ */

CREATE OR ALTER PROCEDURE dbo.spTopCustomers
    @TopN INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        customer_unique_id AS CustomerID,
        COUNT(DISTINCT order_id) AS SiparisSayisi,
        SUM(
            TRY_CONVERT(
                DECIMAL(18,2),
                total_price
            )
        ) AS ToplamHarcama

    FROM dbo.Orders_Staging

    WHERE customer_unique_id IS NOT NULL
      AND total_price IS NOT NULL

    GROUP BY customer_unique_id

    ORDER BY ToplamHarcama DESC;
END;
GO


/* Procedure test */
EXEC dbo.spTopCustomers @TopN = 20;
GO


/* ================================================================
   15. TRIGGER
   ================================================================ */


/* Log tablosu */
IF OBJECT_ID('dbo.OrderStatusLog','U') IS NULL
BEGIN

    CREATE TABLE dbo.OrderStatusLog
    (
        LogID INT IDENTITY(1,1) PRIMARY KEY,

        OrderID VARCHAR(32),

        EskiDurum VARCHAR(30),

        YeniDurum VARCHAR(30),

        DegisimTarihi DATETIME
            DEFAULT GETDATE()
    );

END;
GO


/* ------------------------------------------------
   Sipariş durumu değişikliğini loglayan trigger
   ------------------------------------------------ */

CREATE OR ALTER TRIGGER dbo.trg_OrderStatusChange
ON dbo.Orders
AFTER UPDATE
AS
BEGIN

    SET NOCOUNT ON;

    INSERT INTO dbo.OrderStatusLog
    (
        OrderID,
        EskiDurum,
        YeniDurum
    )

    SELECT
        d.order_id,
        d.order_status,
        i.order_status

    FROM deleted AS d

    INNER JOIN inserted AS i
        ON d.order_id = i.order_id

    WHERE
        ISNULL(d.order_status,'')
        <>
        ISNULL(i.order_status,'');

END;
GO


/* Trigger kontrolü */
SELECT TOP 20 *
FROM dbo.OrderStatusLog
ORDER BY LogID DESC;
GO


/* ================================================================
   16. PERFORMANS ANALİZİ
   ================================================================ */

/*
   SSMS'te Ctrl + M ile Actual Execution Plan açılabilir.
*/

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

SELECT TOP 20
    CustomerID,
    SiparisSayisi,
    ToplamHarcama
FROM dbo.vw_TopCustomers
ORDER BY ToplamHarcama DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


/* ================================================================
   17. PERFORMANS İÇİN EK İNDEKS KONTROLÜ
   ================================================================ */

/*
   SQL Server Execution Plan çalıştırıldığında Orders_Staging
   üzerinde Missing Index önerisi görülebilir.

   Mevcut Primary Key ve indeksleri görmek için:
*/

SELECT
    t.name AS Tablo,
    i.name AS IndexAdi,
    i.type_desc AS IndexTipi,
    c.name AS Kolon
FROM sys.indexes i
INNER JOIN sys.index_columns ic
    ON i.object_id = ic.object_id
    AND i.index_id = ic.index_id
INNER JOIN sys.columns c
    ON ic.object_id = c.object_id
    AND ic.column_id = c.column_id
INNER JOIN sys.tables t
    ON i.object_id = t.object_id
WHERE t.is_ms_shipped = 0
ORDER BY t.name, i.name;
GO


/* ================================================================
   18. SON PROJE KONTROLÜ
   ================================================================ */


/* View kontrolü */
SELECT
    name AS ViewAdi
FROM sys.views
WHERE name IN
(
    'vw_MonthlySales',
    'vw_ReturnAnalysis',
    'vw_TopCustomers'
)
ORDER BY name;
GO


/* Procedure kontrolü */
SELECT
    name AS ProcedureAdi
FROM sys.procedures
WHERE name IN
(
    'spMonthlySales',
    'spTopCustomers'
)
ORDER BY name;
GO


/* Trigger kontrolü */
SELECT
    name AS TriggerAdi,
    OBJECT_NAME(parent_id) AS BagliTablo
FROM sys.triggers
WHERE name = 'trg_OrderStatusChange';
GO


/* OrderStatusLog kontrolü */
SELECT COUNT(*) AS LogKayitSayisi
FROM dbo.OrderStatusLog;
GO


/* ================================================================
   19. FINAL VERİ KONTROLÜ
   ================================================================ */

SELECT
    COUNT(*) AS StagingSatirSayisi,
    COUNT(DISTINCT order_id) AS FarkliSiparisSayisi
FROM dbo.Orders_Staging;
GO


/* ================================================================
   20. PROJEDE ELDE EDİLEN ÖRNEK SONUÇLAR
   ================================================================

   Tablo kayıtları:

   Customers       = 99441
   müşteriler      = 99441
   Orders          = 98666
   Orders_Staging  = 112650
   Products        = 32951
   products_clean  = 32951

   Sipariş doğrulama:

   Staging satırı       = 112650
   Farklı sipariş       = 98666

   Sipariş durumları:

   delivered     = 110197
   shipped       = 1185
   canceled      = 542
   invoiced      = 359
   processing    = 357
   unavailable   = 7
   approved      = 3

   Daha önce hesaplanan bazı analiz sonuçları:

   Toplam müşteri / tek siparişli müşteri / oran:
   95420 / 51891 / 54.38

   Tekrar alışveriş:
   95420 / 2913 / 3.05

   İptal siparişi:
   98666 / 461 / 0.47

   Toplam satış / toplam maliyet benzeri hesap:
   13221498.11 / 11899348.2990 / -1322149.81

   NOT:
   Son satırdaki maliyet/kâr hesabı veri setindeki gerçek maliyet
   alanına dayanmıyorsa resmi "gerçek kâr" olarak sunulmamalıdır.
   Proje tesliminde maliyet alanının bulunmadığı açıkça belirtilmelidir.

====================================================================
 PROJE SONU

 Yapılanlar:
 [X] Database oluşturma
 [X] Tablo/veri yapısı
 [X] Veri yükleme ve kontrol
 [X] Primary Key kontrolü
 [X] SQL sorguları
 [X] View oluşturma
 [X] Stored Procedure
 [X] Trigger
 [X] Performans analizi
 [X] Gelecek tahmini
 [X] Son kontroller

 Veri setinde bulunmayan alanlar:
 [!] Gerçek ürün maliyeti
 [!] Gerçek indirim
 [!] Stok miktarı
 [!] İade nedeni

 Bu nedenle bu dört alanla ilgili gerçek değer yapılmadı
====================================================================
*/

