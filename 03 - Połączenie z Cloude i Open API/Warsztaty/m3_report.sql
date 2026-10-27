/* Ćwiczenie 3.3 – raport dla dyrektora operacyjnego i kontrola kosztów */
USE AsystentOpinii;
GO
/* a) Co boli gości w poszczególnych hotelach? */
SELECT h.Nazwa AS Hotel, a.KategoriaGlowna,
       COUNT(*)                                          AS Opinie,
       SUM(IIF(a.Sentyment = 'negatywny', 1, 0))         AS Negatywne,
       CAST(AVG(CAST(o.Ocena AS decimal(3,1))) AS decimal(3,1)) AS SredniaGwiazdek
FROM dbo.AnalizaOpinii AS a
JOIN dbo.Opinia AS o ON o.OpiniaID = a.OpiniaID
JOIN dbo.Hotel  AS h ON h.HotelID = o.HotelID
GROUP BY h.Nazwa, a.KategoriaGlowna
HAVING SUM(IIF(a.Sentyment = 'negatywny', 1, 0)) > 0
ORDER BY Negatywne DESC, h.Nazwa;
 
/* b) Sprawy pilne – lista dla kierowników na dziś */
SELECT o.OpiniaID, h.Nazwa AS Hotel, a.Pilnosc, a.KategoriaGlowna, a.Streszczenie
FROM dbo.AnalizaOpinii AS a
JOIN dbo.Opinia AS o ON o.OpiniaID = a.OpiniaID
JOIN dbo.Hotel  AS h ON h.HotelID = o.HotelID
WHERE a.Pilnosc >= 4
ORDER BY a.Pilnosc DESC, o.OpiniaID;
 
/* c) Gwiazdki kontra treść: gdzie ocena liczbowa nie pasuje do sentymentu? */
SELECT o.OpiniaID, o.Ocena, a.Sentyment, o.Tresc
FROM dbo.AnalizaOpinii AS a
JOIN dbo.Opinia AS o ON o.OpiniaID = a.OpiniaID
WHERE (o.Ocena >= 4 AND a.Sentyment = 'negatywny') OR (o.Ocena <= 2 AND a.Sentyment = 'pozytywny');
 
/* d) Ile to kosztowało? */
SELECT Etap, COUNT(*) AS Wywolania, SUM(TokenyWe) AS TokenyWe, SUM(TokenyWy) AS TokenyWy,
       CAST(SUM(KosztUSD) AS decimal(12,6)) AS KosztUSD, AVG(CzasMs) AS SredniCzasMs
FROM dbo.LogLLM
GROUP BY Etap
ORDER BY MIN(LogID);
