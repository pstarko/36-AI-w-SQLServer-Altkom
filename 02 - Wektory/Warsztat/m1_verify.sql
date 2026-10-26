/* ============================================================
   WERYFIKACJA MODUŁU 1
   Wszystkie wiersze powinny mieć status OK.
   ============================================================ */
USE WektoryHelpdesk;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(100), Oczekiwane nvarchar(100), OK bit);
 
INSERT INTO #W SELECT 1, N'Wersja silnika: SQL Server 2025 (17.x) lub nowsza',
       CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50)), N'17.x',
       IIF(CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50)), 4) AS int) >= 17, 1, 0);
 
INSERT INTO #W SELECT 2, N'Liczba kategorii / tematów', CONCAT((SELECT COUNT(*) FROM dbo.Kategoria), N' / ', COUNT(*)),
       N'8 / 24', IIF(COUNT(*) = 24 AND (SELECT COUNT(*) FROM dbo.Kategoria) = 8, 1, 0) FROM dbo.Temat;
 
INSERT INTO #W SELECT 3, N'Liczba zgłoszeń w archiwum', CONCAT(COUNT(*), ''), N'1200', IIF(COUNT(*) = 1200, 1, 0)
FROM dbo.Zgloszenie;
 
INSERT INTO #W SELECT 4, N'Kolumna Embedding jest typu vector', TYPE_NAME(c.user_type_id), N'vector',
       IIF(TYPE_NAME(c.user_type_id) = N'vector', 1, 0)
FROM sys.columns AS c WHERE c.object_id = OBJECT_ID(N'dbo.Zgloszenie') AND c.name = N'Embedding';
 
INSERT INTO #W SELECT 5, N'Każdy embedding ma 32 wymiary', CONCAT(MIN(CAST(VECTORPROPERTY(Embedding, 'Dimensions') AS int)), N'–',
       MAX(CAST(VECTORPROPERTY(Embedding, 'Dimensions') AS int))), N'32–32',
       IIF(MIN(CAST(VECTORPROPERTY(Embedding, 'Dimensions') AS int)) = 32 AND MAX(CAST(VECTORPROPERTY(Embedding, 'Dimensions') AS int)) = 32, 1, 0)
FROM dbo.Zgloszenie;
 
INSERT INTO #W SELECT 6, N'Wektory są znormalizowane (długość = 1)',
       CONCAT(N'max odchylenie = ', CAST(MAX(ABS(VECTOR_NORM(Embedding, 'norm2') - 1)) AS decimal(9,6))), N'< 0,001',
       IIF(MAX(ABS(VECTOR_NORM(Embedding, 'norm2') - 1)) < 0.001, 1, 0)
FROM dbo.Zgloszenie;
 
INSERT INTO #W SELECT 7, N'Nowe zgłoszenia z embeddingiem', CONCAT(COUNT(Embedding), N' z ', COUNT(*)), N'10 z 10',
       IIF(COUNT(Embedding) = 10 AND COUNT(*) = 10, 1, 0)
FROM dbo.NoweZgloszenie;
 
INSERT INTO #W SELECT 8, N'Najczęstszy temat w archiwum', MAX(t.Tytul), N'Opóźniona przesyłka',
       IIF(MAX(t.Tytul) = N'Opóźniona przesyłka', 1, 0)
FROM (SELECT TOP (1) TematID FROM dbo.Zgloszenie GROUP BY TematID ORDER BY COUNT(*) DESC) AS x
JOIN dbo.Temat AS t ON t.TematID = x.TematID;
 
/* Testy funkcji wektorowych na przykładzie z ćwiczenia 1.2 */
DECLARE @a vector(3) = '[1, 0, 0]', @b vector(3) = '[0.8, 0.6, 0]', @c vector(3) = '[0, 0, 2]';
 
INSERT INTO #W SELECT 9, N'cosine(a, b)', CAST(CAST(VECTOR_DISTANCE('cosine', @a, @b) AS decimal(6,4)) AS nvarchar(20)), N'0,2000',
       IIF(ABS(VECTOR_DISTANCE('cosine', @a, @b) - 0.2) < 0.0001, 1, 0);
INSERT INTO #W SELECT 10, N'euclidean(a, c)', CAST(CAST(VECTOR_DISTANCE('euclidean', @a, @c) AS decimal(6,4)) AS nvarchar(20)), N'2,2361',
       IIF(ABS(VECTOR_DISTANCE('euclidean', @a, @c) - SQRT(5.0)) < 0.0001, 1, 0);
INSERT INTO #W SELECT 11, N'dot(a, b) – ujemny iloczyn skalarny', CAST(CAST(VECTOR_DISTANCE('dot', @a, @b) AS decimal(6,4)) AS nvarchar(20)), N'-0,8000',
       IIF(ABS(VECTOR_DISTANCE('dot', @a, @b) + 0.8) < 0.0001, 1, 0);
INSERT INTO #W SELECT 12, N'norm2(c) i norm2(normalize(c))',
       CONCAT(VECTOR_NORM(@c, 'norm2'), N' / ', VECTOR_NORM(VECTOR_NORMALIZE(@c, 'norm2'), 'norm2')), N'2 / 1',
       IIF(ABS(VECTOR_NORM(@c, 'norm2') - 2) < 0.0001 AND ABS(VECTOR_NORM(VECTOR_NORMALIZE(@c, 'norm2'), 'norm2') - 1) < 0.0001, 1, 0);
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 1 zaliczony – możesz przejść dalej',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;
