/* ============================================================
   WERYFIKACJA MODUŁU 2
   ============================================================ */
USE AsystentOpinii;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(200), Oczekiwane nvarchar(100), OK bit);
 
INSERT INTO #W SELECT 1, N'Prompt analiza_opinii zapisany w bazie', CONCAT(N'wersje: ', COUNT(*)), N'>= 1', IIF(COUNT(*) >= 1, 1, 0)
FROM dbo.PromptSzablon WHERE Nazwa = 'analiza_opinii';
 
INSERT INTO #W SELECT 2, N'Przeanalizowane opinie 1–5', CONCAT(COUNT(*), ''), N'5', IIF(COUNT(*) = 5, 1, 0)
FROM dbo.AnalizaOpinii WHERE OpiniaID BETWEEN 1 AND 5;
 
INSERT INTO #W SELECT 3, N'Wszystkie wartości ze słownika (sentyment, kategoria, pilność 1–5)',
       CONCAT(COUNT(*), N' niepoprawnych'), N'0', IIF(COUNT(*) = 0, 1, 0)
FROM dbo.AnalizaOpinii
WHERE Sentyment NOT IN ('pozytywny', 'negatywny', 'mieszany', 'neutralny')
   OR KategoriaGlowna NOT IN ('pokoj', 'czystosc', 'obsluga', 'jedzenie', 'halas', 'cena', 'lokalizacja', 'internet', 'udogodnienia', 'inne')
   OR Pilnosc NOT BETWEEN 1 AND 5
   OR ISJSON(Kategorie, ARRAY) <> 1;
 
INSERT INTO #W SELECT 4, N'Sentyment zgodny z kluczem (opinie 1–5)', CONCAT(SUM(IIF(a.Sentyment = k.OczekiwanySentyment, 1, 0)), N' z 5'),
       N'>= 4 z 5', IIF(SUM(IIF(a.Sentyment = k.OczekiwanySentyment, 1, 0)) >= 4, 1, 0)
FROM dbo.AnalizaOpinii AS a JOIN dbo.KluczOpinii AS k ON k.OpiniaID = a.OpiniaID
WHERE a.OpiniaID BETWEEN 1 AND 5;
 
INSERT INTO #W SELECT 5, N'Opinia 4 rozpoznana jako angielska', MAX(Jezyk), N'en', IIF(MAX(Jezyk) = 'en', 1, 0)
FROM dbo.AnalizaOpinii WHERE OpiniaID = 4;
 
INSERT INTO #W SELECT 6, N'Streszczenia krótkie (do 150 znaków)', CONCAT(N'max ', MAX(LEN(Streszczenie)), N' znaków'), N'<= 150',
       IIF(MAX(LEN(Streszczenie)) <= 150, 1, 0)
FROM dbo.AnalizaOpinii;
 
INSERT INTO #W SELECT 7, N'Każda analiza powiązana z wpisem w dzienniku', CONCAT(COUNT(*), N' bez wpisu'), N'0', IIF(COUNT(*) = 0, 1, 0)
FROM dbo.AnalizaOpinii AS a WHERE NOT EXISTS (SELECT 1 FROM dbo.LogLLM AS l WHERE l.LogID = a.LogID AND l.KodHTTP = 200);
 
INSERT INTO #W SELECT 8, N'Opinia 2 (brud w pokoju) – kategoria czystość', MAX(KategoriaGlowna), N'czystosc',
       IIF(MAX(KategoriaGlowna) = 'czystosc', 1, 0)
FROM dbo.AnalizaOpinii WHERE OpiniaID = 2;
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 2 zaliczony – możesz przejść dalej',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;


--select * from dbo.LogLLM 