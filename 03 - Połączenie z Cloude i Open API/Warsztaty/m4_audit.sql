/* Ćwiczenie 4.1 – audyt RODO: czy wysłaliśmy dostawcy dane osobowe? */
USE AsystentOpinii;
GO
/* Zapytanie jest nvarchar(max), a funkcje REGEXP_* w części kompilacji go nie przyjmują,
   dlatego wyszukujemy we fragmentach po 4000 znaków (zakładka 3800 znaków, aby nie rozciąć wzorca). */
WITH Fragmenty AS
(
    SELECT l.LogID, l.Etap, l.CzasStart,
           CAST(SUBSTRING(l.Zapytanie, f.value * 3800 + 1, 4000) AS nvarchar(4000)) AS Fragment
    FROM dbo.LogLLM AS l
    CROSS APPLY GENERATE_SERIES(0, CAST((DATALENGTH(l.Zapytanie) / 2) / 3800 AS int)) AS f
    WHERE l.Zapytanie IS NOT NULL
)
SELECT LogID, Etap, MIN(CzasStart) AS CzasStart,
       MAX(REGEXP_SUBSTR(Fragment, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')) AS ZnalezionyEmail,
       MAX(REGEXP_SUBSTR(Fragment, '(\+48[ -]?)?\d{3}[ -]?\d{3}[ -]?\d{3}'))       AS ZnalezionyTelefon
FROM Fragmenty
WHERE REGEXP_LIKE(Fragment, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
   OR REGEXP_LIKE(Fragment, '(\+48[ -]?)?\d{3}[ -]?\d{3}[ -]?\d{3}')
GROUP BY LogID, Etap
ORDER BY LogID;
