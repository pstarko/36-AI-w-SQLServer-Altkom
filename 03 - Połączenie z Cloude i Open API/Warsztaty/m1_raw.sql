/* Ćwiczenie 1.3 – pierwsze "surowe" wywołanie API z T-SQL */
USE AsystentOpinii;
GO
DECLARE @Ret int, @Response nvarchar(max), @Payload nvarchar(max);
 
/* Payload budujemy funkcją JSON_OBJECT, a nie sklejaniem tekstu – poprawne escapowanie gratis */
SET @Payload = JSON_OBJECT(
    'model': 'claude-haiku-5-5',
    'max_tokens': 300,
    'messages': JSON_ARRAY(JSON_OBJECT('role': 'user',
                                       'content': N'Podaj w jednym zdaniu jedną ciekawostkę o Gdańsku.')));
 
EXEC @Ret = sys.sp_invoke_external_rest_endpoint
     @url        = N'https://api.anthropic.com/v1/messages',
     @method     = 'POST',
     @headers    = N'{"anthropic-version":"2026-10-21"}',
     @credential = [https://api.anthropic.com],
     @payload    = @Payload,
     @timeout    = 60,
     @response   = @Response OUTPUT;
 
SELECT @Ret AS KodPowrotu,                                                   -- 0 = HTTP 2xx
       JSON_VALUE(@Response, '$.response.status.http.code') AS KodHTTP,
       @Response AS PelnaOdpowiedz;
 
/* Wyciągamy tylko to, co ważne */
SELECT b.Typ, b.Tekst
FROM OPENJSON(@Response, '$.result.content')
     WITH (Typ varchar(30) '$.type', Tekst nvarchar(max) '$.text') AS b;
 
SELECT JSON_VALUE(@Response, '$.result.usage.input_tokens')  AS TokenyWe,
       JSON_VALUE(@Response, '$.result.usage.output_tokens') AS TokenyWy,
       JSON_VALUE(@Response, '$.result.stop_reason')         AS PowodZakonczenia;
GO
/* ---------- WARIANT OPENAI (Responses API) – zamień powyższe:
SET @Payload = JSON_OBJECT('model': 'gpt-6-luna', 'max_output_tokens': 300,
                           'input': N'Podaj w jednym zdaniu jedną ciekawostkę o Gdańsku.');
EXEC @Ret = sys.sp_invoke_external_rest_endpoint
     @url = N'https://api.openai.com/v1/responses', @method = 'POST',
     @credential = [https://api.openai.com], @payload = @Payload, @timeout = 60,
     @response = @Response OUTPUT;
-- tekst:   $.result.output[?type=message].content[?type=output_text].text
-- tokeny:  $.result.usage.input_tokens, $.result.usage.output_tokens
*/


--WERSJA OPEN AI
DECLARE @pytanie   NVARCHAR(MAX) = N'Ile mieszkańców ma Gdańsk';
DECLARE @payload   NVARCHAR(MAX);
DECLARE @response  NVARCHAR(MAX);
DECLARE @ret       INT;

-- Budowa JSON-a (JSON_OBJECT sam escapuje cudzysłowy i znaki specjalne)
SET @payload = JSON_OBJECT(
    'model': 'gpt-4o-mini',
    'temperature': 0.2,
    'messages': JSON_ARRAY(
        --JSON_OBJECT('role':'system', 'content':'Jesteś ekspertem SQL Server. Odpowiadasz po polsku.'),
        JSON_OBJECT('role':'user',   'content':@pytanie)
    )
);

EXEC @ret = sp_invoke_external_rest_endpoint
     @url        = N'https://api.openai.com/v1/chat/completions',
     @method     = 'POST',
     @headers    = N'{"Content-Type":"application/json"}',
     @credential = [https://api.openai.com],
     @payload    = @payload,
     @timeout    = 60,
     @response   = @response OUTPUT;

-- 1) Surowa odpowiedź (do podglądu struktury)
SELECT @ret AS return_code, @response AS surowy_json;

-- 2) Wyciągnięte, czytelne pola
SELECT
    JSON_VALUE(@response, '$.response.status.http.code')          AS http_status,
    JSON_VALUE(@response, '$.result.model')                       AS model,
    JSON_VALUE(@response, '$.result.choices[0].message.content')  AS odpowiedz,
    JSON_VALUE(@response, '$.result.usage.prompt_tokens')         AS tokeny_prompt,
    JSON_VALUE(@response, '$.result.usage.completion_tokens')     AS tokeny_odpowiedz,
    JSON_VALUE(@response, '$.result.error.message')               AS blad;   -- NULL, jeśli OK

-- 3) Wersja "na ekran" w zakładce Messages
DECLARE @odp NVARCHAR(MAX) = JSON_VALUE(@response, '$.result.choices[0].message.content');
PRINT @odp;