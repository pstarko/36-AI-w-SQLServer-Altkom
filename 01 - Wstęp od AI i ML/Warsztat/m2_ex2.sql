/* Ćwiczenie 2.2 – jak pogoda i kalendarz wpływają na każdy punkt? */
USE LodyPrognoza;
GO
DROP TABLE IF EXISTS dbo.AnalizaPunktow;
CREATE TABLE dbo.AnalizaPunktow
(
    PunktID        int   NOT NULL PRIMARY KEY,
    KorelacjaTemp  float NOT NULL,   -- korelacja Pearsona: temperatura vs liczba porcji
    SredniaSucho   float NOT NULL,   -- średnia sprzedaż w dni bez opadów (< 1 mm)
    SredniaDeszcz  float NOT NULL,   -- średnia sprzedaż w dni deszczowe (>= 5 mm)
    WskaznikWeekend float NOT NULL   -- średnia weekendowa / średnia w dni robocze
);
 
INSERT INTO dbo.AnalizaPunktow (PunktID, KorelacjaTemp, SredniaSucho, SredniaDeszcz, WskaznikWeekend)
EXEC sys.sp_execute_external_script
     @language     = N'Python',
     @script       = N'
import pandas as pd
 
df = InputDataSet
 
# Kontrola jakosci danych: dni bez pomiaru temperatury
braki = df.loc[df["TempMax"].isna(), "Data"].drop_duplicates()
print("Dni bez pomiaru temperatury:", len(braki))
for d in braki:
    print("   brak pomiaru:", pd.Timestamp(d).date())
 
# Do analizy korelacji pomijamy dni bez pomiaru
dane = df.dropna(subset=["TempMax"])
 
wyniki = []
for punkt, g in dane.groupby("PunktID"):
    wyniki.append({
        "PunktID": int(punkt),
        "KorelacjaTemp": g["TempMax"].corr(g["LiczbaPorcji"]),
        "SredniaSucho": g.loc[g["OpadyMm"] < 1, "LiczbaPorcji"].mean(),
        "SredniaDeszcz": g.loc[g["OpadyMm"] >= 5, "LiczbaPorcji"].mean(),
        "WskaznikWeekend": g.loc[g["CzyWeekend"] == 1, "LiczbaPorcji"].mean()
                           / g.loc[g["CzyWeekend"] == 0, "LiczbaPorcji"].mean()
    })
 
OutputDataSet = pd.DataFrame(wyniki)
',
     @input_data_1 = N'
SELECT s.Data, CAST(s.PunktID AS int) AS PunktID, s.LiczbaPorcji,
       CAST(w.TempMax AS float) AS TempMax, CAST(w.OpadyMm AS float) AS OpadyMm,
       CAST(k.CzyWeekend AS int) AS CzyWeekend
FROM dbo.Sprzedaz  AS s
JOIN dbo.Pogoda    AS w ON w.Data = s.Data
JOIN dbo.Kalendarz AS k ON k.Data = s.Data';
 
SELECT p.Nazwa,
       CAST(a.KorelacjaTemp AS decimal(4,2))                         AS KorelacjaTemp,
       CAST(a.SredniaSucho  AS decimal(6,1))                         AS SredniaSucho,
       CAST(a.SredniaDeszcz AS decimal(6,1))                         AS SredniaDeszcz,
       CAST(100.0 * (a.SredniaDeszcz / a.SredniaSucho - 1) AS decimal(5,1)) AS ZmianaWDeszczProc,
       CAST(a.WskaznikWeekend AS decimal(4,2))                       AS WskaznikWeekend
FROM dbo.AnalizaPunktow AS a
JOIN dbo.Punkt AS p ON p.PunktID = a.PunktID
ORDER BY a.KorelacjaTemp DESC;
