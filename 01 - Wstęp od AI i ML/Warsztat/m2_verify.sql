/* ============================================================
   WERYFIKACJA MODUŁU 2
   ============================================================ */
USE LodyPrognoza;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(100), Oczekiwane nvarchar(100), OK bit);
 
INSERT INTO #W SELECT 1, N'Tabela AnalizaPunktow ma 4 wiersze', CONCAT(COUNT(*), ''), N'4', IIF(COUNT(*) = 4, 1, 0)
FROM dbo.AnalizaPunktow;
 
INSERT INTO #W SELECT 2, N'Temperatura dodatnio skorelowana ze sprzedażą we wszystkich punktach',
       CONCAT(N'min = ', CAST(MIN(KorelacjaTemp) AS decimal(4,2))), N'min > 0,30', IIF(MIN(KorelacjaTemp) > 0.30, 1, 0)
FROM dbo.AnalizaPunktow;
 
INSERT INTO #W SELECT 3, N'Najsłabsza zależność od temperatury: Galeria (punkt zadaszony)',
       (SELECT TOP (1) p.Nazwa FROM dbo.AnalizaPunktow a JOIN dbo.Punkt p ON p.PunktID = a.PunktID ORDER BY a.KorelacjaTemp),
       N'Galeria',
       IIF((SELECT TOP (1) PunktID FROM dbo.AnalizaPunktow ORDER BY KorelacjaTemp) = 4, 1, 0);
 
INSERT INTO #W SELECT 4, N'Deszcz obniża sprzedaż na Plaży o ponad 50%',
       CONCAT(CAST(100.0 * (SredniaDeszcz / SredniaSucho - 1) AS decimal(5,1)), N' %'), N'< -50 %',
       IIF(SredniaDeszcz / SredniaSucho < 0.5, 1, 0)
FROM dbo.AnalizaPunktow WHERE PunktID = 1;
 
INSERT INTO #W SELECT 5, N'Deszcz praktycznie nie szkodzi Galerii (spadek < 10%)',
       CONCAT(CAST(100.0 * (SredniaDeszcz / SredniaSucho - 1) AS decimal(5,1)), N' %'), N'> -10 %',
       IIF(SredniaDeszcz / SredniaSucho > 0.9, 1, 0)
FROM dbo.AnalizaPunktow WHERE PunktID = 4;
 
INSERT INTO #W SELECT 6, N'Weekend zwiększa sprzedaż w każdym punkcie',
       CONCAT(N'min = ', CAST(MIN(WskaznikWeekend) AS decimal(4,2))), N'min > 1,20', IIF(MIN(WskaznikWeekend) > 1.2, 1, 0)
FROM dbo.AnalizaPunktow;
 
INSERT INTO #W SELECT 7, N'AnalizaTemperatury: 5 przedziałów', CONCAT(COUNT(*), ''), N'5', IIF(COUNT(*) = 5, 1, 0)
FROM dbo.AnalizaTemperatury;
 
INSERT INTO #W SELECT 8, N'Średnia sprzedaż rośnie w każdym kolejnym przedziale temperatury',
       CONCAT(SUM(IIF(Wzrost = 1, 1, 0)), N' z 4 przejść'), N'4 z 4 przejść', IIF(SUM(IIF(Wzrost = 1, 1, 0)) = 4, 1, 0)
FROM (SELECT IIF(SredniaPorcji > LAG(SredniaPorcji) OVER (ORDER BY Lp), 1, 0) AS Wzrost, Lp
      FROM dbo.AnalizaTemperatury) AS x
WHERE Lp > 1;
 
INSERT INTO #W SELECT 9, N'Upał (30+) daje min. 3x więcej porcji niż chłodny dzień (<18)',
       CONCAT(CAST(MAX(IIF(Lp = 5, SredniaPorcji, NULL)) / MAX(IIF(Lp = 1, SredniaPorcji, NULL)) AS decimal(4,1)), N' x'),
       N'>= 3,0 x',
       IIF(MAX(IIF(Lp = 5, SredniaPorcji, NULL)) / MAX(IIF(Lp = 1, SredniaPorcji, NULL)) >= 3, 1, 0)
FROM dbo.AnalizaTemperatury;
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 2 zaliczony – możesz przejść dalej',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;
