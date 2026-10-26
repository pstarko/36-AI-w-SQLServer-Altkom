/* Ćwiczenie 4.1 – indeks wektorowy DiskANN (funkcja w wersji PREVIEW w SQL Server 2025)
   Uwaga: w starszych wersjach indeksu tabela po jego utworzeniu staje się TYLKO DO ODCZYTU,
   dlatego indeks tworzymy na końcu, po wszystkich zmianach danych z Modułu 3. */
USE WektoryHelpdesk;
GO
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO
CREATE VECTOR INDEX IX_Zgloszenie_Embedding
    ON dbo.Zgloszenie (Embedding)
    WITH (METRIC = 'cosine', TYPE = 'DiskANN');
GO
/* Co powstało? */
SELECT i.name                                         AS Indeks,
       v.vector_index_type                            AS Typ,
       v.distance_metric                              AS Metryka,
       JSON_VALUE(v.build_parameters, '$.Version')    AS WersjaIndeksu
FROM sys.vector_indexes AS v
JOIN sys.indexes        AS i ON i.object_id = v.object_id AND i.index_id = v.index_id
WHERE v.object_id = OBJECT_ID(N'dbo.Zgloszenie');
