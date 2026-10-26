/* Ćwiczenie 4.2 – wyszukiwanie przybliżone (ANN) przez VECTOR_SEARCH*/

USE WektoryHelpdesk;
GO
DECLARE @q vector(32) = (SELECT Embedding FROM dbo.NoweZgloszenie WHERE NoweID = 9);

SELECT TOP (5) z.ZgloszenieID, z.Kanal, z.Tresc, CAST(s.distance AS decimal(5,3)) AS Odleglosc
FROM VECTOR_SEARCH(
        TABLE      = dbo.Zgloszenie AS z,
        COLUMN     = Embedding,
        SIMILAR_TO = @q,
        METRIC     = 'cosine',
        TOP_N      = 5
     ) AS s
ORDER BY s.distance;
