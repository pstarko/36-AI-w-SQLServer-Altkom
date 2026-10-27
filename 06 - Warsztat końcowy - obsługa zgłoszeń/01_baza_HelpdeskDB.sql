/* =====================================================================
   Warsztat: Python + OpenAI + SQL Server – automatyczna obsługa zgłoszeń
   Skrypt 01 – baza HelpdeskDB i tabela tickets (Moduł 1)
   Wymagania: SQL Server 2016 lub nowszy (środowisko kursu: SQL Server 2025), SSMS
   ===================================================================== */

USE master;
GO
IF DB_ID(N'HelpdeskDB') IS NULL
    CREATE DATABASE HelpdeskDB;
GO
USE HelpdeskDB;
GO

/* ---------------------------------------------------------------------
   Krok 1.2 – tabela dokładnie według specyfikacji zadania
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.tickets;
GO
CREATE TABLE dbo.tickets (
  id           int      IDENTITY (1,1) PRIMARY KEY,
  filename     text,                       -- nazwa pliku z katalogu
  raw_text     text,
  summary      text,
  is_prio      char(1)  DEFAULT 0,
  created_at   datetime DEFAULT GETDATE()
);
GO

/* ---------------------------------------------------------------------
   Krok 1.3 – sprawdzamy specyfikację krytycznie (uruchamiaj po kolei)
   --------------------------------------------------------------------- */

-- a) Polskie znaki w kolumnie typu text (varchar) zależą od collation bazy
INSERT INTO dbo.tickets (filename, raw_text)
VALUES (N'test_znaki.txt', N'Zażółć gęślą jaźń – awaria!');

SELECT id, filename, raw_text, is_prio, created_at
FROM dbo.tickets;
-- Jeżeli zamiast "Zażółć gęślą jaźń" widzisz inne litery lub znaki "?",
-- collation bazy nie obsługuje polskich znaków w typie text.

SELECT DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS CollationBazy;

-- b) Typu text nie da się porównać operatorem "=" (spodziewany BŁĄD 402)
SELECT id FROM dbo.tickets WHERE filename = N'test_znaki.txt';
GO

-- ... ale da się po rzutowaniu:
SELECT id FROM dbo.tickets WHERE CAST(filename AS nvarchar(260)) = N'test_znaki.txt';
GO

-- sprzątamy wiersz testowy
DELETE FROM dbo.tickets;
DBCC CHECKIDENT ('dbo.tickets', RESEED, 0);
GO

/* ---------------------------------------------------------------------
   Krok 1.4 – ZALECANA modernizacja schematu
   Typ text jest przestarzały (deprecated). Zamieniamy go na typy Unicode.
   Skrypt Pythona działa z OBIEMA wersjami tabeli.
   --------------------------------------------------------------------- */
ALTER TABLE dbo.tickets ALTER COLUMN filename nvarchar(260) NULL;
ALTER TABLE dbo.tickets ALTER COLUMN raw_text nvarchar(max) NULL;
ALTER TABLE dbo.tickets ALTER COLUMN summary  nvarchar(max) NULL;
ALTER TABLE dbo.tickets ADD CONSTRAINT CK_tickets_is_prio CHECK (is_prio IN ('0', '1'));
CREATE INDEX IX_tickets_filename ON dbo.tickets (filename);
GO

/* ---------------------------------------------------------------------
   Punkt kontrolny Modułu 1
   --------------------------------------------------------------------- */
SELECT c.name AS kolumna, t.name AS typ, c.max_length
FROM sys.columns AS c
JOIN sys.types   AS t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'dbo.tickets')
ORDER BY c.column_id;

SELECT COUNT(*) AS liczba_wierszy FROM dbo.tickets;   -- oczekiwane: 0
GO

/* ---------------------------------------------------------------------
   Zapytania weryfikacyjne do Modułu 4 (uruchom po przetworzeniu plików)
   --------------------------------------------------------------------- */
-- SELECT id, filename, is_prio, created_at,
--        LEFT(CAST(summary AS nvarchar(max)), 200) AS summary_poczatek
-- FROM dbo.tickets
-- ORDER BY is_prio DESC, created_at;
--
-- SELECT is_prio, COUNT(*) AS liczba FROM dbo.tickets GROUP BY is_prio;
