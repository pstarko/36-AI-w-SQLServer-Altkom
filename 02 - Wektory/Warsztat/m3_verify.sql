/* ============================================================
   WERYFIKACJA MODUŁU 3
   ============================================================ */
USE WektoryHelpdesk;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(100), Oczekiwane nvarchar(100), OK bit);
 
INSERT INTO #W SELECT 1, N'Centroidy dla wszystkich kategorii', CONCAT(COUNT(*), ''), N'8', IIF(COUNT(*) = 8, 1, 0)
FROM dbo.CentroidKategorii;
 
INSERT INTO #W SELECT 2, N'Centroidy znormalizowane', CONCAT(N'max odchylenie = ', CAST(MAX(ABS(VECTOR_NORM(Centroid, 'norm2') - 1)) AS decimal(9,6))),
       N'< 0,001', IIF(MAX(ABS(VECTOR_NORM(Centroid, 'norm2') - 1)) < 0.001, 1, 0)
FROM dbo.CentroidKategorii;
 
INSERT INTO #W SELECT 3, N'Suma zgłoszeń w centroidach', CONCAT(SUM(LiczbaZgloszen), ''), N'1200', IIF(SUM(LiczbaZgloszen) = 1200, 1, 0)
FROM dbo.CentroidKategorii;
 
INSERT INTO #W SELECT 4, N'Wykryte podejrzane zgłoszenia', CONCAT(COUNT(*), ''), N'12', IIF(COUNT(*) = 12, 1, 0)
FROM dbo.PodejrzaneZgloszenie;
 
INSERT INTO #W SELECT 5, N'Trafność audytu (wykryte celowo błędne etykiety)',
       CONCAT(COUNT(*), N' z 12'), N'12 z 12', IIF(COUNT(*) = 12, 1, 0)
FROM dbo.PodejrzaneZgloszenie
WHERE ZgloszenieID IN (37, 141, 222, 305, 388, 456, 529, 610, 777, 853, 964, 1101);
 
/* Po korekcie (ćw. 3.3) żadne zgłoszenie nie powinno być bliżej obcego centroidu */
INSERT INTO #W SELECT 6, N'Po korekcie: zgłoszenia bliżej obcego centroidu', CONCAT(COUNT(*), ''), N'0', IIF(COUNT(*) = 0, 1, 0)
FROM dbo.Zgloszenie AS z
JOIN dbo.Temat AS t ON t.TematID = z.TematID
CROSS APPLY (SELECT TOP (1) c.KategoriaID FROM dbo.CentroidKategorii AS c
             ORDER BY VECTOR_DISTANCE('cosine', z.Embedding, c.Centroid)) AS n
WHERE n.KategoriaID <> t.KategoriaID;
 
INSERT INTO #W SELECT 7, N'Korekta przywróciła właściwy temat (na podstawie treści)',
       CONCAT(COUNT(*), N' z 12'), N'12 z 12', IIF(COUNT(*) = 12, 1, 0)
FROM dbo.Zgloszenie AS z
JOIN (VALUES (37, 13), (141, 7), (222, 21), (305, 1), (388, 23), (456, 13),
             (529, 7), (610, 12), (777, 1), (853, 23), (964, 18), (1101, 7)) AS w (ZgloszenieID, WlasciwyTematID)
  ON w.ZgloszenieID = z.ZgloszenieID AND w.WlasciwyTematID = z.TematID;
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 3 zaliczony – możesz przejść dalej',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;
