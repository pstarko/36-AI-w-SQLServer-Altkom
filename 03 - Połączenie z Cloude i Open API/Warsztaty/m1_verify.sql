/* ============================================================
   WERYFIKACJA MODUŁU 1
   Uwaga: test 10 wykonuje jedno prawdziwe wywołanie API.
   ============================================================ */
USE AsystentOpinii;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(200), Oczekiwane nvarchar(100), OK bit);
 
INSERT INTO #W SELECT 1, N'Wywołania REST włączone na serwerze', CONCAT(CAST(value_in_use AS int), ''), N'1',
       IIF(CAST(value_in_use AS int) = 1, 1, 0)
FROM sys.configurations WHERE name = N'external rest endpoint enabled';
 
INSERT INTO #W SELECT 2, N'Klucz główny bazy istnieje', CONCAT(COUNT(*), ''), N'1', IIF(COUNT(*) = 1, 1, 0)
FROM sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##';
 
INSERT INTO #W SELECT 3, N'Dokładnie jeden aktywny dostawca', CONCAT(COUNT(*), N': ', MAX(Dostawca)), N'1',
       IIF(COUNT(*) = 1, 1, 0)
FROM dbo.KonfiguracjaLLM WHERE CzyAktywny = 1;
 
INSERT INTO #W SELECT 4, N'Poświadczenie dla aktywnego dostawcy', COALESCE(MAX(c.name), N'brak'), N'nazwa = URL dostawcy',
       IIF(COUNT(c.name) = 1, 1, 0)
FROM dbo.KonfiguracjaLLM AS k
LEFT JOIN sys.database_scoped_credentials AS c ON c.name = k.NazwaPoswiadczenia
WHERE k.CzyAktywny = 1;
 
INSERT INTO #W SELECT 5, N'Dane: hotele / opinie', CONCAT((SELECT COUNT(*) FROM dbo.Hotel), N' / ', COUNT(*)), N'3 / 40',
       IIF(COUNT(*) = 40 AND (SELECT COUNT(*) FROM dbo.Hotel) = 3, 1, 0)
FROM dbo.Opinia;
 
INSERT INTO #W SELECT 6, N'Udane wywołanie zapisane w dzienniku (HTTP 200)', CONCAT(COUNT(*), N' wywołań'), N'>= 1',
       IIF(COUNT(*) >= 1, 1, 0)
FROM dbo.LogLLM WHERE KodHTTP = 200 AND Blad IS NULL;
 
INSERT INTO #W SELECT 7, N'Dziennik zawiera tokeny i koszt', CONCAT(N'we: ', MAX(TokenyWe), N', wy: ', MAX(TokenyWy)), N'> 0',
       IIF(MAX(TokenyWe) > 0 AND MAX(TokenyWy) > 0 AND MAX(KosztUSD) > 0, 1, 0)
FROM dbo.LogLLM WHERE KodHTTP = 200;
 
INSERT INTO #W SELECT 8, N'Test ze stolicą zwrócił „Warszawa”', LEFT(MAX(Odpowiedz), 50), N'Warszawa',
       IIF(MAX(Odpowiedz) LIKE N'%Warszaw%', 1, 0)
FROM dbo.LogLLM WHERE Etap = 'M1-test' AND KodHTTP = 200;
 
INSERT INTO #W SELECT 9, N'Klucz API nie trafia do dziennika', CONCAT(COUNT(*), N' podejrzanych wpisów'), N'0',
       IIF(COUNT(*) = 0, 1, 0)
FROM dbo.LogLLM WHERE Zapytanie LIKE N'%x-api-key%' OR Zapytanie LIKE N'%Bearer%' OR Zapytanie LIKE N'%sk-%';
 
/* Test na żywo przez procedurę */
DECLARE @Odp nvarchar(max);
BEGIN TRY
    EXEC dbo.usp_LLM_Zapytaj @System = N'Odpowiadasz wyłącznie słowem OK.', @Prompt = N'Test połączenia.',
                             @Etap = 'M1-weryfikacja', @Odpowiedz = @Odp OUTPUT;
END TRY
BEGIN CATCH
    SET @Odp = ERROR_MESSAGE();
END CATCH;
INSERT INTO #W SELECT 10, N'Procedura usp_LLM_Zapytaj działa na żywo', LEFT(@Odp, 100), N'OK',
       IIF(@Odp LIKE N'%OK%' AND @Odp NOT LIKE N'%Błąd%', 1, 0);
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 1 zaliczony – możesz przejść dalej',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;
