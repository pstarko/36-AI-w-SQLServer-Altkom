-- Uruchom w bazie, w której zarejestrowany jest język myPython
-- (CREATE EXTERNAL LANGUAGE działa w obrębie jednej bazy danych).
 
IF SCHEMA_ID(N'sklep') IS NULL
    EXEC(N'CREATE SCHEMA sklep');
GO
 
-- Reset: pozwala uruchomić warsztat od zera dowolną liczbę razy
DROP VIEW      IF EXISTS sklep.vw_ReviewAlerts, sklep.vw_ProductSentiment, sklep.vw_ReviewAnalysis;
DROP PROCEDURE IF EXISTS sklep.usp_AddReview, sklep.usp_ScoreReviews;
DROP TABLE     IF EXISTS sklep.ReviewSentiment, sklep.Reviews, sklep.Products;
GO
