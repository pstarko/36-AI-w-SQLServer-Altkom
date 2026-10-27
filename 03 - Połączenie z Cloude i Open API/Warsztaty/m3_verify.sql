/* ============================================================
   WERYFIKACJA MODUŁU 3
   Uwaga: test 7 uruchamia przetwarzanie wsadowe jeszcze raz –
   przy poprawnej implementacji nie wykona żadnego wywołania API.
   ============================================================ */
USE AsystentOpinii;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(200), Oczekiwane nvarchar(100), OK bit);
DECLARE @Wersja int = (SELECT MAX(Wersja) FROM dbo.PromptSzablon WHERE Nazwa = 'analiza_opinii');
 
INSERT INTO #W SELECT 1, N'Wszystkie opinie mają aktualną analizę', CONCAT(COUNT(*), N' z 40'), N'40 z 40', IIF(COUNT(*) = 40, 1, 0)
FROM dbo.AnalizaOpinii AS a JOIN dbo.Opinia AS o ON o.OpiniaID = a.OpiniaID
WHERE a.WersjaPromptu = @Wersja AND a.HashTresci = HASHBYTES('SHA2_256', o.Tresc);
 
INSERT INTO #W SELECT 2, N'Trafność sentymentu (opinie jednoznaczne)',
       CONCAT(SUM(IIF(a.Sentyment = k.OczekiwanySentyment, 1, 0)), N' z ', COUNT(*)), N'>= 90%',
       IIF(SUM(IIF(a.Sentyment = k.OczekiwanySentyment, 1, 0)) >= 0.9 * COUNT(*), 1, 0)
FROM dbo.AnalizaOpinii AS a JOIN dbo.KluczOpinii AS k ON k.OpiniaID = a.OpiniaID
WHERE k.OczekiwanySentyment IS NOT NULL;
 
INSERT INTO #W SELECT 3, N'Trafność kategorii głównej (opinie jednoznaczne)',
       CONCAT(SUM(IIF(a.KategoriaGlowna = k.OczekiwanaKategoria, 1, 0)), N' z ', COUNT(*)), N'>= 75%',
       IIF(SUM(IIF(a.KategoriaGlowna = k.OczekiwanaKategoria, 1, 0)) >= 0.75 * COUNT(*), 1, 0)
FROM dbo.AnalizaOpinii AS a JOIN dbo.KluczOpinii AS k ON k.OpiniaID = a.OpiniaID
WHERE k.OczekiwanaKategoria IS NOT NULL;
 
INSERT INTO #W SELECT 4, N'Sprawy krytyczne (pluskwy, kradzież, brudna woda) mają pilność >= 4',
       CONCAT(SUM(IIF(Pilnosc >= 4, 1, 0)), N' z 3'), N'3 z 3', IIF(SUM(IIF(Pilnosc >= 4, 1, 0)) = 3, 1, 0)
FROM dbo.AnalizaOpinii WHERE OpiniaID IN (6, 14, 26);
 
INSERT INTO #W SELECT 5, N'Pochwały nie są oznaczane jako pilne (pilność <= 2)',
       CONCAT(SUM(IIF(Pilnosc <= 2, 1, 0)), N' z 6'), N'>= 5 z 6', IIF(SUM(IIF(Pilnosc <= 2, 1, 0)) >= 5, 1, 0)
FROM dbo.AnalizaOpinii WHERE OpiniaID IN (1, 7, 15, 23, 32, 37);
 
INSERT INTO #W SELECT 6, N'Koszt etapu M3 mieści się w budżecie', CONCAT(CAST(ISNULL(SUM(KosztUSD), 0) AS decimal(12,6)), N' USD'),
       N'< 0,50 USD', IIF(ISNULL(SUM(KosztUSD), 0) < 0.50 AND COUNT(*) > 0, 1, 0)
FROM dbo.LogLLM WHERE Etap = 'M3-wsad';
 
/* Test idempotentności: ponowne uruchomienie nie może wywoływać API */
DECLARE @Przed int = (SELECT COUNT(*) FROM dbo.LogLLM);
EXEC dbo.usp_AnalizujWszystkie @Etap = 'M3-weryfikacja', @ZwrocPodsumowanie = 0;
INSERT INTO #W SELECT 7, N'Ponowne uruchomienie = 0 nowych wywołań API',
       CONCAT((SELECT COUNT(*) FROM dbo.LogLLM) - @Przed, N' wywołań'), N'0 wywołań',
       IIF((SELECT COUNT(*) FROM dbo.LogLLM) - @Przed = 0, 1, 0);
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 3 zaliczony – możesz przejść dalej',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;
