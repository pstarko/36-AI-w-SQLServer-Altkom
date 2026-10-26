/* Ćwiczenie 3.2 – audyt jakości danych: które zgłoszenia mają podejrzaną kategorię?
   Zgłoszenie jest podejrzane, gdy jego wektor leży bliżej centroidu INNEJ kategorii
   niż centroidu kategorii przypisanej przez konsultanta. */
USE WektoryHelpdesk;
GO
DROP TABLE IF EXISTS dbo.PodejrzaneZgloszenie;
CREATE TABLE dbo.PodejrzaneZgloszenie
(
    ZgloszenieID          int     NOT NULL PRIMARY KEY,
    PrzypisanaKategoriaID tinyint NOT NULL,
    ProponowanaKategoriaID tinyint NOT NULL,
    OdlPrzypisana         float   NOT NULL,
    OdlProponowana        float   NOT NULL
);
 
INSERT INTO dbo.PodejrzaneZgloszenie
       (ZgloszenieID, PrzypisanaKategoriaID, ProponowanaKategoriaID, OdlPrzypisana, OdlProponowana)
SELECT z.ZgloszenieID, t.KategoriaID, n.KategoriaID,
       VECTOR_DISTANCE('cosine', z.Embedding, cp.Centroid),
       n.Odleglosc
FROM dbo.Zgloszenie        AS z
JOIN dbo.Temat             AS t  ON t.TematID = z.TematID
JOIN dbo.CentroidKategorii AS cp ON cp.KategoriaID = t.KategoriaID
CROSS APPLY (SELECT TOP (1) c.KategoriaID, VECTOR_DISTANCE('cosine', z.Embedding, c.Centroid) AS Odleglosc
             FROM dbo.CentroidKategorii AS c
             ORDER BY Odleglosc) AS n
WHERE n.KategoriaID <> t.KategoriaID;
 
/* Raport dla kierownika zmiany: człowiek czyta treść i decyduje */
SELECT p.ZgloszenieID, z.Tresc,
       kp.Nazwa AS PrzypisanaKategoria, kn.Nazwa AS ProponowanaKategoria,
       CAST(p.OdlPrzypisana AS decimal(5,3)) AS OdlPrzypisana,
       CAST(p.OdlProponowana AS decimal(5,3)) AS OdlProponowana
FROM dbo.PodejrzaneZgloszenie AS p
JOIN dbo.Zgloszenie AS z  ON z.ZgloszenieID = p.ZgloszenieID
JOIN dbo.Kategoria  AS kp ON kp.KategoriaID = p.PrzypisanaKategoriaID
JOIN dbo.Kategoria  AS kn ON kn.KategoriaID = p.ProponowanaKategoriaID
ORDER BY p.OdlPrzypisana - p.OdlProponowana DESC;
