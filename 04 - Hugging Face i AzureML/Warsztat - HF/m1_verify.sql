SELECT N'1. Liczba produktów = 8' AS test,
       CASE WHEN (SELECT COUNT(*) FROM sklep.Products) = 8 THEN N'OK' ELSE N'BŁĄD' END AS wynik
UNION ALL
SELECT N'2. Liczba opinii = 40',
       CASE WHEN (SELECT COUNT(*) FROM sklep.Reviews) = 40 THEN N'OK' ELSE N'BŁĄD' END
UNION ALL
SELECT N'3. Opinie neutralne (ocena 3) = 3',
       CASE WHEN (SELECT COUNT(*) FROM sklep.Reviews WHERE rating = 3) = 3 THEN N'OK' ELSE N'BŁĄD' END
UNION ALL
SELECT N'4. Każdy produkt ma 5 opinii',
       CASE WHEN NOT EXISTS (SELECT product_id FROM sklep.Reviews
                             GROUP BY product_id HAVING COUNT(*) <> 5)
            THEN N'OK' ELSE N'BŁĄD' END
UNION ALL
SELECT N'5. Język myPython zarejestrowany w tej bazie',
       CASE WHEN EXISTS (SELECT 1 FROM sys.external_languages WHERE language = N'Python')
            THEN N'OK' ELSE N'BŁĄD' END;
