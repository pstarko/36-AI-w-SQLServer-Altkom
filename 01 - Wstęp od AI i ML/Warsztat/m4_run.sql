/* Ćwiczenie 4.2 – prognoza na 1–14 lipca 2026 */
USE LodyPrognoza;
GO
EXEC dbo.usp_PrognozujSprzedaz @DataOd = '20260701', @DataDo = '20260714';
GO
/* Widok "dla kierownika": dni w wierszach, punkty w kolumnach */
SELECT ps.Data,
       CHOOSE(k.DzienTygodnia, N'pon', N'wt', N'śr', N'czw', N'pt', N'sob', N'nd') AS Dzien,
       pp.TempMax, pp.OpadyMm,
       SUM(IIF(ps.PunktID = 1, ps.PrognozaPorcji, 0)) AS Plaza,
       SUM(IIF(ps.PunktID = 2, ps.PrognozaPorcji, 0)) AS Rynek,
       SUM(IIF(ps.PunktID = 3, ps.PrognozaPorcji, 0)) AS Park,
       SUM(IIF(ps.PunktID = 4, ps.PrognozaPorcji, 0)) AS Galeria,
       SUM(ps.PrognozaPorcji)                         AS Razem
FROM dbo.PrognozaSprzedazy AS ps
JOIN dbo.Kalendarz         AS k  ON k.Data  = ps.Data
JOIN dbo.PrognozaPogody    AS pp ON pp.Data = ps.Data
WHERE ps.Data BETWEEN '20260701' AND '20260714'
GROUP BY ps.Data, k.DzienTygodnia, pp.TempMax, pp.OpadyMm
ORDER BY ps.Data;
