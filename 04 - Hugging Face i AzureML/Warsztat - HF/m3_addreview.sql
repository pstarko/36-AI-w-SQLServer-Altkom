CREATE OR ALTER PROCEDURE sklep.usp_AddReview
    @product_id  INT,
    @rating      TINYINT,
    @review_text NVARCHAR(2000)
AS
BEGIN
    SET NOCOUNT ON;
 
    INSERT INTO sklep.Reviews (product_id, review_date, rating, review_text)
    VALUES (@product_id, CAST(GETDATE() AS DATE), @rating, @review_text);
 
    DECLARE @new_id INT = SCOPE_IDENTITY();
 
    -- analiza tylko nowych opinii (procedura z modułu 2)
    EXEC sklep.usp_ScoreReviews;
 
    SELECT * FROM sklep.vw_ReviewAnalysis WHERE review_id = @new_id;
END;
GO
 
-- Klient dał 5 gwiazdek, ale treść jest wyraźnie negatywna
EXEC sklep.usp_AddReview
     @product_id  = 3,
     @rating      = 5,
     @review_text = N'The mouse stopped working after three days. Very disappointed.';
