CREATE OR ALTER VIEW sklep.vw_ProductSentiment
AS
SELECT product_id,
       product_name,
       COUNT(*) AS review_count,
       CAST(AVG(CAST(rating AS DECIMAL(4,2))) AS DECIMAL(3,2)) AS avg_rating,
       CAST(100.0 * SUM(CASE WHEN sentiment = 'NEGATIVE' THEN 1 ELSE 0 END)
            / COUNT(*) AS DECIMAL(5,1)) AS negative_pct,
       CAST(AVG(score) AS DECIMAL(4,3)) AS avg_confidence
FROM   sklep.vw_ReviewAnalysis
GROUP BY product_id, product_name;
GO
 
-- Ranking produktów: od najgorzej odbieranego
SELECT * FROM sklep.vw_ProductSentiment ORDER BY negative_pct DESC;
