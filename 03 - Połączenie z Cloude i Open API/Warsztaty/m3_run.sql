/* Ćwiczenie 3.2 – analiza całego archiwum i drugie uruchomienie (test cache) */
USE AsystentOpinii;
GO
EXEC dbo.usp_AnalizujWszystkie @BudzetUSD = 0.50;   -- ok. 35 wywołań, 1–3 min
GO
EXEC dbo.usp_AnalizujWszystkie @BudzetUSD = 0.50;   -- powinno być 0 wywołań API
GO
SELECT * FROM dbo.BladPrzetwarzania;                 -- najlepiej pusto
