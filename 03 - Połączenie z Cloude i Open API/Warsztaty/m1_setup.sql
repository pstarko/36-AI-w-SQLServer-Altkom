/* ============================================================
   Moduł 1 – skrypt przygotowujący środowisko i dane (od zera)
   Wymagania: SQL Server 2025 (17.x), uprawnienia sysadmin
   (sp_configure). Dane opinii są fikcyjne.
   ============================================================ */
USE master;
GO
/* Włączenie wywołań REST z silnika (domyślnie wyłączone) */
EXEC sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE WITH OVERRIDE;
GO
IF DB_ID(N'AsystentOpinii') IS NOT NULL
BEGIN
    ALTER DATABASE AsystentOpinii SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE AsystentOpinii;
END;
GO
CREATE DATABASE AsystentOpinii;
GO
USE AsystentOpinii;
GO
/* Klucz główny bazy – szyfruje poświadczenia z kluczami API */
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Warsztat_LLM_2026!Haslo';
GO
 
/* 1. Konfiguracja dostawców modeli (aktywny jest dokładnie jeden) */
CREATE TABLE dbo.KonfiguracjaLLM
(
    Dostawca           varchar(10)    NOT NULL CONSTRAINT PK_KonfiguracjaLLM PRIMARY KEY,
    Url                nvarchar(400)  NOT NULL,
    Model              varchar(100)   NOT NULL,
    NazwaPoswiadczenia sysname        NOT NULL,
    Naglowki           nvarchar(1000) NULL,      -- dodatkowe nagłówki (płaski JSON), bez sekretów!
    CenaWejscieUSD     decimal(10,4)  NOT NULL,  -- cena za 1 mln tokenów wejściowych
    CenaWyjscieUSD     decimal(10,4)  NOT NULL,  -- cena za 1 mln tokenów wyjściowych
    CzyAktywny         bit            NOT NULL CONSTRAINT DF_KonfiguracjaLLM_CzyAktywny DEFAULT 0
);
CREATE UNIQUE INDEX UX_KonfiguracjaLLM_Aktywny ON dbo.KonfiguracjaLLM (CzyAktywny) WHERE CzyAktywny = 1;
 
INSERT INTO dbo.KonfiguracjaLLM (Dostawca, Url, Model, NazwaPoswiadczenia, Naglowki, CenaWejscieUSD, CenaWyjscieUSD, CzyAktywny)
VALUES ('Claude', N'https://api.anthropic.com/v1/messages', 'claude-haiku-5-5', N'https://api.anthropic.com',
        N'{"anthropic-version":"2026-10-21"}', 0.10, 0.50, 1),
       ('OpenAI', N'https://api.openai.com/v1/responses',   'gpt-6-luna',       N'https://api.openai.com',
        NULL, 0.10, 0.50, 0);
 
/* 2. Dziennik wszystkich wywołań modelu (audyt, koszty, diagnostyka) */
CREATE TABLE dbo.LogLLM
(
    LogID            int IDENTITY(1,1) NOT NULL CONSTRAINT PK_LogLLM PRIMARY KEY,
    CzasStart        datetime2(3)   NOT NULL,
    CzasMs           int            NOT NULL,
    Etap             varchar(30)    NOT NULL,
    Dostawca         varchar(10)    NOT NULL,
    Model            varchar(100)   NOT NULL,
    KodHTTP          int            NULL,
    TokenyWe         int            NULL,
    TokenyWy         int            NULL,
    KosztUSD         decimal(12,8)  NULL,
    PowodZakonczenia varchar(40)    NULL,
    Zapytanie        nvarchar(max)  NULL,   -- dokładnie to, co wysłaliśmy do dostawcy
    Odpowiedz        nvarchar(max)  NULL,   -- tekst odpowiedzi modelu
    OdpowiedzSurowa  nvarchar(max)  NULL,   -- pełny JSON z sp_invoke_external_rest_endpoint
    Blad             nvarchar(4000) NULL
);
 
/* 3. Hotele i opinie gości z portali rezerwacyjnych */
CREATE TABLE dbo.Hotel
(
    HotelID tinyint      NOT NULL CONSTRAINT PK_Hotel PRIMARY KEY,
    Nazwa   nvarchar(60) NOT NULL
);
INSERT INTO dbo.Hotel (HotelID, Nazwa)
VALUES (1, N'Hotel Bursztyn Gdańsk'), (2, N'Hotel Bursztyn Kraków'), (3, N'Hotel Bursztyn Zakopane');
 
CREATE TABLE dbo.Opinia
(
    OpiniaID   int           NOT NULL CONSTRAINT PK_Opinia PRIMARY KEY,
    HotelID    tinyint       NOT NULL CONSTRAINT FK_Opinia_Hotel REFERENCES dbo.Hotel (HotelID),
    Portal     varchar(20)   NOT NULL,
    DataOpinii date          NOT NULL,
    Ocena      tinyint       NOT NULL CONSTRAINT CK_Opinia_Ocena CHECK (Ocena BETWEEN 1 AND 5),
    Tresc      nvarchar(2000) NOT NULL
);
 
INSERT INTO dbo.Opinia (OpiniaID, HotelID, Portal, DataOpinii, Ocena, Tresc)
VALUES
 (1, 1, 'Booking',     '20260702', 5, N'Piękny widok na morze z pokoju, łóżko bardzo wygodne. Na pewno wrócimy!'),
 (2, 2, 'Google',      '20260703', 2, N'Pokój był brudny – włosy w łazience i kurz pod łóżkiem. Recepcja przeprosiła, ale nikt nie przyszedł posprzątać.'),
 (3, 3, 'TripAdvisor', '20260704', 4, N'Śniadania rewelacyjne, duży wybór regionalnych produktów. Jedynie kawa z ekspresu mogłaby być lepsza.'),
 (4, 2, 'Booking',     '20260705', 4, N'Great location right next to the Old Town. Staff spoke excellent English. Room was a bit small though.'),
 (5, 1, 'Google',      '20260706', 3, N'Obsługa bardzo miła i pomocna, ale przez imprezę weselną na dole nie dało się spać do 3 w nocy.'),
 (6, 3, 'Booking',     '20260707', 1, N'W pokoju 214 znaleźliśmy pluskwy! Mamy ugryzienia na rękach. Żądam kontaktu z kierownictwem.'),
 (7, 2, 'TripAdvisor', '20260708', 5, N'Recepcjonistka pomogła nam zarezerwować stolik i bilety do Wieliczki. Pełen profesjonalizm!'),
 (8, 1, 'Booking',     '20260709', 2, N'Wi-Fi praktycznie nie działało, a przyjechałem służbowo i musiałem pracować z kawiarni obok.'),
 (9, 3, 'Google',      '20260710', 4, N'Cisza, spokój, piękne widoki na Giewont. Do centrum Zakopanego kilka minut spacerem.'),
 (10, 2, 'Booking',    '20260711', 2, N'Za 650 zł za noc oczekiwałem dużo więcej. Pokój standardowy, nic specjalnego.'),
 (11, 1, 'TripAdvisor','20260712', 5, N'Spa i basen na najwyższym poziomie. Polecam pakiet weekendowy z masażem.'),
 (12, 3, 'Booking',    '20260713', 2, N'Śniadanie podawane do 9:30, a o 9:15 połowy rzeczy już nie było i nikt nie uzupełniał.'),
 (13, 2, 'Google',     '20260714', 3, N'Hotel w porządku. Nic szczególnego, nic złego.'),
 (14, 1, 'Booking',    '20260715', 1, N'Ktoś zabrał mój laptop z pokoju podczas sprzątania. Sprawa zgłoszona na policję, hotel nie reaguje. Kontakt: marek.nowak@example.com, tel. 601 234 567.'),
 (15, 3, 'TripAdvisor','20260716', 5, N'Najlepsze pierogi, jakie jadłem! Restauracja hotelowa zasługuje na osobne wyróżnienie.'),
 (16, 2, 'Booking',    '20260717', 2, N'Tramwaje pod oknem od 5 rano, okna nieszczelne. Nie wyspałam się ani jednej nocy.'),
 (17, 1, 'Google',     '20260718', 4, N'Bardzo dobra lokalizacja, blisko plaży. Pokoje odnowione, choć klimatyzacja głośna.'),
 (18, 3, 'Booking',    '20260719', 3, N'Pokój czysty i ciepły, ale łazienka wymaga remontu – odpadające kafelki i grzyb przy prysznicu.'),
 (19, 2, 'TripAdvisor','20260720', 5, N'Świetny stosunek ceny do jakości, w tej lokalizacji to prawdziwa okazja.'),
 (20, 1, 'Booking',    '20260721', 2, N'Parking hotelowy płatny 90 zł za dobę i i tak zabrakło miejsc. Musieliśmy stać na ulicy.'),
 (21, 3, 'Google',     '20260722', 1, N'Recepcja nieuprzejma, przy zameldowaniu kazano nam czekać 40 minut bez słowa wyjaśnienia.'),
 (22, 2, 'Booking',    '20260723', 4, N'Fajny hotel na city break. Śniadania dobre, pokój mały, ale funkcjonalny.'),
 (23, 1, 'TripAdvisor','20260724', 5, N'Personel przygotował dla nas niespodziankę na rocznicę ślubu – szampan i kwiaty w pokoju. Dziękujemy!'),
 (24, 3, 'Booking',    '20260725', 2, N'Internet działał tylko w lobby, w pokojach zero zasięgu. W 2026 roku to nie do przyjęcia.'),
 (25, 2, 'Google',     '20260726', 3, N'Śniadanie smaczne, ale drogie jak na to, co oferuje – 85 zł od osoby.'),
 (26, 1, 'Booking',    '20260727', 1, N'Woda w kranie miała brązowy kolor, a po prysznicu dostałam wysypki. Proszę o pilny kontakt: 512-345-678.'),
 (27, 3, 'TripAdvisor','20260728', 5, N'Sauna z widokiem na góry – bajka! Obsługa strefy wellness bardzo kompetentna.'),
 (28, 2, 'Booking',    '20260729', 4, N'Hotel w samym centrum, wszędzie blisko pieszo.'),
 (29, 1, 'Google',     '20260730', 2, N'Pokój pachniał papierosami mimo zakazu palenia. Prosiłem o zmianę, ale nie było wolnych pokoi.'),
 (30, 3, 'Booking',    '20260731', 4, N'The breakfast was amazing and the mountain view from our balcony was breathtaking.'),
 (31, 2, 'Booking',    '20260801', 1, N'Rezerwacja przepadła, choć miałem potwierdzenie mailowe. Przyjechałem o 23 i nie było dla mnie pokoju. Mój mail: tomasz.zielinski@example.com'),
 (32, 1, 'TripAdvisor','20260802', 5, N'Czystość na medal, pokój sprzątany codziennie, ręczniki zawsze świeże.'),
 (33, 3, 'Google',     '20260803', 3, N'Lokalizacja trochę na uboczu, bez samochodu ciężko się dostać. Sam hotel w porządku.'),
 (34, 2, 'Booking',    '20260804', 2, N'Klimatyzacja w pokoju nie działała w czasie upału, w nocy było 29 stopni.'),
 (35, 1, 'Google',     '20260805', 4, N'Dobra restauracja, polecam rybę dnia. Kelnerzy mogliby być szybsi.'),
 (36, 3, 'Booking',    '20260806', 1, N'Za ścianą przez całą noc głośna impreza, recepcja nie zareagowała na trzy telefony.'),
 (37, 2, 'TripAdvisor','20260807', 5, N'Bardzo wygodne łóżka i świetne zasłony zaciemniające – wyspałem się jak nigdy.'),
 (38, 1, 'Booking',    '20260808', 3, N'Cena wysoka, ale w sezonie wszędzie tak jest. Standard odpowiedni.'),
 (39, 3, 'Google',     '20260809', 2, N'Basen zamknięty przez cały pobyt bez wcześniejszej informacji, a był głównym powodem rezerwacji.'),
 (40, 2, 'Booking',    '20260810', 4, N'ok');
 
/* 4. Klucz prowadzącego: oczekiwane wyniki dla opinii jednoznacznych (NULL = nie oceniamy) */
CREATE TABLE dbo.KluczOpinii
(
    OpiniaID            int         NOT NULL PRIMARY KEY,
    OczekiwanySentyment varchar(12) NULL,
    OczekiwanaKategoria varchar(15) NULL
);
INSERT INTO dbo.KluczOpinii (OpiniaID, OczekiwanySentyment, OczekiwanaKategoria)
VALUES (1,'pozytywny','pokoj'), (2,'negatywny','czystosc'), (3,'pozytywny','jedzenie'), (4,'pozytywny','lokalizacja'),
       (5,'mieszany','halas'), (6,'negatywny','czystosc'), (7,'pozytywny','obsluga'), (8,'negatywny','internet'),
       (9,'pozytywny','lokalizacja'), (10,'negatywny','cena'), (11,'pozytywny','udogodnienia'), (12,'negatywny','jedzenie'),
       (13,'neutralny',NULL), (14,'negatywny',NULL), (15,'pozytywny','jedzenie'), (16,'negatywny','halas'),
       (17,NULL,NULL), (18,NULL,NULL), (19,'pozytywny','cena'), (20,'negatywny',NULL),
       (21,'negatywny','obsluga'), (22,'pozytywny',NULL), (23,'pozytywny','obsluga'), (24,'negatywny','internet'),
       (25,NULL,NULL), (26,'negatywny',NULL), (27,'pozytywny','udogodnienia'), (28,'pozytywny','lokalizacja'),
       (29,'negatywny',NULL), (30,'pozytywny',NULL), (31,'negatywny','obsluga'), (32,'pozytywny','czystosc'),
       (33,NULL,'lokalizacja'), (34,'negatywny','pokoj'), (35,NULL,'jedzenie'), (36,'negatywny','halas'),
       (37,'pozytywny','pokoj'), (38,NULL,'cena'), (39,'negatywny','udogodnienia'), (40,NULL,NULL);
GO
 
/* 5. "Hak" na ochronę prywatności – na razie nic nie robi, uzupełnimy go w Module 4 */
CREATE OR ALTER FUNCTION dbo.fn_FiltrPrywatnosci (@Tekst nvarchar(max))
RETURNS nvarchar(max)
AS
BEGIN
    RETURN @Tekst;
END;
GO
PRINT N'Baza AsystentOpinii gotowa. Teraz utwórz poświadczenie z kluczem API (ćwiczenie 1.2).';
