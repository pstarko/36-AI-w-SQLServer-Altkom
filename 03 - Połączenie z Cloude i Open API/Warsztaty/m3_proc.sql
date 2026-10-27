/* Ćwiczenie 3.1 – przetwarzanie wsadowe: idempotentność, budżet i obsługa błędów */
USE AsystentOpinii;
GO
CREATE TABLE dbo.BladPrzetwarzania
(
    BladID   int IDENTITY(1,1) PRIMARY KEY,
    OpiniaID int            NOT NULL,
    Czas     datetime2(0)   NOT NULL DEFAULT SYSDATETIME(),
    Komunikat nvarchar(2048) NOT NULL
);
GO
CREATE OR ALTER PROCEDURE dbo.usp_AnalizujWszystkie
    @BudzetUSD decimal(10,4) = 0.50,
    @Etap      varchar(30)   = 'M3-wsad',
    @ZwrocPodsumowanie bit   = 1          -- 0 = bez zestawu wyników (gdy wołamy z innej procedury)
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @Wersja int = (SELECT MAX(Wersja) FROM dbo.PromptSzablon WHERE Nazwa = 'analiza_opinii'),
            @Start datetime2(3) = SYSDATETIME(), @Id int, @Wydano decimal(12,8) = 0,
            @Nowe int = 0, @Bledy int = 0, @Przerwano bit = 0;
 
    /* Tylko opinie bez aktualnej analizy: nowe, zmienione (inny hash) lub z nowszą wersją promptu */
    DECLARE kolejka CURSOR LOCAL FAST_FORWARD FOR
        SELECT o.OpiniaID
        FROM dbo.Opinia AS o
        WHERE NOT EXISTS (SELECT 1 FROM dbo.AnalizaOpinii AS a
                          WHERE a.OpiniaID = o.OpiniaID
                            AND a.WersjaPromptu = @Wersja
                            AND a.HashTresci = HASHBYTES('SHA2_256', o.Tresc))
        ORDER BY o.OpiniaID;
 
    OPEN kolejka;
    FETCH NEXT FROM kolejka INTO @Id;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        /* Bezpiecznik kosztowy liczony z dziennika */
        SELECT @Wydano = ISNULL(SUM(KosztUSD), 0) FROM dbo.LogLLM WHERE CzasStart >= @Start;
        IF @Wydano >= @BudzetUSD
        BEGIN
            SET @Przerwano = 1;
            BREAK;
        END;
 
        BEGIN TRY
            EXEC dbo.usp_AnalizujOpinie @OpiniaID = @Id, @Etap = @Etap;
            SET @Nowe += 1;
        END TRY
        BEGIN CATCH
            SET @Bledy += 1;
            INSERT INTO dbo.BladPrzetwarzania (OpiniaID, Komunikat) VALUES (@Id, ERROR_MESSAGE());
        END CATCH;
 
        FETCH NEXT FROM kolejka INTO @Id;
    END;
    CLOSE kolejka;
    DEALLOCATE kolejka;
 
    IF @ZwrocPodsumowanie = 1
    SELECT @Nowe AS Przeanalizowane, @Bledy AS Bledy,
           (SELECT COUNT(*) FROM dbo.LogLLM WHERE CzasStart >= @Start) AS WywolaniaAPI,
           CAST((SELECT ISNULL(SUM(KosztUSD), 0) FROM dbo.LogLLM WHERE CzasStart >= @Start) AS decimal(12,6)) AS KosztUSD,
           IIF(@Przerwano = 1, N'Przerwano – wyczerpany budżet', N'Zakończono') AS Status,
           DATEDIFF(second, @Start, SYSDATETIME()) AS CzasSek;
END;
GO
