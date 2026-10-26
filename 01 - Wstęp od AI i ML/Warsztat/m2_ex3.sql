/* Ćwiczenie 2.3 – przy jakiej temperaturze "Plaża" naprawdę zarabia? */
USE LodyPrognoza;
GO
DROP TABLE IF EXISTS dbo.AnalizaTemperatury;
CREATE TABLE dbo.AnalizaTemperatury
(
    Lp            int          NOT NULL PRIMARY KEY,
    Przedzial     nvarchar(20) NOT NULL,
    LiczbaDni     int          NOT NULL,
    SredniaPorcji float        NULL
);
 
INSERT INTO dbo.AnalizaTemperatury (Lp, Przedzial, LiczbaDni, SredniaPorcji)
EXEC sys.sp_execute_external_script
     @language     = N'Python',
     @script       = N'
import pandas as pd
 
df = InputDataSet.dropna(subset=["TempMax"]).copy()
granice = [-100, 18, 22, 26, 30, 100]
etykiety = ["ponizej 18", "18-22", "22-26", "26-30", "30 i wiecej"]
df["Przedzial"] = pd.cut(df["TempMax"], bins=granice, labels=etykiety, right=False)
 
wynik = (df.groupby("Przedzial", observed=False)["LiczbaPorcji"]
           .agg(["count", "mean"])
           .reset_index())
wynik.columns = ["Przedzial", "LiczbaDni", "SredniaPorcji"]
wynik.insert(0, "Lp", range(1, len(wynik) + 1))
wynik["Przedzial"] = wynik["Przedzial"].astype(str)
 
OutputDataSet = wynik
',
     @input_data_1 = N'
SELECT CAST(w.TempMax AS float) AS TempMax, s.LiczbaPorcji
FROM dbo.Sprzedaz AS s
JOIN dbo.Pogoda   AS w ON w.Data = s.Data
WHERE s.PunktID = 1
  AND w.OpadyMm < 1
  AND s.Promocja = 0';
-- Filtr: tylko Plaża (PunktID = 1), dni bez opadów i bez promocji
 
SELECT Lp, Przedzial, LiczbaDni, CAST(SredniaPorcji AS decimal(6,1)) AS SredniaPorcji
FROM dbo.AnalizaTemperatury
ORDER BY Lp;
