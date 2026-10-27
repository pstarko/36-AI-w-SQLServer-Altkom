/*
	Zadanie 

    Porównaj liczbę odczytanych stron

	Utwórz 1 indeks klastrowy i 2 nieklastrowe i zmniejsz maksymalnie liczbę odczytywanych stron

*/

SELECT * INTO Orders FROM Sales.SalesOrderHeader



SET STATISTICS IO ON

-- liczba odczytów
-- przed: 
-- po: 
SELECT SalesOrderID, OrderDate, Status, CustomerID, TotalDue
FROM Orders
ORDER BY OrderDate DESC
OFFSET 0 ROWS FETCH NEXT 100 ROWS ONLY

-- liczba odczytów
-- przed: 
-- po:
SELECT SalesOrderID, OrderDate, Status, CustomerID, TotalDue
FROM Orders
ORDER BY OrderDate DESC
OFFSET 300 ROWS FETCH NEXT 100 ROWS ONLY

-- liczba odczytów
-- przed: 
-- po:
SELECT SalesOrderID, OrderDate, Status, CustomerID, TotalDue
FROM Orders
WHERE OrderDate BETWEEN '20130101' AND '20130120'
ORDER BY OrderDate DESC

-- liczba odczytów
-- przed: 
-- po:
SELECT SalesOrderID, OrderDate, Status, CustomerID, TotalDue
FROM Orders WHERE SalesOrderID = 75086

-- liczba odczytów
-- przed: 
-- po:
SELECT SalesOrderID, OrderDate, Status, CustomerID, TotalDue
FROM Orders WHERE CustomerID = 11619

