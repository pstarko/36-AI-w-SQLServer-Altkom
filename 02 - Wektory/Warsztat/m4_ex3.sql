/* Ćwiczenie 4.3 – ile tracimy na przybliżeniu? Pomiar recall@10
   ANN (indeks) porównujemy z dokładnym kNN (VECTOR_DISTANCE) dla 10 nowych zgłoszeń. */
USE WektoryHelpdesk;
GO
DROP TABLE IF EXISTS dbo.WynikANN, dbo.WynikDokladny;
CREATE TABLE dbo.WynikANN      (NoweID int NOT NULL, ZgloszenieID int NOT NULL, PRIMARY KEY (NoweID, ZgloszenieID));
CREATE TABLE dbo.WynikDokladny (NoweID int NOT NULL, ZgloszenieID int NOT NULL, PRIMARY KEY (NoweID, ZgloszenieID));
GO
DECLARE @id int = 1, @q vector(32);
WHILE @id <= 10
BEGIN
    SELECT @q = Embedding FROM dbo.NoweZgloszenie WHERE NoweID = @id;
 

    INSERT INTO dbo.WynikANN (NoweID, ZgloszenieID)
    SELECT @id, z.ZgloszenieID
    FROM VECTOR_SEARCH(TABLE = dbo.Zgloszenie AS z, COLUMN = Embedding,
                       SIMILAR_TO = @q, METRIC = 'cosine', TOP_N = 10) AS s;
    
 
    INSERT INTO dbo.WynikDokladny (NoweID, ZgloszenieID)
    SELECT TOP (10) @id, z.ZgloszenieID
    FROM dbo.Zgloszenie AS z
    ORDER BY VECTOR_DISTANCE('cosine', @q, z.Embedding);
 
    SET @id += 1;
END;
GO
SELECT d.NoweID,
       COUNT(a.ZgloszenieID)                             AS Wspolne,
       CAST(COUNT(a.ZgloszenieID) / 10.0 AS decimal(3,2)) AS Recall10
FROM dbo.WynikDokladny AS d
LEFT JOIN dbo.WynikANN AS a ON a.NoweID = d.NoweID AND a.ZgloszenieID = d.ZgloszenieID
GROUP BY d.NoweID
ORDER BY d.NoweID;
