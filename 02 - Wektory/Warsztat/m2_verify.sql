/* ============================================================
   WERYFIKACJA MODUŁU 2
   ============================================================ */
USE WektoryHelpdesk;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(100), Oczekiwane nvarchar(100), OK bit);
 
INSERT INTO #W SELECT 1, N'Procedura dbo.usp_ProponujTemat istnieje', IIF(OBJECT_ID(N'dbo.usp_ProponujTemat') IS NULL, N'brak', N'jest'),
       N'jest', IIF(OBJECT_ID(N'dbo.usp_ProponujTemat') IS NULL, 0, 1);
 
INSERT INTO #W SELECT 2, N'Propozycje dla wszystkich nowych zgłoszeń', CONCAT(COUNT(*), ''), N'10', IIF(COUNT(*) = 10, 1, 0)
FROM dbo.Propozycja;
 
INSERT INTO #W SELECT 3, N'Poprawny temat (zgłoszenia jednoznaczne 1–9)',
       CONCAT(SUM(IIF(p.ProponowanyTematID = k.OczekiwanyTematID, 1, 0)), N' z 9'), N'9 z 9',
       IIF(SUM(IIF(p.ProponowanyTematID = k.OczekiwanyTematID, 1, 0)) = 9, 1, 0)
FROM dbo.Propozycja AS p JOIN dbo.KluczWeryfikacji AS k ON k.NoweID = p.NoweID
WHERE k.OczekiwanyTematID IS NOT NULL;
 
INSERT INTO #W SELECT 4, N'Zgłoszenia jednoznaczne obsłużone automatycznie',
       CONCAT(SUM(IIF(p.Decyzja = N'Automatyczna odpowiedź', 1, 0)), N' z 9'), N'9 z 9',
       IIF(SUM(IIF(p.Decyzja = N'Automatyczna odpowiedź', 1, 0)) = 9, 1, 0)
FROM dbo.Propozycja AS p JOIN dbo.KluczWeryfikacji AS k ON k.NoweID = p.NoweID
WHERE k.OczekiwanyTematID IS NOT NULL;
 
INSERT INTO #W SELECT 5, N'Zgłoszenie niejednoznaczne (nr 10) trafia do konsultanta', p.Decyzja, N'Do konsultanta',
       IIF(p.Decyzja = N'Do konsultanta', 1, 0)
FROM dbo.Propozycja AS p WHERE p.NoweID = 10;
 
INSERT INTO #W SELECT 6, N'Podobieństwo zgłoszenia 10 wyraźnie niższe niż pozostałych',
       CONCAT(CAST(MAX(IIF(NoweID = 10, MaksPodobienstwo, NULL)) AS decimal(4,2)), N' vs min. ',
              CAST(MIN(IIF(NoweID < 10, MaksPodobienstwo, NULL)) AS decimal(4,2))),
       N'< 0,85 vs > 0,90',
       IIF(MAX(IIF(NoweID = 10, MaksPodobienstwo, NULL)) < 0.85 AND MIN(IIF(NoweID < 10, MaksPodobienstwo, NULL)) > 0.90, 1, 0)
FROM dbo.Propozycja;
 
/* Metryki dla wektorów znormalizowanych: ta sama dziesiątka najbliższych sąsiadów */
DECLARE @q vector(32) = (SELECT Embedding FROM dbo.NoweZgloszenie WHERE NoweID = 3);
INSERT INTO #W SELECT 7, N'cosine i euclidean dają te same 10 najbliższych (zgłoszenie 3)',
       CONCAT(COUNT(*), N' z 10 wspólnych'), N'>= 9 z 10', IIF(COUNT(*) >= 9, 1, 0)
FROM (SELECT TOP (10) ZgloszenieID FROM dbo.Zgloszenie ORDER BY VECTOR_DISTANCE('cosine', @q, Embedding)) AS a
JOIN (SELECT TOP (10) ZgloszenieID FROM dbo.Zgloszenie ORDER BY VECTOR_DISTANCE('euclidean', @q, Embedding)) AS b
  ON a.ZgloszenieID = b.ZgloszenieID;
 
INSERT INTO #W SELECT 8, N'Najbliższy sąsiad zgłoszenia 3 ma inny temat niż większość',
       CONCAT(N'najbliższy: temat ', x.TematID), N'temat 16 (błędna etykieta!)',
       IIF(x.TematID = 16, 1, 0)
FROM (SELECT TOP (1) TematID FROM dbo.Zgloszenie ORDER BY VECTOR_DISTANCE('cosine', @q, Embedding)) AS x;
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 2 zaliczony – możesz przejść dalej',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;
