/* Ćwiczenie 2.1 – dane z SQL do Pythona i z powrotem */
USE LodyPrognoza;
GO
EXEC sys.sp_execute_external_script
     @language     = N'Python',
     @script       = N'
df = InputDataSet
print("Liczba wierszy przekazanych z SQL Server:", len(df))
print(df.dtypes)
 
OutputDataSet = df.groupby("Nazwa", as_index=False).agg(
    Dni=("LiczbaPorcji", "count"),
    Srednia=("LiczbaPorcji", "mean"),
    Minimum=("LiczbaPorcji", "min"),
    Maksimum=("LiczbaPorcji", "max"))
',
     @input_data_1 = N'
SELECT p.Nazwa, s.LiczbaPorcji
FROM dbo.Sprzedaz AS s
JOIN dbo.Punkt    AS p ON p.PunktID = s.PunktID'
WITH RESULT SETS ((Punkt nvarchar(50), Dni int, Srednia float, Minimum int, Maksimum int));
