CREATE OR ALTER VIEW sklep.vw_ReviewAnalysis
AS
SELECT r.review_id,
       p.product_id,
       p.product_name,
       r.rating,
       r.review_text,
       s.sentiment,
       s.score,
       -- sentyment "oczekiwany" na podstawie gwiazdek
       CASE WHEN r.rating >= 4 THEN 'POSITIVE'
            WHEN r.rating <= 2 THEN 'NEGATIVE'
       END AS expected_sentiment,
       -- 1 = model zgadza się z oceną, 0 = rozbieżność, NULL = ocena neutralna (3)
       CASE WHEN r.rating = 3 THEN NULL
            WHEN (r.rating >= 4 AND s.sentiment = 'POSITIVE')
              OR (r.rating <= 2 AND s.sentiment = 'NEGATIVE') THEN 1
            ELSE 0
       END AS is_match
FROM   sklep.Reviews r
JOIN   sklep.Products p        ON p.product_id = r.product_id
JOIN   sklep.ReviewSentiment s ON s.review_id  = r.review_id;
GO
