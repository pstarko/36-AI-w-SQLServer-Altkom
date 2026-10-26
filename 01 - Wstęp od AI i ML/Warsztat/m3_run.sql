/* Ćwiczenie 3.2 – trening i porównanie modeli */
USE LodyPrognoza;
GO
EXEC dbo.usp_TrenujModel @RokTestowy = 2025;
GO
SELECT ModelID, Algorytm, DataTreningu, RokTestowy,
       CAST(MAE AS decimal(6,1)) AS MAE, CAST(MAPE AS decimal(5,1)) AS MAPE,
       DATALENGTH(ModelBin) / 1024 AS RozmiarKB
FROM dbo.Model
ORDER BY ModelID DESC;
