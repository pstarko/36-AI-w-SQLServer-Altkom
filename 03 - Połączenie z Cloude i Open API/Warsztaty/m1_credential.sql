/* Ćwiczenie 1.2 – poświadczenie z kluczem API i wybór dostawcy
   Uruchom TYLKO część dla swojego dostawcy. Klucza nie zapisuj w repozytorium! */
USE AsystentOpinii;
GO
/* ---------- WARIANT CLAUDE (Anthropic) ---------- */
CREATE DATABASE SCOPED CREDENTIAL [https://api.anthropic.com]
    WITH IDENTITY = 'HTTPEndpointHeaders',
         SECRET   = '{"x-api-key":"<WKLEJ_SWOJ_KLUCZ_API>"}';
 
UPDATE dbo.KonfiguracjaLLM SET CzyAktywny = 0;
UPDATE dbo.KonfiguracjaLLM SET CzyAktywny = 1 WHERE Dostawca = 'Claude';
GO
/* ---------- WARIANT OPENAI ----------
CREATE DATABASE SCOPED CREDENTIAL [https://api.openai.com]
    WITH IDENTITY = 'HTTPEndpointHeaders',
         SECRET   = '{"Authorization":"Bearer <WKLEJ_SWOJ_KLUCZ_API>"}';
 
UPDATE dbo.KonfiguracjaLLM SET CzyAktywny = 0;
UPDATE dbo.KonfiguracjaLLM SET CzyAktywny = 1 WHERE Dostawca = 'OpenAI';
GO
*/
/* Sprawdzenie: poświadczenie istnieje, a sekret nie jest nigdzie widoczny */
SELECT name, credential_identity, create_date
FROM sys.database_scoped_credentials;
 
SELECT Dostawca, Model, Url, CzyAktywny FROM dbo.KonfiguracjaLLM;
