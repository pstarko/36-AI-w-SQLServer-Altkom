/* Ćwiczenie 3.3 – korekta etykiet po akceptacji człowieka
   Nowy temat = najczęstszy temat wśród 5 najbliższych zgłoszeń z proponowanej kategorii. */
USE WektoryHelpdesk;
GO
WITH Korekta AS
(
    SELECT p.ZgloszenieID, x.TematID AS NowyTematID
    FROM dbo.PodejrzaneZgloszenie AS p
    JOIN dbo.Zgloszenie AS z ON z.ZgloszenieID = p.ZgloszenieID
    CROSS APPLY (SELECT TOP (1) s.TematID
                 FROM (SELECT TOP (5) z2.TematID
                       FROM dbo.Zgloszenie AS z2
                       JOIN dbo.Temat AS t2 ON t2.TematID = z2.TematID
                       WHERE t2.KategoriaID = p.ProponowanaKategoriaID
                         AND z2.ZgloszenieID <> z.ZgloszenieID
                       ORDER BY VECTOR_DISTANCE('cosine', z.Embedding, z2.Embedding)) AS s
                 GROUP BY s.TematID
                 ORDER BY COUNT(*) DESC) AS x
)
UPDATE z
SET TematID = k.NowyTematID
OUTPUT inserted.ZgloszenieID, deleted.TematID AS StaryTemat, inserted.TematID AS NowyTemat
FROM dbo.Zgloszenie AS z
JOIN Korekta AS k ON k.ZgloszenieID = z.ZgloszenieID;
