/* Ćwiczenie 4.2 – uzupełniamy "hak" z Modułu 1: maskowanie danych osobowych
   Zmieniamy JEDNĄ funkcję – chroni ona automatycznie każde wywołanie modelu. */
USE AsystentOpinii;
GO
CREATE OR ALTER FUNCTION dbo.fn_FiltrPrywatnosci (@Tekst nvarchar(max))
RETURNS nvarchar(max)
AS
BEGIN
    /* REGEXP_REPLACE w części kompilacji SQL Server 2025 nie przyjmuje nvarchar(max),
       dlatego dłuższy tekst przetwarzamy w kawałkach do 4000 znaków. Tniemy tylko na spacji
       poprzedzonej znakiem innym niż cyfra – nie rozetniemy e-maila ani numeru telefonu. */
    DECLARE @Wynik nvarchar(max) = N'', @Reszta nvarchar(max) = @Tekst,
            @Kawalek nvarchar(4000), @Dl int, @Ciecie int;
 
    IF @Tekst IS NULL RETURN NULL;
 
    WHILE DATALENGTH(@Reszta) > 0
    BEGIN
        IF DATALENGTH(@Reszta) / 2 <= 4000
            SET @Dl = DATALENGTH(@Reszta) / 2;
        ELSE
        BEGIN
            SET @Kawalek = SUBSTRING(@Reszta, 1, 4000);
            SET @Ciecie  = PATINDEX(N'% [^0-9]%', REVERSE(@Kawalek));   -- ostatnia "bezpieczna" spacja
            SET @Dl      = IIF(@Ciecie > 0, 4000 - @Ciecie + 1, 4000);
        END;
 
        SET @Kawalek = SUBSTRING(@Reszta, 1, @Dl);
        SET @Kawalek = REGEXP_REPLACE(@Kawalek, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '[EMAIL]');
        SET @Kawalek = REGEXP_REPLACE(@Kawalek, '(\+48[ -]?)?\d{3}[ -]?\d{3}[ -]?\d{3}', '[TELEFON]');
 
        SET @Wynik  = @Wynik + @Kawalek;
        SET @Reszta = SUBSTRING(@Reszta, @Dl + 1, DATALENGTH(@Reszta) / 2);
    END;
 
    RETURN @Wynik;
END;
GO
/* Test funkcji */
SELECT dbo.fn_FiltrPrywatnosci(N'Kontakt: anna.kowalska@example.com, tel. +48 601 234 567 lub 512-345-678. Pokój 214, 650 zł.')
       AS PoMaskowaniu;
GO
/* Sprzątanie po incydencie: dane już wyszły do dostawcy, ale nie trzymajmy ich dodatkowo w dzienniku */
UPDATE dbo.LogLLM
SET Zapytanie       = dbo.fn_FiltrPrywatnosci(Zapytanie),
    OdpowiedzSurowa = dbo.fn_FiltrPrywatnosci(OdpowiedzSurowa),
    Odpowiedz       = dbo.fn_FiltrPrywatnosci(Odpowiedz);
