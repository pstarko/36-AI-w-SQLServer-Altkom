/* Ćwiczenie 4.3 – od prognozy do decyzji: ile kuwet lodów przygotować?
   Założenia biznesowe (fikcyjne): 1 kuweta 5 l = ok. 40 porcji,
   bufor bezpieczeństwa = błąd modelu (MAPE) zaokrąglony w górę. */
USE LodyPrognoza;
GO
DECLARE @Bufor decimal(4,2) =
    (SELECT TOP (1) 1 + CEILING(MAPE) / 100.0 FROM dbo.Model ORDER BY ModelID DESC);
 
SELECT p.Nazwa                                         AS Punkt,
       ps.Data,
       ps.PrognozaPorcji,
       CEILING(ps.PrognozaPorcji * @Bufor / 40.0)       AS KuwetyDoPrzygotowania
FROM dbo.PrognozaSprzedazy AS ps
JOIN dbo.Punkt             AS p ON p.PunktID = ps.PunktID
WHERE ps.Data BETWEEN '20260704' AND '20260705'          -- upalny weekend
ORDER BY ps.Data, p.PunktID;
 
/* Podsumowanie tygodniowe dla działu zakupów */
SELECT p.Nazwa                                         AS Punkt,
       SUM(ps.PrognozaPorcji)                          AS PorcjeRazem,
       SUM(CEILING(ps.PrognozaPorcji * @Bufor / 40.0)) AS KuwetyRazem,
       MAX(ps.PrognozaPorcji)                          AS NajwiekszyDzien,
       MIN(ps.PrognozaPorcji)                          AS NajmniejszyDzien
FROM dbo.PrognozaSprzedazy AS ps
JOIN dbo.Punkt             AS p ON p.PunktID = ps.PunktID
WHERE ps.Data BETWEEN '20260701' AND '20260707'
GROUP BY p.Nazwa
ORDER BY PorcjeRazem DESC;
