SELECT N'1. Wszystkie 40 opinii ma wynik' AS test,
       CASE WHEN (SELECT COUNT(*) FROM sklep.ReviewSentiment) = 40
            THEN N'OK' ELSE N'BŁĄD' END AS wynik
UNION ALL
SELECT N'2. Brak opinii bez wyniku',
       CASE WHEN NOT EXISTS (SELECT 1 FROM sklep.Reviews r
                             LEFT JOIN sklep.ReviewSentiment s ON s.review_id = r.review_id
                             WHERE s.review_id IS NULL)
            THEN N'OK' ELSE N'BŁĄD' END
UNION ALL
SELECT N'3. Pewność modelu w zakresie 0.5 - 1.0',
       CASE WHEN (SELECT MIN(score) FROM sklep.ReviewSentiment) >= 0.5
             AND (SELECT MAX(score) FROM sklep.ReviewSentiment) <= 1.0
            THEN N'OK' ELSE N'BŁĄD' END
UNION ALL
SELECT N'4. Oczywisty przypadek pozytywny (id 1)',
       CASE WHEN (SELECT sentiment FROM sklep.ReviewSentiment WHERE review_id = 1) = 'POSITIVE'
            THEN N'OK' ELSE N'BŁĄD' END
UNION ALL
SELECT N'5. Oczywisty przypadek negatywny (id 21)',
       CASE WHEN (SELECT sentiment FROM sklep.ReviewSentiment WHERE review_id = 21) = 'NEGATIVE'
            THEN N'OK' ELSE N'BŁĄD' END;
