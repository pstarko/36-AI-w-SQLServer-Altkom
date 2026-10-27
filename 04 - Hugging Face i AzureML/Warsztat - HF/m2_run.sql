-- Przebieg 1: tylko pierwsze 10 opinii
EXEC sklep.usp_ScoreReviews @batch_size = 10;
SELECT COUNT(*) AS przeanalizowane FROM sklep.ReviewSentiment;   -- 10
 
-- Przebieg 2: pozostałe 30 opinii
EXEC sklep.usp_ScoreReviews;
SELECT COUNT(*) AS przeanalizowane FROM sklep.ReviewSentiment;   -- 40
 
-- Przebieg 3: nic nowego, w Messages: "Brak nowych opinii do analizy."
EXEC sklep.usp_ScoreReviews;
 
-- Podgląd wyników
SELECT r.review_id, r.rating, s.sentiment,
       CAST(s.score AS DECIMAL(5,4)) AS score, r.review_text
FROM   sklep.Reviews r
JOIN   sklep.ReviewSentiment s ON s.review_id = r.review_id
ORDER BY r.review_id;
