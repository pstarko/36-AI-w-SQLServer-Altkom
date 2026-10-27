/* =====================================================================
   Warsztat: Python + OpenAI + SQL Server – automatyczna obsługa zgłoszeń
   Skrypt 05 – uruchamianie procedury Pythona z poziomu T-SQL (Moduł 5)
   Wymagania: SQL Server 2016 lub nowszy (środowisko kursu: SQL Server 2025),
              uprawnienia sysadmin, wykonane Moduły 1–4.

   Założenia ścieżek (bez spacji – xp_cmdshell nie lubi cudzysłowów):
     C:\Warsztat\tickets\ticket_processor.py
     C:\Warsztat\tickets\.venv\Scripts\python.exe
   ===================================================================== */

/* ---------------------------------------------------------------------
   Krok 5.1 – włączenie xp_cmdshell (domyślnie wyłączone!)
   --------------------------------------------------------------------- */
USE master;
GO
EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO

/* ---------------------------------------------------------------------
   Krok 5.2 – kto i czym uruchomi Pythona?
   --------------------------------------------------------------------- */
-- a) Konto Windows, z którym startują procesy xp_cmdshell (dla sysadmin: konto usługi SQL Server)
EXECUTE xp_cmdshell 'whoami';

-- b) Czy to konto widzi Pythona z venv i skrypt?
EXECUTE xp_cmdshell 'C:\Warsztat\tickets\.venv\Scripts\python.exe --version';
EXECUTE xp_cmdshell 'dir C:\Warsztat\tickets\ticket_processor.py';

-- c) Czy widzi klucz OpenAI? (plik openai_key.txt obok skryptu; wypisujemy tylko TAK/NIE)
EXECUTE xp_cmdshell 'C:\Warsztat\tickets\.venv\Scripts\python.exe -c "import sys; sys.path.insert(0, r''C:\Warsztat\tickets''); import ticket_processor as t; print(''klucz OpenAI:'', ''TAK'' if t.get_api_key() else ''NIE'')"';

-- d) Czy konto usługi ma login w SQL Server (Python łączy się przez Trusted_Connection)?
SELECT name, IS_SRVROLEMEMBER('sysadmin', name) AS czy_sysadmin
FROM sys.server_principals
WHERE name LIKE N'NT SERVICE\MSSQL%';
GO

/* ---------------------------------------------------------------------
   Krok 5.3 – tabela logu przebiegów
   Python zapisuje tu wynik każdego pliku. Dzięki temu T-SQL dostaje
   czytelną odpowiedź (z polskimi znakami), niezależnie od kodowania konsoli.
   --------------------------------------------------------------------- */
USE HelpdeskDB;
GO
DROP TABLE IF EXISTS dbo.ticket_log;
GO
CREATE TABLE dbo.ticket_log (
    log_id     int IDENTITY(1, 1)  NOT NULL CONSTRAINT PK_ticket_log PRIMARY KEY,
    run_id     uniqueidentifier    NOT NULL,
    logged_at  datetime2(0)        NOT NULL CONSTRAINT DF_ticket_log_logged_at DEFAULT (SYSDATETIME()),
    filename   nvarchar(260)       NULL,
    status     varchar(20)         NOT NULL,   -- ZAPISANO / POMINIETO / BLAD / BRAK_PLIKOW
    ticket_id  int                 NULL,       -- id z dbo.tickets, gdy zapisano
    message    nvarchar(4000)      NULL
);
CREATE INDEX IX_ticket_log_run_id ON dbo.ticket_log (run_id);
GO

/* ---------------------------------------------------------------------
   Krok 5.4 – procedura uruchamiająca Pythona
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.usp_ProcessIncomingTickets
    @run_id uniqueidentifier = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    /* Python łączy się z bazą OSOBNĄ sesją. Gdyby nasza sesja trzymała otwartą
       transakcję z blokadami na dbo.tickets, obie sesje czekałyby na siebie. */
    IF @@TRANCOUNT > 0
        THROW 50010, N'Uruchom dbo.usp_ProcessIncomingTickets poza otwartą transakcją.', 1;

    SET @run_id = NEWID();

    /* Polecenie jest STAŁE – jedyny zmienny element to GUID wygenerowany przez SQL Server.
       Nigdy nie doklejamy tu tekstu od użytkownika (ryzyko wstrzyknięcia poleceń systemu). */
    DECLARE @cmd nvarchar(4000) =
          N'C:\Warsztat\tickets\.venv\Scripts\python.exe '
        + N'C:\Warsztat\tickets\ticket_processor.py '
        + N'--run-id ' + CONVERT(nchar(36), @run_id)
        + N' 2>&1';                       -- komunikaty błędów też trafiają do wyniku

    DECLARE @rc int;
    DECLARE @output TABLE (line_no int IDENTITY(1, 1), line nvarchar(255));

    INSERT INTO @output (line)
    EXECUTE @rc = master.sys.xp_cmdshell @cmd;

    IF @rc <> 0
    BEGIN
        -- pokazujemy surowe wyjście Pythona (np. traceback), żeby było wiadomo, co poszło źle
        SELECT line AS python_output
        FROM @output
        WHERE line IS NOT NULL
        ORDER BY line_no;

        THROW 50011, N'Skrypt Pythona zakończył się błędem – szczegóły w wyniku python_output.', 1;
    END;

    -- Wynik 1: co się stało z każdym plikiem
    SELECT logged_at, filename, status, ticket_id, message
    FROM dbo.ticket_log
    WHERE run_id = @run_id
    ORDER BY log_id;

    -- Wynik 2: zgłoszenia zapisane w tym przebiegu
    SELECT t.id, t.filename, t.is_prio, t.created_at, t.summary
    FROM dbo.tickets  AS t
    JOIN dbo.ticket_log AS l
        ON l.ticket_id = t.id
    WHERE l.run_id = @run_id
    ORDER BY t.is_prio DESC, t.id;
END;
GO

/* ---------------------------------------------------------------------
   Krok 5.5 – uruchomienie z T-SQL
   (wcześniej: python przygotuj_zgloszenia.py, aby w skrzynce były pliki)
   --------------------------------------------------------------------- */
DECLARE @run uniqueidentifier;
EXECUTE dbo.usp_ProcessIncomingTickets @run_id = @run OUTPUT;
SELECT @run AS run_id;
GO

/* ---------------------------------------------------------------------
   Krok 5.6 – weryfikacja
   --------------------------------------------------------------------- */
-- historia przebiegów
SELECT run_id,
       MIN(logged_at)                                       AS start_przebiegu,
       SUM(CASE WHEN status = 'ZAPISANO'  THEN 1 ELSE 0 END) AS zapisane,
       SUM(CASE WHEN status = 'POMINIETO' THEN 1 ELSE 0 END) AS pominiete,
       SUM(CASE WHEN status = 'BLAD'      THEN 1 ELSE 0 END) AS bledy
FROM dbo.ticket_log
GROUP BY run_id
ORDER BY start_przebiegu DESC;

-- drugie uruchomienie przy pustej skrzynce → jeden wiersz BRAK_PLIKOW
EXECUTE dbo.usp_ProcessIncomingTickets;
GO

/* ---------------------------------------------------------------------
   Krok 5.7 – po zajęciach: wyłączamy xp_cmdshell
   --------------------------------------------------------------------- */
-- USE master;
-- EXECUTE sp_configure 'xp_cmdshell', 0;
-- RECONFIGURE;
-- EXECUTE sp_configure 'show advanced options', 0;
-- RECONFIGURE;
