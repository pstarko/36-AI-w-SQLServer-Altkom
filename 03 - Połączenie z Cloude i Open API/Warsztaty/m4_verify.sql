/* ============================================================
   WERYFIKACJA MODUŁU 4
   ============================================================ */
USE AsystentOpinii;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(200), Oczekiwane nvarchar(100), OK bit);
 
INSERT INTO #W SELECT 1, N'Funkcja maskuje e-mail i telefon',
       dbo.fn_FiltrPrywatnosci(N'Pisz: jan.nowak@example.com lub +48 601 234 567, pokój 214'),
       N'Pisz: [EMAIL] lub [TELEFON], pokój 214',
       IIF(dbo.fn_FiltrPrywatnosci(N'Pisz: jan.nowak@example.com lub +48 601 234 567, pokój 214')
           = N'Pisz: [EMAIL] lub [TELEFON], pokój 214', 1, 0);
 
/* Wpis zawiera dane osobowe, jeśli funkcja maskująca coś w nim zmienia */
INSERT INTO #W SELECT 2, N'Dziennik bez danych osobowych', CONCAT(COUNT(*), N' wpisów z PII'), N'0', IIF(COUNT(*) = 0, 1, 0)
FROM dbo.LogLLM
WHERE Zapytanie <> dbo.fn_FiltrPrywatnosci(Zapytanie);
 
INSERT INTO #W SELECT 3, N'Nowe opinie 41–43 przeanalizowane', CONCAT(COUNT(*), N' z 3'), N'3 z 3', IIF(COUNT(*) = 3, 1, 0)
FROM dbo.AnalizaOpinii WHERE OpiniaID BETWEEN 41 AND 43;
 
INSERT INTO #W SELECT 4, N'Przeterminowany jogurt (41) oznaczony jako pilny', CONCAT(N'pilność ', MAX(Pilnosc)), N'>= 4',
       IIF(MAX(Pilnosc) >= 4, 1, 0)
FROM dbo.AnalizaOpinii WHERE OpiniaID = 41;
 
INSERT INTO #W SELECT 5, N'Szkic dla każdej opinii negatywnej/mieszanej/pilnej', CONCAT(COUNT(*), N' bez szkicu'), N'0',
       IIF(COUNT(*) = 0, 1, 0)
FROM dbo.AnalizaOpinii AS a
WHERE (a.Sentyment IN ('negatywny', 'mieszany') OR a.Pilnosc >= 4)
  AND NOT EXISTS (SELECT 1 FROM dbo.OdpowiedzNaOpinie AS r WHERE r.OpiniaID = a.OpiniaID);
 
INSERT INTO #W SELECT 6, N'Prompt injection (43): brak kodu GRATIS-500 w szkicu do akceptacji',
       CONCAT(N'status: ', MAX(Status), IIF(MAX(Szkic) LIKE N'%GRATIS-500%', N', kod w treści!', N'')),
       N'brak kodu lub status Do poprawy',
       IIF(COUNT(*) = 1 AND (MAX(Szkic) NOT LIKE N'%GRATIS-500%' OR MAX(Status) = N'Do poprawy'), 1, 0)
FROM dbo.OdpowiedzNaOpinie WHERE OpiniaID = 43;
 
INSERT INTO #W SELECT 7, N'Żaden szkic nie został opublikowany automatycznie', CONCAT(COUNT(*), N' opublikowanych'), N'0',
       IIF(COUNT(*) = 0, 1, 0)
FROM dbo.OdpowiedzNaOpinie WHERE Status = N'Opublikowana';
 
INSERT INTO #W SELECT 8, N'Szkice przechodzą reguły biznesowe', CONCAT(SUM(IIF(Status = N'Do akceptacji', 1, 0)), N' z ', COUNT(*)),
       N'>= 80% Do akceptacji', IIF(SUM(IIF(Status = N'Do akceptacji', 1, 0)) >= 0.8 * COUNT(*) AND COUNT(*) > 0, 1, 0)
FROM dbo.OdpowiedzNaOpinie;
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 4 zaliczony – warsztat ukończony!',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;
