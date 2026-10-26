/* Ćwiczenie 2.3 – czy wybór metryki zmienia wynik? (zgłoszenie nr 3) */
USE WektoryHelpdesk;
GO
DECLARE @q vector(32) = (SELECT Embedding FROM dbo.NoweZgloszenie WHERE NoweID = 3);
 
WITH Rankingi AS
(
    SELECT z.ZgloszenieID, z.TematID, z.Tresc,
           ROW_NUMBER() OVER (ORDER BY VECTOR_DISTANCE('cosine',    @q, z.Embedding)) AS R_Cosine,
           ROW_NUMBER() OVER (ORDER BY VECTOR_DISTANCE('euclidean', @q, z.Embedding)) AS R_Euclidean,
           ROW_NUMBER() OVER (ORDER BY VECTOR_DISTANCE('dot',       @q, z.Embedding)) AS R_Dot
    FROM dbo.Zgloszenie AS z
)
SELECT TOP (10) r.ZgloszenieID, t.Tytul AS PrzypisanyTemat, LEFT(r.Tresc, 50) AS Tresc, r.R_Cosine, r.R_Euclidean, r.R_Dot
FROM Rankingi AS r
JOIN dbo.Temat AS t ON t.TematID = r.TematID
ORDER BY r.R_Cosine;
