/* ============================================================
   WERYFIKACJA MODUŁU 4
   ============================================================ */
USE WektoryHelpdesk;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(100), Oczekiwane nvarchar(100), OK bit);
 
INSERT INTO #W SELECT 1, N'PREVIEW_FEATURES włączone w bazie', CONCAT(CAST(value AS int), ''), N'1', IIF(CAST(value AS int) = 1, 1, 0)
FROM sys.database_scoped_configurations WHERE name = N'PREVIEW_FEATURES';
 
INSERT INTO #W SELECT 2, N'Indeks wektorowy na dbo.Zgloszenie', CONCAT(COUNT(*), N' indeks(y)'), N'1 indeks(y)', IIF(COUNT(*) = 1, 1, 0)
FROM sys.vector_indexes WHERE object_id = OBJECT_ID(N'dbo.Zgloszenie');
 
INSERT INTO #W SELECT 3, N'Metryka indeksu zgodna z zapytaniami', MAX(CAST(distance_metric AS nvarchar(20))), N'cosine',
       IIF(LOWER(MAX(CAST(distance_metric AS nvarchar(20)))) = N'cosine', 1, 0)
FROM sys.vector_indexes WHERE object_id = OBJECT_ID(N'dbo.Zgloszenie');
 
INSERT INTO #W SELECT 4, N'Wyniki ANN dla 10 zgłoszeń x 10 sąsiadów', CONCAT(COUNT(*), ''), N'100', IIF(COUNT(*) = 100, 1, 0)
FROM dbo.WynikANN;
 
INSERT INTO #W SELECT 5, N'Wyniki dokładne (kNN) – 100 wierszy', CONCAT(COUNT(*), ''), N'100', IIF(COUNT(*) = 100, 1, 0)
FROM dbo.WynikDokladny;
 
INSERT INTO #W SELECT 6, N'Średni recall@10 indeksu ANN', CAST(CAST(COUNT(a.ZgloszenieID) / 100.0 AS decimal(3,2)) AS nvarchar(10)),
       N'>= 0,90', IIF(COUNT(a.ZgloszenieID) >= 90, 1, 0)
FROM dbo.WynikDokladny AS d
LEFT JOIN dbo.WynikANN AS a ON a.NoweID = d.NoweID AND a.ZgloszenieID = d.ZgloszenieID;
 
INSERT INTO #W SELECT 7, N'ANN dla zgłoszenia 9 zwraca zgłoszenia o doręczeniu',
       CONCAT(SUM(IIF(z.TematID = 9, 1, 0)), N' z ', COUNT(*)), N'>= 8 z 10',
       IIF(SUM(IIF(z.TematID = 9, 1, 0)) >= 8, 1, 0)
FROM dbo.WynikANN AS a JOIN dbo.Zgloszenie AS z ON z.ZgloszenieID = a.ZgloszenieID
WHERE a.NoweID = 9;
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 4 zaliczony – warsztat ukończony!',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;
