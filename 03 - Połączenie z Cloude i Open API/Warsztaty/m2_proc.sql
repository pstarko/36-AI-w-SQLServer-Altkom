/* Ćwiczenie 2.2 – analiza jednej opinii: prompt -> JSON -> walidacja -> tabela */
USE AsystentOpinii;
GO
CREATE OR ALTER PROCEDURE dbo.usp_AnalizujOpinie
    @OpiniaID int,
    @Etap     varchar(30) = 'M2-analiza'
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @System nvarchar(max), @Wersja int, @Tresc nvarchar(2000), @Prompt nvarchar(max),
            @Odp nvarchar(max), @Json nvarchar(max), @LogID int, @Proba int = 1, @Poprawny bit = 0,
            @Pierwsza int, @Ostatnia int;
 
    SELECT TOP (1) @System = TrescSystem, @Wersja = Wersja
    FROM dbo.PromptSzablon WHERE Nazwa = 'analiza_opinii' ORDER BY Wersja DESC;
 
    SELECT @Tresc = Tresc FROM dbo.Opinia WHERE OpiniaID = @OpiniaID;
    IF @Tresc IS NULL THROW 50010, N'Nie ma opinii o podanym identyfikatorze.', 1;
 
    SET @Prompt = CONCAT(N'<opinia>', @Tresc, N'</opinia>');
 
    WHILE @Proba <= 2 AND @Poprawny = 0
    BEGIN
        EXEC dbo.usp_LLM_Zapytaj @System = @System, @Prompt = @Prompt, @MaxTokens = 2000,
                                 @Etap = @Etap, @Odpowiedz = @Odp OUTPUT, @LogID = @LogID OUTPUT;
 
        /* Modele lubią opakować JSON w ```json ... ``` lub dodać komentarz – wycinamy fragment
           od pierwszego "{" do ostatniego "}". (Bez REGEXP: w części kompilacji SQL Server 2025
           funkcje REGEXP_* nie przyjmują argumentów nvarchar(max).) */
        SET @Pierwsza = CHARINDEX(N'{', @Odp);
        SET @Ostatnia = DATALENGTH(@Odp) / 2 - CHARINDEX(N'}', REVERSE(@Odp)) + 1;
        SET @Json = IIF(@Pierwsza > 0 AND CHARINDEX(N'}', @Odp) > 0 AND @Ostatnia > @Pierwsza,
                        SUBSTRING(@Odp, @Pierwsza, @Ostatnia - @Pierwsza + 1), NULL);
 
        /* Walidacja: poprawny JSON + dozwolone wartości (nie ufamy modelowi na słowo) */
        IF ISJSON(@Json, OBJECT) = 1
           AND JSON_VALUE(@Json, '$.sentyment') IN ('pozytywny', 'negatywny', 'mieszany', 'neutralny')
           AND JSON_VALUE(@Json, '$.kategoria_glowna') IN ('pokoj', 'czystosc', 'obsluga', 'jedzenie', 'halas',
                                                           'cena', 'lokalizacja', 'internet', 'udogodnienia', 'inne')
           AND TRY_CAST(JSON_VALUE(@Json, '$.pilnosc') AS int) BETWEEN 1 AND 5
           AND ISJSON(JSON_QUERY(@Json, '$.kategorie'), ARRAY) = 1
           AND LEN(JSON_VALUE(@Json, '$.jezyk')) = 2
            SET @Poprawny = 1;
        ELSE
        BEGIN
            /* Druga próba: dopisujemy informację zwrotną dla modelu */
            SET @Prompt = CONCAT(N'<opinia>', @Tresc, N'</opinia>', NCHAR(10),
                                 N'Twoja poprzednia odpowiedź nie była poprawnym JSON zgodnym ze schematem. ',
                                 N'Zwróć wyłącznie poprawny obiekt JSON.');
            SET @Proba += 1;
        END;
    END;
 
    IF @Poprawny = 0
        THROW 50011, N'Model dwukrotnie zwrócił niepoprawny JSON – sprawdź dbo.LogLLM.', 1;
 
    MERGE dbo.AnalizaOpinii AS cel
    USING (SELECT @OpiniaID AS OpiniaID,
                  JSON_VALUE(@Json, '$.sentyment')        AS Sentyment,
                  JSON_VALUE(@Json, '$.kategoria_glowna') AS KategoriaGlowna,
                  JSON_QUERY(@Json, '$.kategorie')        AS Kategorie,
                  CAST(JSON_VALUE(@Json, '$.pilnosc') AS tinyint) AS Pilnosc,
                  LOWER(JSON_VALUE(@Json, '$.jezyk'))     AS Jezyk,
                  LEFT(JSON_VALUE(@Json, '$.streszczenie'), 300) AS Streszczenie) AS zr
       ON cel.OpiniaID = zr.OpiniaID
    WHEN MATCHED THEN UPDATE SET Sentyment = zr.Sentyment, KategoriaGlowna = zr.KategoriaGlowna,
                                 Kategorie = zr.Kategorie, Pilnosc = zr.Pilnosc, Jezyk = zr.Jezyk,
                                 Streszczenie = zr.Streszczenie, WersjaPromptu = @Wersja,
                                 HashTresci = HASHBYTES('SHA2_256', @Tresc), LogID = @LogID,
                                 DataAnalizy = SYSDATETIME()
    WHEN NOT MATCHED THEN INSERT (OpiniaID, Sentyment, KategoriaGlowna, Kategorie, Pilnosc, Jezyk, Streszczenie,
                                  WersjaPromptu, HashTresci, LogID)
                          VALUES (zr.OpiniaID, zr.Sentyment, zr.KategoriaGlowna, zr.Kategorie, zr.Pilnosc, zr.Jezyk,
                                  zr.Streszczenie, @Wersja, HASHBYTES('SHA2_256', @Tresc), @LogID);
END;
GO
