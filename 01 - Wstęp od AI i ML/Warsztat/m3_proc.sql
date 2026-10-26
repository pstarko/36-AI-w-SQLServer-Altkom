/* Ćwiczenie 3.1 – magazyn modeli i procedura treningowa */
USE LodyPrognoza;
GO
DROP TABLE IF EXISTS dbo.ModelOcena;
DROP TABLE IF EXISTS dbo.Model;
GO
CREATE TABLE dbo.Model
(
    ModelID      int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Model PRIMARY KEY,
    Algorytm     nvarchar(50)   NOT NULL,
    DataTreningu datetime2(0)   NOT NULL CONSTRAINT DF_Model_DataTreningu DEFAULT SYSDATETIME(),
    RokTestowy   int            NOT NULL,
    MAE          float          NOT NULL,   -- średni błąd bezwzględny [porcje]
    MAPE         float          NOT NULL,   -- średni błąd procentowy [%]
    ModelBin     varbinary(max) NOT NULL    -- model zserializowany przez pickle
);
 
CREATE TABLE dbo.ModelOcena
(
    ModelID  int          NOT NULL CONSTRAINT FK_ModelOcena_Model REFERENCES dbo.Model (ModelID),
    Algorytm nvarchar(50) NOT NULL,
    MAE      float        NOT NULL,
    MAPE     float        NOT NULL,
    CzyWybrany bit        NOT NULL,
    CONSTRAINT PK_ModelOcena PRIMARY KEY (ModelID, Algorytm)
);
GO
 
CREATE OR ALTER PROCEDURE dbo.usp_TrenujModel
    @RokTestowy int = 2025
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @ModelBin varbinary(max),
            @Algorytm nvarchar(50),
            @MAE      float,
            @MAPE     float,
            @ModelID  int;
 
    CREATE TABLE #Ocena (Algorytm nvarchar(50), MAE float, MAPE float, CzyWybrany int);
 
    INSERT INTO #Ocena (Algorytm, MAE, MAPE, CzyWybrany)
    EXEC sys.sp_execute_external_script
         @language     = N'Python',
         @script       = N'
import pickle
import numpy as np
import pandas as pd
import sklearn
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error
 
df = InputDataSet.copy()
df["Data"] = pd.to_datetime(df["Data"])
 
# --- 1. Braki temperatury: interpolacja liniowa po kolejnych dniach ---
pogoda = (df[["Data", "TempMax"]].drop_duplicates("Data")
          .sort_values("Data").set_index("Data")["TempMax"])
print("Dni z brakujaca temperatura:", int(pogoda.isna().sum()))
pogoda = pogoda.interpolate()
df["TempMax"] = df["Data"].map(pogoda)
 
# --- 2. Inzynieria cech (ta sama funkcja musi byc uzyta przy prognozie!) ---
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
 
def mape(y, pred):
    return float(np.mean(np.abs(y - pred) / y) * 100)
 
# --- 3. Podzial czasowy: uczymy na przeszlosci, testujemy na ostatnim sezonie ---
trening = df[df["Data"].dt.year < rok_testowy]
test = df[df["Data"].dt.year == rok_testowy]
X_tr, y_tr = przygotuj_cechy(trening), trening["LiczbaPorcji"]
X_te, y_te = przygotuj_cechy(test), test["LiczbaPorcji"]
print("Wiersze treningowe:", len(X_tr), "| testowe:", len(X_te))
 
wyniki = []
 
# Punkt odniesienia: srednia z lat treningowych dla punktu i typu dnia
srednie = trening.groupby(["PunktID", "CzyWeekend"])["LiczbaPorcji"].mean().rename("Naiwna")
pred_naiwna = test.join(srednie, on=["PunktID", "CzyWeekend"])["Naiwna"]
wyniki.append(["Naiwna (srednia)", mean_absolute_error(y_te, pred_naiwna), mape(y_te, pred_naiwna)])
 
kandydaci = {
    "LinearRegression": lambda: LinearRegression(),
    "RandomForest": lambda: RandomForestRegressor(n_estimators=100, min_samples_leaf=5, random_state=42)
}
for nazwa, utworz in kandydaci.items():
    m = utworz().fit(X_tr, y_tr)
    pred = m.predict(X_te)
    wyniki.append([nazwa, mean_absolute_error(y_te, pred), mape(y_te, pred)])
 
ocena = pd.DataFrame(wyniki, columns=["Algorytm", "MAE", "MAPE"])
najlepszy = ocena[ocena["Algorytm"].isin(list(kandydaci.keys()))].sort_values("MAPE").iloc[0]
ocena["CzyWybrany"] = (ocena["Algorytm"] == najlepszy["Algorytm"]).astype(int)
print(ocena)
 
# --- 4. Model produkcyjny: najlepszy algorytm uczony na WSZYSTKICH danych ---
model = kandydaci[najlepszy["Algorytm"]]().fit(przygotuj_cechy(df), df["LiczbaPorcji"])
pakiet = {
    "model": model,
    "cechy": list(X_tr.columns),
    "algorytm": najlepszy["Algorytm"],
    "sklearn": sklearn.__version__
}
model_bin = pickle.dumps(pakiet)
algorytm = str(najlepszy["Algorytm"])
mae = float(najlepszy["MAE"])
mape_wynik = float(najlepszy["MAPE"])
print("Rozmiar modelu [bajty]:", len(model_bin))
 
OutputDataSet = ocena
',
         @input_data_1 = N'
SELECT s.Data, CAST(s.PunktID AS int) AS PunktID, s.LiczbaPorcji,
       CAST(s.Promocja AS int) AS Promocja,
       CAST(w.TempMax AS float) AS TempMax, CAST(w.OpadyMm AS float) AS OpadyMm,
       CAST(k.CzyWeekend AS int) AS CzyWeekend, CAST(k.CzySwieto AS int) AS CzySwieto,
       CAST(k.CzyWakacje AS int) AS CzyWakacje
FROM dbo.Sprzedaz  AS s
JOIN dbo.Pogoda    AS w ON w.Data = s.Data
JOIN dbo.Kalendarz AS k ON k.Data = s.Data
ORDER BY s.Data, s.PunktID',
         @params       = N'@rok_testowy int, @model_bin varbinary(max) OUTPUT, @algorytm nvarchar(50) OUTPUT,
                           @mae float OUTPUT, @mape_wynik float OUTPUT',
         @rok_testowy  = @RokTestowy,
         @model_bin    = @ModelBin OUTPUT,
         @algorytm     = @Algorytm OUTPUT,
         @mae          = @MAE OUTPUT,
         @mape_wynik   = @MAPE OUTPUT;
 
    INSERT INTO dbo.Model (Algorytm, RokTestowy, MAE, MAPE, ModelBin)
    VALUES (@Algorytm, @RokTestowy, @MAE, @MAPE, @ModelBin);
 
    SET @ModelID = SCOPE_IDENTITY();
 
    INSERT INTO dbo.ModelOcena (ModelID, Algorytm, MAE, MAPE, CzyWybrany)
    SELECT @ModelID, Algorytm, MAE, MAPE, CzyWybrany FROM #Ocena;
 
    SELECT o.Algorytm,
           CAST(o.MAE  AS decimal(6,1)) AS MAE_porcje,
           CAST(o.MAPE AS decimal(5,1)) AS MAPE_proc,
           IIF(o.CzyWybrany = 1, N'<-- zapisany jako model ' + CAST(@ModelID AS nvarchar(10)), N'') AS Decyzja
    FROM dbo.ModelOcena AS o
    WHERE o.ModelID = @ModelID
    ORDER BY o.MAPE;
END;
GO
