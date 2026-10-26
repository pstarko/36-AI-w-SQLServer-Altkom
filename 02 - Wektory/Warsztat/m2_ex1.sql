/* Ćwiczenie 2.1 – "pokaż podobne zgłoszenia" dla nowego zgłoszenia nr 1 (dokładne kNN) */
USE WektoryHelpdesk;
GO
DECLARE @q vector(32) = (SELECT Embedding FROM dbo.NoweZgloszenie WHERE NoweID = 1);
 
SELECT TOP (5)
       z.ZgloszenieID,
       t.Tytul,
       z.Tresc,
       CAST(1 - VECTOR_DISTANCE('cosine', @q, z.Embedding) AS decimal(5,3)) AS Podobienstwo
FROM dbo.Zgloszenie AS z
JOIN dbo.Temat      AS t ON t.TematID = z.TematID
ORDER BY VECTOR_DISTANCE('cosine', @q, z.Embedding);
	