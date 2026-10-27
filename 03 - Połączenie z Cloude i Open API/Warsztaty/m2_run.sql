/* Ćwiczenie 2.3 – analiza pierwszych pięciu opinii */
USE AsystentOpinii;
GO
DECLARE @id int = 1;
WHILE @id <= 5
BEGIN
    EXEC dbo.usp_AnalizujOpinie @OpiniaID = @id;
    SET @id += 1;
END;
 
SELECT o.OpiniaID, LEFT(o.Tresc, 50) + N'...' AS Tresc, a.Sentyment, a.KategoriaGlowna, a.Kategorie,
       a.Pilnosc, a.Jezyk, a.Streszczenie
FROM dbo.AnalizaOpinii AS a
JOIN dbo.Opinia AS o ON o.OpiniaID = a.OpiniaID
ORDER BY o.OpiniaID;
