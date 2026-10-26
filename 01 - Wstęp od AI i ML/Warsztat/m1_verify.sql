/* ============================================================
   WERYFIKACJA MODUŁU 1
   Wszystkie wiersze powinny mieć status OK.
   ============================================================ */
USE LodyPrognoza;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W, #Py;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(100), Oczekiwane nvarchar(100), OK bit);
 
INSERT INTO #W
SELECT 1, N'Usługa external scripts jest włączona', CONCAT(CAST(value_in_use AS int), ''), N'1',
       IIF(CAST(value_in_use AS int) = 1, 1, 0)
FROM sys.configurations WHERE name = N'external scripts enabled';
 
INSERT INTO #W SELECT 2, N'Liczba punktów sprzedaży', CONCAT(COUNT(*), ''), N'4', IIF(COUNT(*) = 4, 1, 0) FROM dbo.Punkt;
INSERT INTO #W SELECT 3, N'Liczba dni w kalendarzu (4 sezony x 153 dni)', CONCAT(COUNT(*), ''), N'612', IIF(COUNT(*) = 612, 1, 0) FROM dbo.Kalendarz;
INSERT INTO #W SELECT 4, N'Liczba dni z pogodą historyczną', CONCAT(COUNT(*), ''), N'459', IIF(COUNT(*) = 459, 1, 0) FROM dbo.Pogoda;
INSERT INTO #W SELECT 5, N'Liczba wierszy sprzedaży', CONCAT(COUNT(*), ''), N'1836', IIF(COUNT(*) = 1836, 1, 0) FROM dbo.Sprzedaz;
INSERT INTO #W SELECT 6, N'Dni bez pomiaru temperatury (celowe braki)', CONCAT(COUNT(*), ''), N'3', IIF(COUNT(*) = 3, 1, 0) FROM dbo.Pogoda WHERE TempMax IS NULL;
INSERT INTO #W SELECT 7, N'Łączna sprzedaż 2023–2025 [porcje]', FORMAT(SUM(LiczbaPorcji), 'N0', 'pl-PL'), N'ok. 362 290',
       IIF(SUM(LiczbaPorcji) BETWEEN 361900 AND 362700, 1, 0) FROM dbo.Sprzedaz;
INSERT INTO #W SELECT 8, N'Dni z promocją (historycznie)', CONCAT(SUM(CAST(Promocja AS int)), ''), N'ok. 156',
       IIF(SUM(CAST(Promocja AS int)) BETWEEN 150 AND 162, 1, 0) FROM dbo.Sprzedaz;
INSERT INTO #W SELECT 9, N'Dni prognozy pogody', CONCAT(COUNT(*), ''), N'14', IIF(COUNT(*) = 14, 1, 0) FROM dbo.PrognozaPogody;
 
/* Test Pythona – jeśli ta część zgłosi błąd, wróć do Załącznika A */
CREATE TABLE #Py (Pakiet nvarchar(50), Wersja nvarchar(50));
INSERT INTO #Py (Pakiet, Wersja)
EXEC sys.sp_execute_external_script
     @language = N'Python',
     @script   = N'
import sys, pandas, numpy, sklearn
OutputDataSet = pandas.DataFrame({
    "Pakiet": ["python", "pandas", "numpy", "scikit-learn"],
    "Wersja": [sys.version.split()[0], pandas.__version__, numpy.__version__, sklearn.__version__]})
';
 
INSERT INTO #W SELECT 10, N'Python odpowiada i widzi pakiety', CONCAT(COUNT(*), N' pakiety'), N'4 pakiety', IIF(COUNT(*) = 4, 1, 0) FROM #Py;
INSERT INTO #W SELECT 11, N'Wersja Pythona 3.10.x', MAX(Wersja), N'3.10.x', IIF(MAX(Wersja) LIKE '3.10.%', 1, 0) FROM #Py WHERE Pakiet = N'python';
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 1 zaliczony – możesz przejść dalej',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;
