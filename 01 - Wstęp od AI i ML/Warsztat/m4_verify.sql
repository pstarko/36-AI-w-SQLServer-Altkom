/* ============================================================
   WERYFIKACJA MODUŁU 4
   ============================================================ */
USE LodyPrognoza;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(100), Oczekiwane nvarchar(100), OK bit);
 
DECLARE @Ostatni int = (SELECT MAX(ModelID) FROM dbo.Model);
 
INSERT INTO #W SELECT 1, N'Liczba prognoz (14 dni x 4 punkty)', CONCAT(COUNT(*), ''), N'56', IIF(COUNT(*) = 56, 1, 0)
FROM dbo.PrognozaSprzedazy WHERE Data BETWEEN '20260701' AND '20260714';
 
INSERT INTO #W SELECT 2, N'Każdy dzień ma prognozę dla 4 punktów', CONCAT(COUNT(*), N' dni niekompletnych'), N'0 dni niekompletnych',
       IIF(COUNT(*) = 0, 1, 0)
FROM (SELECT Data FROM dbo.PrognozaSprzedazy WHERE Data BETWEEN '20260701' AND '20260714'
      GROUP BY Data HAVING COUNT(*) <> 4) AS x;
 
INSERT INTO #W SELECT 3, N'Prognozy pochodzą z najnowszego modelu', CONCAT(N'ModelID = ', MIN(ModelID)), CONCAT(N'ModelID = ', @Ostatni),
       IIF(MIN(ModelID) = @Ostatni AND MAX(ModelID) = @Ostatni, 1, 0)
FROM dbo.PrognozaSprzedazy WHERE Data BETWEEN '20260701' AND '20260714';
 
INSERT INTO #W SELECT 4, N'Brak prognoz ujemnych lub zerowych', CONCAT(N'min = ', MIN(PrognozaPorcji)), N'min > 0',
       IIF(MIN(PrognozaPorcji) > 0, 1, 0)
FROM dbo.PrognozaSprzedazy WHERE Data BETWEEN '20260701' AND '20260714';
 
INSERT INTO #W SELECT 5, N'Łączna prognoza na 14 dni [porcje]', FORMAT(SUM(PrognozaPorcji), 'N0', 'pl-PL'), N'ok. 14 600 (12 000–17 000)',
       IIF(SUM(PrognozaPorcji) BETWEEN 12000 AND 17000, 1, 0)
FROM dbo.PrognozaSprzedazy WHERE Data BETWEEN '20260701' AND '20260714';
 
INSERT INTO #W SELECT 6, N'Upalna niedziela 5.07 vs deszczowa środa 8.07 (cała sieć)',
       CONCAT(SUM(IIF(Data = '20260705', PrognozaPorcji, 0)), N' vs ', SUM(IIF(Data = '20260708', PrognozaPorcji, 0))),
       N'stosunek >= 3',
       IIF(SUM(IIF(Data = '20260705', PrognozaPorcji, 0)) >= 3 * SUM(IIF(Data = '20260708', PrognozaPorcji, 0)), 1, 0)
FROM dbo.PrognozaSprzedazy;
 
INSERT INTO #W SELECT 7, N'Galeria najbardziej stabilna (najmniejsza rozpiętość max/min)',
       (SELECT TOP (1) p.Nazwa FROM dbo.PrognozaSprzedazy ps JOIN dbo.Punkt p ON p.PunktID = ps.PunktID
        WHERE ps.Data BETWEEN '20260701' AND '20260714'
        GROUP BY p.Nazwa ORDER BY 1.0 * MAX(ps.PrognozaPorcji) / MIN(ps.PrognozaPorcji)),
       N'Galeria',
       IIF((SELECT TOP (1) PunktID FROM dbo.PrognozaSprzedazy
            WHERE Data BETWEEN '20260701' AND '20260714'
            GROUP BY PunktID ORDER BY 1.0 * MAX(PrognozaPorcji) / MIN(PrognozaPorcji)) = 4, 1, 0);
 
INSERT INTO #W SELECT 8, N'W deszczowy 7.07 Galeria sprzedaje więcej niż Plaża',
       CONCAT(MAX(IIF(PunktID = 4, PrognozaPorcji, NULL)), N' vs ', MAX(IIF(PunktID = 1, PrognozaPorcji, NULL))),
       N'Galeria > Plaża',
       IIF(MAX(IIF(PunktID = 4, PrognozaPorcji, NULL)) > MAX(IIF(PunktID = 1, PrognozaPorcji, NULL)), 1, 0)
FROM dbo.PrognozaSprzedazy WHERE Data = '20260707';
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 4 zaliczony – warsztat ukończony!',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;
