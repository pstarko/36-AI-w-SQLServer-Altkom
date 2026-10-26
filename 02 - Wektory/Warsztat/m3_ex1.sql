/* Ćwiczenie 3.1 – centroidy kategorii: "średni wektor" każdej kategorii
   Typ vector nie ma funkcji agregujących (AVG), więc rozbijamy wektor na składowe
   przez JSON, uśredniamy i składamy z powrotem. */
USE WektoryHelpdesk;
GO
DROP TABLE IF EXISTS dbo.CentroidKategorii;
CREATE TABLE dbo.CentroidKategorii
(
    KategoriaID  tinyint    NOT NULL CONSTRAINT PK_CentroidKategorii PRIMARY KEY,
    LiczbaZgloszen int      NOT NULL,
    Centroid     vector(32) NOT NULL
);
 
WITH Skladowe AS
(
    SELECT t.KategoriaID, z.ZgloszenieID,
           CAST(j.[key] AS int)     AS Wym,
           CAST(j.[value] AS float) AS Wart
    FROM dbo.Zgloszenie AS z
    JOIN dbo.Temat      AS t ON t.TematID = z.TematID
    CROSS APPLY OPENJSON(CAST(z.Embedding AS nvarchar(max))) AS j
),
Srednie AS
(
    SELECT KategoriaID, Wym, AVG(Wart) AS Wart, COUNT(DISTINCT ZgloszenieID) AS Liczba
    FROM Skladowe
    GROUP BY KategoriaID, Wym
)
INSERT INTO dbo.CentroidKategorii (KategoriaID, LiczbaZgloszen, Centroid)
SELECT KategoriaID, MAX(Liczba),
       VECTOR_NORMALIZE(CAST(CONCAT('[', STRING_AGG(CAST(CAST(Wart AS decimal(9,6)) AS varchar(12)), ',')
                                         WITHIN GROUP (ORDER BY Wym), ']') AS vector(32)), 'norm2')
FROM Srednie
GROUP BY KategoriaID;
 
/* Jak daleko od siebie leżą kategorie? (macierz odległości kosinusowych) */
SELECT k1.Nazwa AS Kategoria, k2.Nazwa AS NajblizszaInnaKategoria,
       CAST(x.Odleglosc AS decimal(5,3)) AS Odleglosc
FROM dbo.CentroidKategorii AS c1
JOIN dbo.Kategoria AS k1 ON k1.KategoriaID = c1.KategoriaID
CROSS APPLY (SELECT TOP (1) c2.KategoriaID, VECTOR_DISTANCE('cosine', c1.Centroid, c2.Centroid) AS Odleglosc
             FROM dbo.CentroidKategorii AS c2
             WHERE c2.KategoriaID <> c1.KategoriaID
             ORDER BY Odleglosc) AS x
JOIN dbo.Kategoria AS k2 ON k2.KategoriaID = x.KategoriaID
ORDER BY x.Odleglosc;
