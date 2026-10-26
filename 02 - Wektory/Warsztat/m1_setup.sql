/* ============================================================
   Moduł 1 – skrypt przygotowujący dane (uruchamiany od zera)
   Wymagania: SQL Server 2025 (typ VECTOR, VECTOR_NORMALIZE,
   GENERATE_SERIES). Dane fikcyjne i deterministyczne.
   ============================================================ */
USE master;
GO
IF DB_ID(N'WektoryHelpdesk') IS NOT NULL
BEGIN
    ALTER DATABASE WektoryHelpdesk SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE WektoryHelpdesk;
END;
GO
CREATE DATABASE WektoryHelpdesk;
GO
USE WektoryHelpdesk;
GO
 
/* 1. Deterministyczny generator liczb pseudolosowych z przedziału [0, 1) */
CREATE OR ALTER FUNCTION dbo.fn_Los (@Klucz varchar(100))
RETURNS float
WITH SCHEMABINDING
AS
BEGIN
    RETURN ABS(CAST(CAST(HASHBYTES('MD5', @Klucz) AS binary(4)) AS int) % 1000000) / 1000000.0;
END;
GO
 
/* 2. Słownik kategorii i tematów zgłoszeń wraz ze standardowymi rozwiązaniami */
CREATE TABLE dbo.Kategoria
(
    KategoriaID tinyint      NOT NULL CONSTRAINT PK_Kategoria PRIMARY KEY,
    Nazwa       nvarchar(50) NOT NULL
);
 
INSERT INTO dbo.Kategoria (KategoriaID, Nazwa)
VALUES (1, N'Konto i logowanie'), (2, N'Płatności'),   (3, N'Dostawa'),           (4, N'Zwroty'),
       (5, N'Faktury'),           (6, N'Aplikacja mobilna'), (7, N'Program lojalnościowy'), (8, N'Uszkodzony produkt');
 
CREATE TABLE dbo.Temat
(
    TematID     tinyint       NOT NULL CONSTRAINT PK_Temat PRIMARY KEY,
    KategoriaID tinyint       NOT NULL CONSTRAINT FK_Temat_Kategoria REFERENCES dbo.Kategoria (KategoriaID),
    Tytul       nvarchar(80)  NOT NULL,
    Rozwiazanie nvarchar(300) NOT NULL,   -- standardowa odpowiedź z bazy wiedzy
    Waga        tinyint       NOT NULL,   -- względna częstość tematu (do generatora)
    Fraza1      nvarchar(150) NOT NULL,
    Fraza2      nvarchar(150) NOT NULL
);
 
INSERT INTO dbo.Temat (TematID, KategoriaID, Tytul, Rozwiazanie, Waga, Fraza1, Fraza2)
VALUES
 (1, 1, N'Reset zapomnianego hasła', N'Wyślij link resetujący z panelu konsultanta (ważny 30 min). Poproś o sprawdzenie folderu SPAM.', 6,
     N'Nie pamiętam hasła do konta i nie mogę się zalogować.', N'Link do resetu hasła nie przychodzi na mój e-mail.'),
 (2, 1, N'Konto zablokowane po nieudanych logowaniach', N'Odblokuj konto w panelu (Klienci > Bezpieczeństwo) po weryfikacji tożsamości kodem SMS.', 3,
     N'Po kilku próbach logowania konto zostało zablokowane.', N'System pisze, że moje konto jest zablokowane ze względów bezpieczeństwa.'),
 (3, 1, N'Zmiana adresu e-mail konta', N'Zmiana w Ustawienia > Dane konta; wymaga potwierdzenia na starym i nowym adresie.', 2,
     N'Chcę zmienić adres e-mail przypisany do konta.', N'Mam nowy adres mailowy, jak go podmienić w profilu?'),
 (4, 2, N'Odrzucona płatność BLIK', N'Poproś o ponowienie płatności z poziomu zamówienia; kod BLIK jest ważny 2 minuty. Sprawdź limity w banku.', 4,
     N'Płatność BLIK została odrzucona, a zamówienie wisi jako nieopłacone.', N'Kod BLIK nie przechodzi, za każdym razem błąd płatności.'),
 (5, 2, N'Podwójne obciążenie karty', N'Zweryfikuj transakcje u operatora płatności; nadmiarowa kwota wraca automatycznie w 3–5 dni roboczych.', 5,
     N'Pieniądze zostały pobrane z karty dwa razy za to samo zamówienie.', N'Na wyciągu widzę podwójną transakcję za jeden zakup.'),
 (6, 2, N'Przelew niezaksięgowany', N'Poproś o potwierdzenie przelewu (PDF) i przekaż do księgowości; księgowanie do 2 dni roboczych.', 3,
     N'Zapłaciłem przelewem trzy dni temu, a zamówienie nadal jest nieopłacone.', N'Wysłałem przelew tradycyjny, ale status płatności się nie zmienił.'),
 (7, 3, N'Opóźniona przesyłka', N'Sprawdź status u przewoźnika; po 5 dniach roboczych opóźnienia zgłoś reklamację przewozową.', 9,
     N'Paczka miała być wczoraj, a nadal jej nie ma.', N'Przesyłka utknęła w sortowni od kilku dni.'),
 (8, 3, N'Zmiana adresu dostawy', N'Zmiana możliwa przed nadaniem paczki; po nadaniu – przekierowanie na stronie przewoźnika.', 4,
     N'Chcę zmienić adres dostawy w złożonym zamówieniu.', N'Pomyliłem adres w zamówieniu, czy można go jeszcze poprawić?'),
 (9, 3, N'Nieudane doręczenie lub pełny paczkomat', N'Paczka czeka w oddziale 3 dni; podaj numer do awizacji lub zleć ponowne doręczenie.', 5,
     N'Kurier nie zastał mnie w domu i paczka wróciła do oddziału.', N'Paczkomat był pełny i przesyłkę przekierowano gdzie indziej.'),
 (10, 4, N'Procedura zwrotu w 14 dni', N'Klient zgłasza zwrot w Moje zamówienia > Zwrot; odsyłka w ciągu 14 dni od zgłoszenia.', 4,
     N'Jak mogę zwrócić produkt, który mi nie pasuje?', N'Chcę odstąpić od umowy i oddać towar.'),
 (11, 4, N'Brak zwrotu pieniędzy', N'Zwrot środków do 14 dni od otrzymania paczki zwrotnej; sprawdź status w magazynie zwrotów.', 4,
     N'Odesłałem towar dwa tygodnie temu i nadal nie dostałem pieniędzy.', N'Zwrot został przyjęty, ale pieniądze nie wróciły na konto.'),
 (12, 4, N'Niedziałająca etykieta zwrotna', N'Wygeneruj nową etykietę w panelu zwrotów; stara traci ważność po 7 dniach.', 2,
     N'Etykieta zwrotna nie daje się wydrukować.', N'Kod zwrotu jest nieaktywny w punkcie nadania.'),
 (13, 5, N'Brak faktury VAT', N'Faktura jest w Moje zamówienia > Dokumenty; ponowna wysyłka z panelu konsultanta.', 3,
     N'Nie otrzymałem faktury do zamówienia.', N'Gdzie znajdę fakturę za zakupy?'),
 (14, 5, N'Błędne dane na fakturze', N'Wystaw fakturę korygującą po potwierdzeniu poprawnych danych (NIP, nazwa firmy).', 2,
     N'Na fakturze jest błędny NIP firmy.', N'Faktura ma literówkę w nazwie firmy, potrzebuję korekty.'),
 (15, 5, N'Faktura na firmę po zakupie', N'Fakturę na firmę można wystawić do 3 miesięcy od zakupu, jeśli paragon zawierał NIP.', 2,
     N'Kupiłem jako osoba prywatna, a potrzebuję faktury na firmę.', N'Zapomniałem podać NIP przy zamówieniu, czy dostanę fakturę firmową?'),
 (16, 6, N'Aplikacja się zawiesza', N'Poproś o aktualizację aplikacji i wyczyszczenie pamięci podręcznej; zbierz model telefonu i wersję systemu.', 3,
     N'Aplikacja mobilna zawiesza się przy otwieraniu koszyka.', N'Po aktualizacji aplikacja zamyka się sama po kilku sekundach.'),
 (17, 6, N'Brak powiadomień push', N'Sprawdź zgody na powiadomienia w telefonie oraz w Ustawienia > Powiadomienia w aplikacji.', 2,
     N'Nie dostaję żadnych powiadomień z aplikacji.', N'Powiadomienia o statusie zamówienia przestały przychodzić na telefon.'),
 (18, 6, N'Koszyk nie synchronizuje się', N'Wyloguj i zaloguj ponownie; synchronizacja wymaga tego samego konta na obu urządzeniach.', 2,
     N'Produkty dodane na komputerze nie pojawiają się w koszyku w aplikacji.', N'Koszyk w telefonie jest pusty, choć na stronie mam produkty.'),
 (19, 7, N'Nienaliczone punkty', N'Punkty naliczają się 14 dni po dostawie (po okresie zwrotu); jeśli dłużej – dopisz je ręcznie.', 3,
     N'Nie dostałem punktów za ostatnie zakupy.', N'Punkty lojalnościowe za zamówienie się nie pojawiły.'),
 (20, 7, N'Kod rabatowy nie działa', N'Sprawdź warunki kodu (minimalna kwota, kategorie, data ważności) w panelu promocji.', 4,
     N'Kod rabatowy nie działa w koszyku.', N'Przy wpisaniu kodu promocyjnego dostaję komunikat, że jest nieprawidłowy.'),
 (21, 7, N'Wygasłe punkty', N'Punkty wygasają po 12 miesiącach; wyjątkowo przywraca je kierownik zmiany.', 1,
     N'Moje punkty lojalnościowe nagle zniknęły.', N'Dlaczego wygasły mi punkty, które zbierałem?'),
 (22, 8, N'Uszkodzenie w transporcie', N'Poproś o zdjęcia paczki i produktu; wyślij nowy egzemplarz i zleć odbiór uszkodzonego na koszt sklepu.', 4,
     N'Paczka dotarła zgnieciona, a produkt jest pęknięty.', N'Towar przyszedł uszkodzony, karton był rozerwany.'),
 (23, 8, N'Wada fabryczna – reklamacja', N'Przyjmij reklamację z tytułu rękojmi; produkt trafia do serwisu, odpowiedź w 14 dni.', 3,
     N'Ekspres przestał działać po dwóch tygodniach.', N'Produkt ma wadę, chcę złożyć reklamację.'),
 (24, 8, N'Brak elementu w zestawie', N'Wyślij brakujący element z magazynu części; jeśli niedostępny – zaproponuj wymianę zestawu.', 3,
     N'W zestawie brakuje jednego elementu.', N'W paczce nie było ładowarki, która miała być w komplecie.');
 
/* 3. "Model językowy" w miniaturze: składowe wektorów kategorii (C) i tematów (O).
      W produkcji embedding wylicza model AI z treści zgłoszenia – tutaj symulujemy
      go, aby warsztat działał offline i dawał identyczne wyniki u wszystkich. */
CREATE TABLE #Skladowa (Typ char(1), ID int, Wym int, Wart float, PRIMARY KEY (Typ, ID, Wym));
 
INSERT INTO #Skladowa (Typ, ID, Wym, Wart)
SELECT 'C', k.KategoriaID, d.value, 2 * dbo.fn_Los(CONCAT('C', k.KategoriaID, '-', d.value)) - 1
FROM dbo.Kategoria AS k CROSS JOIN GENERATE_SERIES(1, 32) AS d;
 
INSERT INTO #Skladowa (Typ, ID, Wym, Wart)
SELECT 'O', t.TematID, d.value, 2 * dbo.fn_Los(CONCAT('O', t.TematID, '-', d.value)) - 1
FROM dbo.Temat AS t CROSS JOIN GENERATE_SERIES(1, 32) AS d;
 
/* 4. Archiwum 1200 zgłoszeń z 2026 r. (temat losowany zgodnie z wagami) */
CREATE TABLE #Zgl (ZgloszenieID int PRIMARY KEY, PrawdziwyTematID tinyint);
 
WITH Wagi AS
(
    SELECT TematID,
           SUM(Waga) OVER (ORDER BY TematID ROWS UNBOUNDED PRECEDING) AS Kumulacja,
           SUM(Waga) OVER () AS Suma
    FROM dbo.Temat
)
INSERT INTO #Zgl (ZgloszenieID, PrawdziwyTematID)
SELECT g.value, x.TematID
FROM GENERATE_SERIES(1, 1200) AS g
CROSS APPLY (SELECT TOP (1) w.TematID
             FROM Wagi AS w
             WHERE w.Kumulacja > dbo.fn_Los(CONCAT('T', g.value)) * w.Suma
             ORDER BY w.TematID) AS x;
 
CREATE TABLE dbo.Zgloszenie
(
    ZgloszenieID   int           NOT NULL CONSTRAINT PK_Zgloszenie PRIMARY KEY CLUSTERED,
    DataZgloszenia date          NOT NULL,
    Kanal          varchar(10)   NOT NULL,
    TematID        tinyint       NOT NULL CONSTRAINT FK_Zgloszenie_Temat REFERENCES dbo.Temat (TematID),
    Tresc          nvarchar(300) NOT NULL,
    Embedding      vector(32)    NOT NULL
);
 
WITH Skladowe AS
(
    SELECT z.ZgloszenieID, d.value AS Wym,
           c.Wart + 0.6 * o.Wart
         + 0.35 * (2 * dbo.fn_Los(CONCAT('E', z.ZgloszenieID, '-', d.value)) - 1) AS Wart
    FROM #Zgl AS z
    JOIN dbo.Temat AS t ON t.TematID = z.PrawdziwyTematID
    CROSS JOIN GENERATE_SERIES(1, 32) AS d
    JOIN #Skladowa AS c ON c.Typ = 'C' AND c.ID = t.KategoriaID AND c.Wym = d.value
    JOIN #Skladowa AS o ON o.Typ = 'O' AND o.ID = t.TematID     AND o.Wym = d.value
),
Json AS
(
    SELECT ZgloszenieID,
           CONCAT('[', STRING_AGG(CAST(CAST(Wart AS decimal(9,6)) AS varchar(12)), ',')
                       WITHIN GROUP (ORDER BY Wym), ']') AS Tablica
    FROM Skladowe
    GROUP BY ZgloszenieID
)
INSERT INTO dbo.Zgloszenie (ZgloszenieID, DataZgloszenia, Kanal, TematID, Tresc, Embedding)
SELECT z.ZgloszenieID,
       DATEADD(day, CAST(dbo.fn_Los(CONCAT('D', z.ZgloszenieID)) * 270 AS int), '20260102'),
       CASE WHEN dbo.fn_Los(CONCAT('K', z.ZgloszenieID)) < 0.5 THEN 'e-mail'
            WHEN dbo.fn_Los(CONCAT('K', z.ZgloszenieID)) < 0.8 THEN 'czat'
            ELSE 'telefon' END,
       -- Realistyczny problem: 12 zgłoszeń konsultanci przypisali do złego tematu
       CASE WHEN z.ZgloszenieID IN (37, 141, 222, 305, 388, 456, 529, 610, 777, 853, 964, 1101)
            THEN (z.PrawdziwyTematID - 1 + 9) % 24 + 1
            ELSE z.PrawdziwyTematID END,
       CONCAT(IIF(dbo.fn_Los(CONCAT('W', z.ZgloszenieID)) < 0.5, t.Fraza1, t.Fraza2),
              N' (zamówienie ZM-', 250000 + z.ZgloszenieID, N')'),
       VECTOR_NORMALIZE(CAST(j.Tablica AS vector(32)), 'norm2')
FROM #Zgl AS z
JOIN dbo.Temat AS t ON t.TematID = z.PrawdziwyTematID
JOIN Json      AS j ON j.ZgloszenieID = z.ZgloszenieID;
 
/* 5. Dzisiejsze nowe zgłoszenia – czekają na przypisanie i odpowiedź */
CREATE TABLE dbo.NoweZgloszenie
(
    NoweID    int           NOT NULL CONSTRAINT PK_NoweZgloszenie PRIMARY KEY,
    Kanal     varchar(10)   NOT NULL,
    Tresc     nvarchar(300) NOT NULL,
    Embedding vector(32)    NULL
);
 
INSERT INTO dbo.NoweZgloszenie (NoweID, Kanal, Tresc)
VALUES
 (1,  'e-mail',  N'Dzień dobry, od rana próbuję się zalogować, ale nie pamiętam hasła, a mail resetujący nie dochodzi.'),
 (2,  'czat',    N'Bank pokazuje dwie identyczne płatności kartą za moje wczorajsze zamówienie. Proszę o zwrot jednej.'),
 (3,  'telefon', N'Zamówienie miało przyjść w poniedziałek, jest czwartek i paczki dalej nie ma.'),
 (4,  'e-mail',  N'Zwrot odesłałam 20 dni temu, status: przyjęty, a pieniędzy brak.'),
 (5,  'e-mail',  N'Faktura ma zły NIP – proszę o korektę, bo księgowa jej nie przyjmie.'),
 (6,  'czat',    N'Aplikacja na Androidzie wyłącza się, gdy chcę zapłacić.'),
 (7,  'czat',    N'Kod LATO20 nie działa, a według regulaminu powinien.'),
 (8,  'telefon', N'Blender po miesiącu przestał się włączać, chcę go reklamować.'),
 (9,  'czat',    N'Paczkomat był pełny i nie wiem, gdzie teraz jest moja paczka.'),
 (10, 'e-mail',  N'Paczka przyszła zgnieciona, ekspres pęknięty. Odesłałem go 3 tygodnie temu i dalej nie mam ani zwrotu pieniędzy, ani nowego ekspresu.');
 
WITH Definicja AS
(
    -- Zgłoszenie 10 łączy dwa tematy (uszkodzenie + brak zwrotu pieniędzy)
    SELECT * FROM (VALUES (1, 1, 1.0, 1, 0.0),   (2, 5, 1.0, 5, 0.0),   (3, 7, 1.0, 7, 0.0),
                          (4, 11, 1.0, 11, 0.0), (5, 14, 1.0, 14, 0.0), (6, 16, 1.0, 16, 0.0),
                          (7, 20, 1.0, 20, 0.0), (8, 23, 1.0, 23, 0.0), (9, 9, 1.0, 9, 0.0),
                          (10, 22, 0.5, 11, 0.5)
                  ) AS v (NoweID, TematA, WagaA, TematB, WagaB)
),
Skladowe AS
(
    SELECT d.NoweID, g.value AS Wym,
           d.WagaA * (ca.Wart + 0.6 * oa.Wart) + d.WagaB * (cb.Wart + 0.6 * ob.Wart)
         + 0.35 * (2 * dbo.fn_Los(CONCAT('N', d.NoweID, '-', g.value)) - 1) AS Wart
    FROM Definicja AS d
    CROSS JOIN GENERATE_SERIES(1, 32) AS g
    JOIN dbo.Temat AS ta ON ta.TematID = d.TematA
    JOIN dbo.Temat AS tb ON tb.TematID = d.TematB
    JOIN #Skladowa AS ca ON ca.Typ = 'C' AND ca.ID = ta.KategoriaID AND ca.Wym = g.value
    JOIN #Skladowa AS oa ON oa.Typ = 'O' AND oa.ID = ta.TematID     AND oa.Wym = g.value
    JOIN #Skladowa AS cb ON cb.Typ = 'C' AND cb.ID = tb.KategoriaID AND cb.Wym = g.value
    JOIN #Skladowa AS ob ON ob.Typ = 'O' AND ob.ID = tb.TematID     AND ob.Wym = g.value
),
Json AS
(
    SELECT NoweID,
           CONCAT('[', STRING_AGG(CAST(CAST(Wart AS decimal(9,6)) AS varchar(12)), ',')
                       WITHIN GROUP (ORDER BY Wym), ']') AS Tablica
    FROM Skladowe
    GROUP BY NoweID
)
UPDATE n
SET Embedding = VECTOR_NORMALIZE(CAST(j.Tablica AS vector(32)), 'norm2')
FROM dbo.NoweZgloszenie AS n
JOIN Json AS j ON j.NoweID = n.NoweID;
 
/* 6. Klucz prowadzącego – oczekiwane tematy nowych zgłoszeń (używany w weryfikacji) */
CREATE TABLE dbo.KluczWeryfikacji
(
    NoweID            int NOT NULL PRIMARY KEY,
    OczekiwanyTematID tinyint NULL   -- NULL = zgłoszenie niejednoznaczne, powinno trafić do człowieka
);
INSERT INTO dbo.KluczWeryfikacji (NoweID, OczekiwanyTematID)
VALUES (1, 1), (2, 5), (3, 7), (4, 11), (5, 14), (6, 16), (7, 20), (8, 23), (9, 9), (10, NULL);
GO
 
PRINT N'Baza WektoryHelpdesk gotowa.';
