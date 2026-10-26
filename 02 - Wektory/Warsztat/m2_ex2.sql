/* Ćwiczenie 2.2 – automatyczna propozycja tematu i odpowiedzi dla wszystkich nowych zgłoszeń
   Reguła: głosowanie 5 najbliższych sąsiadów; przy niskim podobieństwie -> do konsultanta. */
USE WektoryHelpdesk;
GO
DROP TABLE IF EXISTS dbo.Propozycja;
CREATE TABLE dbo.Propozycja
(
    NoweID            int          NOT NULL PRIMARY KEY,
    ProponowanyTematID tinyint     NOT NULL,
    Glosy             int          NOT NULL,   -- ilu z 5 sąsiadów ma ten temat
    MaksPodobienstwo  float        NOT NULL,   -- podobieństwo najbliższego sąsiada
    Decyzja           nvarchar(30) NOT NULL
);
GO
CREATE OR ALTER PROCEDURE dbo.usp_ProponujTemat
    @K        int   = 5,
    @ProgPodobienstwa float = 0.85
AS
BEGIN
    SET NOCOUNT ON;
 
    WITH Sasiedzi AS
    (
        SELECT n.NoweID, s.TematID, s.Podobienstwo
        FROM dbo.NoweZgloszenie AS n
        CROSS APPLY (SELECT TOP (@K) z.TematID,
                            1 - VECTOR_DISTANCE('cosine', n.Embedding, z.Embedding) AS Podobienstwo
                     FROM dbo.Zgloszenie AS z
                     ORDER BY VECTOR_DISTANCE('cosine', n.Embedding, z.Embedding)) AS s
    ),
    Glosowanie AS
    (
        SELECT NoweID, TematID, COUNT(*) AS Glosy, AVG(Podobienstwo) AS SrPodobienstwo,
               ROW_NUMBER() OVER (PARTITION BY NoweID ORDER BY COUNT(*) DESC, AVG(Podobienstwo) DESC) AS Miejsce
        FROM Sasiedzi
        GROUP BY NoweID, TematID
    ),
    Maks AS
    (
        SELECT NoweID, MAX(Podobienstwo) AS MaksPodobienstwo FROM Sasiedzi GROUP BY NoweID
    )
    MERGE dbo.Propozycja AS cel
    USING (SELECT g.NoweID, g.TematID, g.Glosy, m.MaksPodobienstwo,
                  CASE WHEN m.MaksPodobienstwo < @ProgPodobienstwa THEN N'Do konsultanta'
                       WHEN g.Glosy < 3                            THEN N'Do konsultanta'
                       ELSE N'Automatyczna odpowiedź' END AS Decyzja
           FROM Glosowanie AS g
           JOIN Maks AS m ON m.NoweID = g.NoweID
           WHERE g.Miejsce = 1) AS zr
       ON cel.NoweID = zr.NoweID
    WHEN MATCHED THEN UPDATE SET ProponowanyTematID = zr.TematID, Glosy = zr.Glosy,
                                 MaksPodobienstwo = zr.MaksPodobienstwo, Decyzja = zr.Decyzja
    WHEN NOT MATCHED THEN INSERT (NoweID, ProponowanyTematID, Glosy, MaksPodobienstwo, Decyzja)
                          VALUES (zr.NoweID, zr.TematID, zr.Glosy, zr.MaksPodobienstwo, zr.Decyzja);
END;
GO
 
EXEC dbo.usp_ProponujTemat;
 
SELECT n.NoweID, LEFT(n.Tresc, 60) + N'...' AS Tresc, t.Tytul AS ProponowanyTemat, p.Glosy,
       CAST(p.MaksPodobienstwo AS decimal(5,3)) AS MaksPodobienstwo, p.Decyzja,
       IIF(p.Decyzja = N'Automatyczna odpowiedź', t.Rozwiazanie, NULL) AS OdpowiedzZBazyWiedzy
FROM dbo.Propozycja AS p
JOIN dbo.NoweZgloszenie AS n ON n.NoweID = p.NoweID
JOIN dbo.Temat AS t ON t.TematID = p.ProponowanyTematID
ORDER BY p.NoweID;
