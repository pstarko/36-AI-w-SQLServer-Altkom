SELECT N'1. Zgodność modelu z ocenami >= 80%' AS test,
       CASE WHEN (SELECT 100.0 * SUM(is_match) / COUNT(is_match)
                  FROM sklep.vw_ReviewAnalysis) >= 80
            THEN N'OK' ELSE N'BŁĄD' END AS wynik
UNION ALL
SELECT N'2. Najgorzej oceniany produkt to StreamCam Pro',
       CASE WHEN (SELECT TOP (1) product_id FROM sklep.vw_ProductSentiment
                  ORDER BY negative_pct DESC) = 5
            THEN N'OK' ELSE N'BŁĄD' END
UNION ALL
SELECT N'3. Wykryto 4 zaplanowane anomalie (id 5, 19, 29, 38)',
       CASE WHEN (SELECT COUNT(*) FROM sklep.vw_ReviewAlerts
                  WHERE review_id IN (5, 19, 29, 38)) = 4
            THEN N'OK' ELSE N'BŁĄD' END
UNION ALL
SELECT N'4. Nowa opinia została automatycznie przeanalizowana',
       CASE WHEN (SELECT COUNT(*) FROM sklep.Reviews) > 40
             AND (SELECT COUNT(*) FROM sklep.Reviews)
               = (SELECT COUNT(*) FROM sklep.ReviewSentiment)
            THEN N'OK' ELSE N'BŁĄD' END
UNION ALL
SELECT N'5. Nowa opinia trafiła do alertów',
       CASE WHEN EXISTS (SELECT 1 FROM sklep.vw_ReviewAlerts
                         WHERE review_id = (SELECT MAX(review_id) FROM sklep.Reviews))
            THEN N'OK' ELSE N'BŁĄD' END;
