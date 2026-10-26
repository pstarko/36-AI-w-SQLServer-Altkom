/* ============================================================
   WERYFIKACJA MODUŁU 3
   ============================================================ */
USE LodyPrognoza;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #W, #Scenariusz;
CREATE TABLE #W (Nr int, Test nvarchar(200), Wynik nvarchar(100), Oczekiwane nvarchar(100), OK bit);
 
DECLARE @ModelID int, @ModelBin varbinary(max);
SELECT TOP (1) @ModelID = ModelID, @ModelBin = ModelBin FROM dbo.Model ORDER BY ModelID DESC;
 
INSERT INTO #W SELECT 1, N'W tabeli dbo.Model jest zapisany model', CONCAT(COUNT(*), ''), N'>= 1', IIF(COUNT(*) >= 1, 1, 0) FROM dbo.Model;
 
INSERT INTO #W SELECT 2, N'Model ma niezerowy rozmiar binarny', CONCAT(DATALENGTH(@ModelBin) / 1024, N' KB'), N'> 0 KB',
       IIF(DATALENGTH(@ModelBin) > 0, 1, 0);
 
INSERT INTO #W SELECT 3, N'Porównano 3 podejścia (naiwne, LR, RF)', CONCAT(COUNT(*), ''), N'3', IIF(COUNT(*) = 3, 1, 0)
FROM dbo.ModelOcena WHERE ModelID = @ModelID;
 
INSERT INTO #W SELECT 4, N'Wybrano model RandomForest', Algorytm, N'RandomForest', IIF(Algorytm = N'RandomForest', 1, 0)
FROM dbo.Model WHERE ModelID = @ModelID;
 
INSERT INTO #W SELECT 5, N'MAPE wybranego modelu na sezonie 2025', CONCAT(CAST(MAPE AS decimal(5,1)), N' %'), N'10–20 % (ok. 15 %)',
       IIF(MAPE BETWEEN 10 AND 20, 1, 0)
FROM dbo.Model WHERE ModelID = @ModelID;
 
INSERT INTO #W SELECT 6, N'Model ML jest wyraźnie lepszy od prognozy naiwnej',
       CONCAT(CAST(MAX(IIF(CzyWybrany = 1, MAPE, NULL)) AS decimal(5,1)), N' % vs ',
              CAST(MAX(IIF(Algorytm LIKE N'Naiwna%', MAPE, NULL)) AS decimal(5,1)), N' %'),
       N'MAPE ML < połowa MAPE naiwnej',
       IIF(MAX(IIF(CzyWybrany = 1, MAPE, NULL)) < 0.5 * MAX(IIF(Algorytm LIKE N'Naiwna%', MAPE, NULL)), 1, 0)
FROM dbo.ModelOcena WHERE ModelID = @ModelID;
 
/* Test funkcjonalny: wczytujemy model z bazy i pytamy o dwa skrajne scenariusze */
CREATE TABLE #Scenariusz (Scenariusz nvarchar(100), Prognoza float);
INSERT INTO #Scenariusz (Scenariusz, Prognoza)
EXEC sys.sp_execute_external_script
     @language = N'Python',
     @script   = N'
import pickle
import pandas as pd
pakiet = pickle.loads(model_bin)
scen = pd.DataFrame({
    "TempMax": [30.0, 15.0], "Deszcz": [0, 1], "Mzawka": [0, 0],
    "CzyWeekend": [1, 0], "CzySwieto": [0, 0], "CzyWakacje": [1, 0], "Promocja": [0, 0],
    "Punkt_1": [1, 1], "Punkt_2": [0, 0], "Punkt_3": [0, 0], "Punkt_4": [0, 0]})
pred = pakiet["model"].predict(scen[pakiet["cechy"]])
OutputDataSet = pd.DataFrame({
    "Scenariusz": ["Plaza, sobota, 30 st., sucho, wakacje", "Plaza, wtorek, 15 st., ulewa, maj"],
    "Prognoza": pred})
',
     @params    = N'@model_bin varbinary(max)',
     @model_bin = @ModelBin;
 
INSERT INTO #W SELECT 7, N'Model wczytany z bazy działa (2 prognozy)', CONCAT(COUNT(*), ''), N'2', IIF(COUNT(*) = 2, 1, 0) FROM #Scenariusz;
 
INSERT INTO #W SELECT 8, N'Upalna sobota >> deszczowy wtorek (Plaża)',
       CONCAT(CAST(MAX(Prognoza) AS int), N' vs ', CAST(MIN(Prognoza) AS int), N' porcji'),
       N'stosunek >= 5',
       IIF(MAX(IIF(Scenariusz LIKE N'%sobota%', Prognoza, NULL)) >= 5 * MAX(IIF(Scenariusz LIKE N'%wtorek%', Prognoza, NULL)), 1, 0)
FROM #Scenariusz;
 
SELECT Nr, Test, Wynik, Oczekiwane, IIF(OK = 1, N'OK', N'BŁĄD') AS Status FROM #W ORDER BY Nr;
SELECT IIF(MIN(CAST(OK AS int)) = 1, N'Moduł 3 zaliczony – możesz przejść dalej',
                                     N'Popraw testy ze statusem BŁĄD') AS Podsumowanie
FROM #W;
