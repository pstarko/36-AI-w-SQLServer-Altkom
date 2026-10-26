/* ============================================================
   Moduł 1 – skrypt przygotowujący dane (uruchamiany od zera)
   Wymagania: SQL Server 2022 lub nowszy (GENERATE_SERIES),
   zalecany SQL Server 2025 Developer Edition.
   Wszystkie dane są fikcyjne i deterministyczne
   ============================================================ */
USE master;
GO
IF DB_ID(N'LodyPrognoza') IS NOT NULL
BEGIN
    ALTER DATABASE LodyPrognoza SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LodyPrognoza;
END;
GO
CREATE DATABASE LodyPrognoza;
GO
USE LodyPrognoza;
GO
 
/* 1. Deterministyczny generator liczb pseudolosowych z przedziału [0, 1).
      Ten sam klucz zawsze daje tę samą wartość (MD5 -> 4 bajty -> int). */
CREATE OR ALTER FUNCTION dbo.fn_Los (@Klucz varchar(100))
RETURNS float
WITH SCHEMABINDING
AS
BEGIN
    RETURN ABS(CAST(CAST(HASHBYTES('MD5', @Klucz) AS binary(4)) AS int) % 1000000) / 1000000.0;
END;
GO
 
/* 2. Punkty sprzedaży sieci "Mroźny Kąsek" (firma fikcyjna) */
CREATE TABLE dbo.Punkt
(
    PunktID      tinyint      NOT NULL CONSTRAINT PK_Punkt PRIMARY KEY,
    Nazwa        nvarchar(50) NOT NULL,
    Lokalizacja  nvarchar(80) NOT NULL,
    CzyZadaszony bit          NOT NULL
);
 
INSERT INTO dbo.Punkt (PunktID, Nazwa, Lokalizacja, CzyZadaszony)
VALUES (1, N'Plaża',   N'kiosk na deptaku przy plaży miejskiej', 0),
       (2, N'Rynek',   N'ogródek na Starym Rynku',               0),
       (3, N'Park',    N'budka przy wejściu do parku',           0),
       (4, N'Galeria', N'wyspa w galerii handlowej',             1);
 
/* 3. Kalendarz sezonów (1 maja – 30 września, lata 2023–2026) */
CREATE TABLE dbo.Kalendarz
(
    Data          date    NOT NULL CONSTRAINT PK_Kalendarz PRIMARY KEY,
    DzienTygodnia tinyint NOT NULL,   -- 1 = poniedziałek ... 7 = niedziela
    CzyWeekend    bit     NOT NULL,
    CzySwieto     bit     NOT NULL,
    CzyWakacje    bit     NOT NULL
);
 
WITH Dni AS
(
    SELECT DATEADD(day, s.value, DATEFROMPARTS(r.value, 5, 1)) AS Data
    FROM GENERATE_SERIES(2023, 2026) AS r
    CROSS APPLY GENERATE_SERIES(0, 152) AS s
)
INSERT INTO dbo.Kalendarz (Data, DzienTygodnia, CzyWeekend, CzySwieto, CzyWakacje)
SELECT d.Data,
       x.Dzien,
       CASE WHEN x.Dzien IN (6, 7) THEN 1 ELSE 0 END,
       CASE WHEN d.Data IN ('20230501', '20230503', '20230608', '20230815',
                            '20240501', '20240503', '20240530', '20240815',
                            '20250501', '20250503', '20250619', '20250815',
                            '20260501', '20260503', '20260604', '20260815')
            THEN 1 ELSE 0 END,
       CASE WHEN d.Data BETWEEN '20230624' AND '20230831'
              OR d.Data BETWEEN '20240622' AND '20240831'
              OR d.Data BETWEEN '20250628' AND '20250831'
              OR d.Data BETWEEN '20260627' AND '20260831'
            THEN 1 ELSE 0 END
FROM Dni AS d
CROSS APPLY (SELECT CAST(DATEDIFF(day, '19000101', d.Data) % 7 + 1 AS tinyint) AS Dzien) AS x;
-- 1900-01-01 był poniedziałkiem, więc wynik nie zależy od SET DATEFIRST
 
/* 4. Historyczna pogoda (sezony 2023–2025) */
CREATE TABLE dbo.Pogoda
(
    Data    date         NOT NULL CONSTRAINT PK_Pogoda PRIMARY KEY
                                  CONSTRAINT FK_Pogoda_Kalendarz REFERENCES dbo.Kalendarz (Data),
    TempMax decimal(4,1) NULL,      -- maksymalna temperatura dnia [°C]
    OpadyMm decimal(4,1) NOT NULL   -- suma opadów [mm]
);
 
WITH Baza AS
(
    SELECT k.Data,
           DATEDIFF(day, DATEFROMPARTS(YEAR(k.Data), 5, 1), k.Data) AS t,
           YEAR(k.Data) AS Rok,
           CONVERT(char(8), k.Data, 112) AS Klucz
    FROM dbo.Kalendarz AS k
    WHERE k.Data < '20260101'
),
Temp AS
(
    SELECT b.Data, b.Klucz,
           CAST(ROUND(
                 15.0 + 11.0 * SIN(PI() * b.t / 152.0)             -- przebieg sezonowy
               + 3.0 * SIN(b.t / 5.0 + b.Rok)                       -- fale ciepła i ochłodzenia
               + CASE b.Rok WHEN 2024 THEN 1.0 WHEN 2025 THEN -0.5 ELSE 0.0 END
               + 7.0 * (dbo.fn_Los(CONCAT('T1', b.Klucz))
                      + dbo.fn_Los(CONCAT('T2', b.Klucz))
                      + dbo.fn_Los(CONCAT('T3', b.Klucz)) - 1.5)   -- zmienność dzienna
               , 1) AS decimal(4,1)) AS TempMax
    FROM Baza AS b
)
INSERT INTO dbo.Pogoda (Data, TempMax, OpadyMm)
SELECT t.Data,
       t.TempMax,
       CASE WHEN dbo.fn_Los(CONCAT('R', t.Klucz)) < CASE WHEN t.TempMax < 20 THEN 0.40 ELSE 0.25 END
            THEN CAST(ROUND(0.5 + 20.0 * POWER(dbo.fn_Los(CONCAT('M', t.Klucz)), 2), 1) AS decimal(4,1))
            ELSE 0.0
       END
FROM Temp AS t;
 
/* 5. Dzienna sprzedaż (liczba porcji) w punktach – sezony 2023–2025 */
CREATE TABLE dbo.Sprzedaz
(
    Data         date    NOT NULL CONSTRAINT FK_Sprzedaz_Kalendarz REFERENCES dbo.Kalendarz (Data),
    PunktID      tinyint NOT NULL CONSTRAINT FK_Sprzedaz_Punkt REFERENCES dbo.Punkt (PunktID),
    LiczbaPorcji int     NOT NULL,
    Promocja     bit     NOT NULL,
    CONSTRAINT PK_Sprzedaz PRIMARY KEY (Data, PunktID)
);
 
WITH Parametry AS
(
    -- "Ukryta prawda" symulacji: wrażliwość każdego punktu na pogodę i kalendarz
    SELECT *
    FROM (VALUES (1, 180.0, 0.070, 0.35, 0.70, 1.35, 1.40),
                 (2, 220.0, 0.050, 0.55, 0.80, 1.35, 1.15),
                 (3, 140.0, 0.055, 0.55, 0.80, 1.35, 1.15),
                 (4, 120.0, 0.020, 1.05, 1.00, 1.50, 1.10)
         ) AS p (PunktID, Baza, WspTemp, MnDeszcz, MnMzawka, MnWeekend, MnWakacje)
),
Dane AS
(
    SELECT k.Data, p.PunktID, p.Baza, p.WspTemp, p.MnDeszcz, p.MnMzawka, p.MnWeekend, p.MnWakacje,
           w.TempMax, w.OpadyMm, k.CzyWeekend, k.CzySwieto, k.CzyWakacje,
           CASE WHEN dbo.fn_Los(CONCAT('P', x.Klucz, '-', p.PunktID)) < 0.08 THEN 1 ELSE 0 END AS Promocja,
           1.0 + 0.25 * (dbo.fn_Los(CONCAT('S1', x.Klucz, '-', p.PunktID))
                       + dbo.fn_Los(CONCAT('S2', x.Klucz, '-', p.PunktID))
                       + dbo.fn_Los(CONCAT('S3', x.Klucz, '-', p.PunktID)) - 1.5) AS Szum
    FROM dbo.Kalendarz AS k
    JOIN dbo.Pogoda    AS w ON w.Data = k.Data
    CROSS JOIN Parametry AS p
    CROSS APPLY (SELECT CONVERT(char(8), k.Data, 112) AS Klucz) AS x
)
INSERT INTO dbo.Sprzedaz (Data, PunktID, LiczbaPorcji, Promocja)
SELECT Data, PunktID,
       CAST(ROUND(
             Baza * EXP(WspTemp * (TempMax - 22.0))
           * CASE WHEN OpadyMm >= 5 THEN MnDeszcz WHEN OpadyMm >= 1 THEN MnMzawka ELSE 1.0 END
           * CASE WHEN CzyWeekend = 1 THEN MnWeekend ELSE 1.0 END
           * CASE WHEN CzySwieto = 1 AND CzyWeekend = 0 THEN 1.40 ELSE 1.0 END
           * CASE WHEN CzyWakacje = 1 THEN MnWakacje ELSE 1.0 END
           * CASE WHEN Promocja = 1 THEN 1.25 ELSE 1.0 END
           * Szum, 0) AS int),
       Promocja
FROM Dane;
 
/* 6. Realistyczna usterka: stacja pogodowa nie zapisała temperatury w 3 dni */
UPDATE dbo.Pogoda
SET TempMax = NULL
WHERE Data IN ('20240717', '20240718', '20250805');
 
/* 7. Prognoza pogody na pierwsze dwa tygodnie lipca 2026 (od zewnętrznego dostawcy) */
CREATE TABLE dbo.PrognozaPogody
(
    Data    date         NOT NULL CONSTRAINT PK_PrognozaPogody PRIMARY KEY
                                  CONSTRAINT FK_PrognozaPogody_Kalendarz REFERENCES dbo.Kalendarz (Data),
    TempMax decimal(4,1) NOT NULL,
    OpadyMm decimal(4,1) NOT NULL
);
 
INSERT INTO dbo.PrognozaPogody (Data, TempMax, OpadyMm)
VALUES ('20260701', 24.5,  0.0), ('20260702', 26.0,  0.0), ('20260703', 28.5, 0.0),
       ('20260704', 31.0,  0.0), ('20260705', 32.5,  0.0), ('20260706', 29.0, 2.5),
       ('20260707', 21.0, 12.0), ('20260708', 18.5,  8.0), ('20260709', 20.0, 0.5),
       ('20260710', 23.5,  0.0), ('20260711', 25.0,  0.0), ('20260712', 27.0, 0.0),
       ('20260713', 26.5,  0.0), ('20260714', 22.0,  3.0);
 
/* 8. Zaplanowane akcje promocyjne */
CREATE TABLE dbo.PlanPromocji
(
    Data    date    NOT NULL CONSTRAINT FK_PlanPromocji_Kalendarz REFERENCES dbo.Kalendarz (Data),
    PunktID tinyint NOT NULL CONSTRAINT FK_PlanPromocji_Punkt REFERENCES dbo.Punkt (PunktID),
    Opis    nvarchar(100) NOT NULL,
    CONSTRAINT PK_PlanPromocji PRIMARY KEY (Data, PunktID)
);
 
INSERT INTO dbo.PlanPromocji (Data, PunktID, Opis)
VALUES ('20260704', 1, N'Druga gałka gratis'),
       ('20260704', 2, N'Druga gałka gratis'),
       ('20260711', 3, N'Rodzinny zestaw -20%');
GO
 
PRINT N'Baza LodyPrognoza gotowa.';
