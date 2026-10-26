/* Ćwiczenie 4.1 – procedura prognozująca (scoring) */
USE LodyPrognoza;
GO
DROP TABLE IF EXISTS dbo.PrognozaSprzedazy;
GO
CREATE TABLE dbo.PrognozaSprzedazy
(
    Data           date         NOT NULL,
    PunktID        tinyint      NOT NULL CONSTRAINT FK_PrognozaSprzedazy_Punkt REFERENCES dbo.Punkt (PunktID),
    PrognozaPorcji int          NOT NULL,
    ModelID        int          NOT NULL CONSTRAINT FK_PrognozaSprzedazy_Model REFERENCES dbo.Model (ModelID),
    DataWyliczenia datetime2(0) NOT NULL CONSTRAINT DF_PrognozaSprzedazy_DataWyliczenia DEFAULT SYSDATETIME(),
    CONSTRAINT PK_PrognozaSprzedazy PRIMARY KEY (Data, PunktID)
);
GO
 
CREATE OR ALTER PROCEDURE dbo.usp_PrognozujSprzedaz
    @DataOd date,
    @DataDo date
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
 
    DECLARE @ModelID int, @ModelBin varbinary(max), @Zapytanie nvarchar(max);
 
    /* 1. Walidacja wejścia */
    SELECT TOP (1) @ModelID = ModelID, @ModelBin = ModelBin
    FROM dbo.Model
    ORDER BY ModelID DESC;
 
    IF @ModelID IS NULL
        THROW 50001, N'Brak wytrenowanego modelu. Uruchom najpierw dbo.usp_TrenujModel.', 1;
 
    IF EXISTS (SELECT 1 FROM dbo.Kalendarz AS k
               WHERE k.Data BETWEEN @DataOd AND @DataDo
                 AND NOT EXISTS (SELECT 1 FROM dbo.PrognozaPogody AS pp WHERE pp.Data = k.Data))
        THROW 50002, N'Brak prognozy pogody dla części dni z wybranego zakresu.', 1;
 
    /* 2. Zapytanie wejściowe: każdy dzień z prognozy pogody x każdy punkt.
          Daty wstawiamy jako literały – parametry są typu date, więc nie ma ryzyka SQL injection. */
    SET @Zapytanie = N'
SELECT pp.Data, CAST(p.PunktID AS int) AS PunktID,
       CAST(pp.TempMax AS float) AS TempMax, CAST(pp.OpadyMm AS float) AS OpadyMm,
       CAST(k.CzyWeekend AS int) AS CzyWeekend, CAST(k.CzySwieto AS int) AS CzySwieto,
       CAST(k.CzyWakacje AS int) AS CzyWakacje,
       CASE WHEN pr.PunktID IS NULL THEN 0 ELSE 1 END AS Promocja
FROM dbo.PrognozaPogody AS pp
JOIN dbo.Kalendarz      AS k  ON k.Data = pp.Data
CROSS JOIN dbo.Punkt    AS p
LEFT JOIN dbo.PlanPromocji AS pr ON pr.Data = pp.Data AND pr.PunktID = p.PunktID
WHERE pp.Data BETWEEN ''' + CONVERT(char(8), @DataOd, 112) + N''' AND ''' + CONVERT(char(8), @DataDo, 112) + N'''
ORDER BY pp.Data, p.PunktID';
 
    CREATE TABLE #Wynik (Data date, PunktID int, PrognozaPorcji int);
 
    /* 3. Scoring w Pythonie */
    INSERT INTO #Wynik (Data, PunktID, PrognozaPorcji)
    EXEC sys.sp_execute_external_script
         @language     = N'Python',
         @script       = N'
import pickle
import numpy as np
import pandas as pd
 
pakiet = pickle.loads(model_bin)
df = InputDataSet.copy()
 
# Ta sama inzynieria cech co w treningu (w praktyce: wspolny modul Pythona)
def przygotuj_cechy(d):
    X = pd.DataFrame(index=d.index)
    X["TempMax"] = d["TempMax"]
    X["Deszcz"] = (d["OpadyMm"] >= 5).astype(int)
    X["Mzawka"] = ((d["OpadyMm"] >= 1) & (d["OpadyMm"] < 5)).astype(int)
    X["CzyWeekend"] = d["CzyWeekend"]
    X["CzySwieto"] = d["CzySwieto"]
    X["CzyWakacje"] = d["CzyWakacje"]
    X["Promocja"] = d["Promocja"]
    for p in [1, 2, 3, 4]:
        X["Punkt_" + str(p)] = (d["PunktID"] == p).astype(int)
    return X
 
# Kolejnosc kolumn MUSI byc identyczna jak w treningu - bierzemy ja z pakietu
X = przygotuj_cechy(df)[pakiet["cechy"]]
pred = pakiet["model"].predict(X)
 
OutputDataSet = pd.DataFrame({
    "Data": pd.to_datetime(df["Data"]),
    "PunktID": df["PunktID"],
    "PrognozaPorcji": np.round(np.clip(pred, 0, None)).astype(int)
})
print("Algorytm:", pakiet["algorytm"], "| sklearn przy treningu:", pakiet["sklearn"])
print("Liczba prognoz:", len(OutputDataSet))
',
         @input_data_1 = @Zapytanie,
         @params       = N'@model_bin varbinary(max)',
         @model_bin    = @ModelBin;
 
    /* 4. Zapis (idempotentny: ponowne uruchomienie nadpisuje prognozy z zakresu) */
    BEGIN TRANSACTION;
        DELETE FROM dbo.PrognozaSprzedazy
        WHERE Data BETWEEN @DataOd AND @DataDo;
 
        INSERT INTO dbo.PrognozaSprzedazy (Data, PunktID, PrognozaPorcji, ModelID)
        SELECT Data, PunktID, PrognozaPorcji, @ModelID
        FROM #Wynik;
    COMMIT TRANSACTION;
 
    SELECT COUNT(*) AS LiczbaPrognoz, @ModelID AS ModelID,
           SUM(PrognozaPorcji) AS SumaPorcji
    FROM #Wynik;
END;
GO
