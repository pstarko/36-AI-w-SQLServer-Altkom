/* Ćwiczenie 1.4 – fundament całego warsztatu: jedna procedura do rozmowy z modelem.
   Każdy kolejny moduł korzysta z niej i ją "ubogaca" – nie wywołujemy API nigdzie indziej. */
USE AsystentOpinii;
GO
CREATE OR ALTER PROCEDURE dbo.usp_LLM_Zapytaj
    @System    nvarchar(max) = NULL,          -- instrukcja systemowa (rola, zasady)
    @Prompt    nvarchar(max),                 -- treść pytania użytkownika
    @MaxTokens int           = 1024,
    @Etap      varchar(30)   = 'test',        -- etykieta do raportów i kosztów
    @Odpowiedz nvarchar(max) = NULL OUTPUT,
    @LogID     int           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @Dostawca varchar(10), @Url nvarchar(400), @Model varchar(100), @Poswiadczenie sysname,
            @Naglowki nvarchar(1000), @CenaWe decimal(10,4), @CenaWy decimal(10,4),
            @Payload nvarchar(max), @Response nvarchar(max), @Ret int, @Blad nvarchar(4000),
            @Start datetime2(3) = SYSDATETIME(), @TokenyWe int, @TokenyWy int, @Powod varchar(40);
 
    SELECT @Dostawca = Dostawca, @Url = Url, @Model = Model, @Poswiadczenie = NazwaPoswiadczenia,
           @Naglowki = Naglowki, @CenaWe = CenaWejscieUSD, @CenaWy = CenaWyjscieUSD
    FROM dbo.KonfiguracjaLLM
    WHERE CzyAktywny = 1;
 
    IF @Dostawca IS NULL
        THROW 50001, N'Brak aktywnego dostawcy w dbo.KonfiguracjaLLM.', 1;
 
    /* 1. Filtr prywatności (w Module 4 zacznie maskować dane osobowe) */
    SET @Prompt = dbo.fn_FiltrPrywatnosci(@Prompt);
 
    /* 2. Treść żądania – każdy dostawca ma własny format */
    SET @Payload = CASE @Dostawca
        WHEN 'Claude' THEN JSON_OBJECT('model': @Model, 'max_tokens': @MaxTokens, 'system': @System,
                                       'messages': JSON_ARRAY(JSON_OBJECT('role': 'user', 'content': @Prompt))
                                       ABSENT ON NULL)
        WHEN 'OpenAI' THEN JSON_OBJECT('model': @Model, 'max_output_tokens': @MaxTokens,
                                       'instructions': @System, 'input': @Prompt
                                       ABSENT ON NULL)
    END;
 
    /* 3. Wywołanie HTTPS (ponowienia przy 429/5xx robi sama procedura systemowa) */
    BEGIN TRY
        EXEC @Ret = sys.sp_invoke_external_rest_endpoint
             @url         = @Url,
             @method      = 'POST',
             @headers     = @Naglowki,
             @credential  = @Poswiadczenie,
             @payload     = @Payload,
             @timeout     = 120,
             @retry_count = 2,
             @response    = @Response OUTPUT;
    END TRY
    BEGIN CATCH
        SELECT @Ret = -1, @Blad = ERROR_MESSAGE();
    END CATCH;
 
    /* 4. Odczyt odpowiedzi – szukamy bloków tekstowych, a nie "pierwszego elementu tablicy" */
    IF @Ret = 0
    BEGIN
        IF @Dostawca = 'Claude'
            SELECT @Odpowiedz = STRING_AGG(b.Tekst, N'')
            FROM OPENJSON(@Response, '$.result.content')
                 WITH (Typ varchar(30) '$.type', Tekst nvarchar(max) '$.text') AS b
            WHERE b.Typ = 'text';
        ELSE
            SELECT @Odpowiedz = STRING_AGG(c.Tekst, N'')
            FROM OPENJSON(@Response, '$.result.output')
                 WITH (Typ varchar(30) '$.type', Zawartosc nvarchar(max) '$.content' AS JSON) AS o
            CROSS APPLY OPENJSON(o.Zawartosc)
                 WITH (Typ varchar(30) '$.type', Tekst nvarchar(max) '$.text') AS c
            WHERE o.Typ = 'message' AND c.Typ = 'output_text';
 
        SELECT @TokenyWe = TRY_CAST(JSON_VALUE(@Response, '$.result.usage.input_tokens')  AS int),
               @TokenyWy = TRY_CAST(JSON_VALUE(@Response, '$.result.usage.output_tokens') AS int),
               @Powod    = COALESCE(JSON_VALUE(@Response, '$.result.stop_reason'),
                                    JSON_VALUE(@Response, '$.result.status'));
 
        IF @Powod IN ('max_tokens', 'incomplete')
            SET @Blad = N'Odpowiedź ucięta – zwiększ @MaxTokens.';
    END
    ELSE
        SET @Blad = COALESCE(@Blad, JSON_VALUE(@Response, '$.result.error.message'),
                             CONCAT(N'HTTP ', @Ret));
 
    /* 5. Dziennik – zawsze, także przy błędzie */
    INSERT INTO dbo.LogLLM (CzasStart, CzasMs, Etap, Dostawca, Model, KodHTTP, TokenyWe, TokenyWy, KosztUSD,
                            PowodZakonczenia, Zapytanie, Odpowiedz, OdpowiedzSurowa, Blad)
    VALUES (@Start, DATEDIFF(millisecond, @Start, SYSDATETIME()), @Etap, @Dostawca, @Model,
            TRY_CAST(JSON_VALUE(@Response, '$.response.status.http.code') AS int),
            @TokenyWe, @TokenyWy,
            (ISNULL(@TokenyWe, 0) * @CenaWe + ISNULL(@TokenyWy, 0) * @CenaWy) / 1000000.0,
            @Powod, @Payload, @Odpowiedz, @Response, @Blad);
 
    SET @LogID = SCOPE_IDENTITY();
 
    IF @Blad IS NOT NULL
    BEGIN
        SET @Blad = LEFT(CONCAT(N'Błąd wywołania LLM (LogID ', @LogID, N'): ', @Blad), 2000);
        THROW 50002, @Blad, 1;
    END;
END;
GO
 
/* Test: pytanie z jednoznaczną odpowiedzią */
DECLARE @Odp nvarchar(max), @Log int;
EXEC dbo.usp_LLM_Zapytaj
     @System    = N'Odpowiadasz jednym słowem, bez kropki.',
     @Prompt    = N'Jak nazywa się stolica Polski?',
     @Etap      = 'M1-test',
     @Odpowiedz = @Odp OUTPUT,
     @LogID     = @Log OUTPUT;
 
SELECT @Odp AS Odpowiedz;
SELECT LogID, Etap, Dostawca, Model, KodHTTP, CzasMs, TokenyWe, TokenyWy, KosztUSD, PowodZakonczenia
FROM dbo.LogLLM WHERE LogID = @Log;
