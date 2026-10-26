/* Ćwiczenie 1.2 – typ VECTOR w pigułce (przykład 3-wymiarowy)
   Wymiary umowne: [płatności, dostawa, konto] */
USE WektoryHelpdesk;
GO
DECLARE @a vector(3) = '[1, 0, 0]';        -- zgłoszenie czysto "płatnicze"
DECLARE @b vector(3) = '[0.8, 0.6, 0]';    -- płatność + trochę dostawy
DECLARE @c vector(3) = '[0, 0, 2]';        -- sprawa konta, "dłuższy" wektor
 
/* a) konwersje: tekst/JSON <-> vector oraz właściwości */
SELECT CAST(@b AS nvarchar(max))             AS JakoTekst,
       VECTORPROPERTY(@b, 'Dimensions')      AS Wymiary,
       VECTORPROPERTY(@b, 'BaseType')        AS TypElementu,
       DATALENGTH(@b)                        AS RozmiarBajty;
 
/* b) trzy metryki odległości */
SELECT N'a vs b' AS Para,
       VECTOR_DISTANCE('cosine',    @a, @b) AS Cosine,
       VECTOR_DISTANCE('euclidean', @a, @b) AS Euclidean,
       VECTOR_DISTANCE('dot',       @a, @b) AS Dot
UNION ALL
SELECT N'a vs c',
       VECTOR_DISTANCE('cosine',    @a, @c),
       VECTOR_DISTANCE('euclidean', @a, @c),
       VECTOR_DISTANCE('dot',       @a, @c);
 
/* c) długość (norma) i normalizacja */
SELECT VECTOR_NORM(@c, 'norm2')                                AS DlugoscC,
       CAST(VECTOR_NORMALIZE(@c, 'norm2') AS nvarchar(max))     AS C_Znormalizowany,
       VECTOR_NORM(VECTOR_NORMALIZE(@c, 'norm2'), 'norm2')      AS DlugoscPoNormalizacji;
GO
 
/* d) Spójrz na prawdziwe dane: 32-wymiarowe embeddingi zgłoszeń */
SELECT TOP (3) z.ZgloszenieID, t.Tytul, z.Tresc,
       VECTORPROPERTY(z.Embedding, 'Dimensions') AS Wymiary,
       LEFT(CAST(z.Embedding AS nvarchar(max)), 60) + N'...' AS PoczatekWektora
FROM dbo.Zgloszenie AS z
JOIN dbo.Temat AS t ON t.TematID = z.TematID
ORDER BY z.ZgloszenieID;
GO
 
/* e) Czego NIE wolno: odkomentuj po kolei i przeczytaj komunikaty błędów */
-- SELECT * FROM dbo.Zgloszenie WHERE Embedding = Embedding;          -- brak operatora porównania
-- SELECT TOP (1) * FROM dbo.Zgloszenie ORDER BY Embedding;           -- vector nie jest sortowalny
-- DECLARE @zly vector(3) = '[1, 2]';                                  -- zła liczba wymiarów
