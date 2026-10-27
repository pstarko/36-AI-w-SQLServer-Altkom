CREATE OR ALTER VIEW sklep.vw_ReviewAlerts
AS
SELECT review_id,
       product_name,
       rating,
       sentiment,
       CAST(score AS DECIMAL(5,4)) AS score,
       CASE WHEN rating >= 4 THEN N'Wysoka ocena, negatywna treść'
            ELSE                  N'Niska ocena, pozytywna treść'
       END AS alert_type,
       review_text
FROM   sklep.vw_ReviewAnalysis
WHERE  is_match = 0
  AND  score >= 0.80;      -- alarmujemy tylko, gdy model jest pewny
GO
 
SELECT * FROM sklep.vw_ReviewAlerts ORDER BY review_id;
