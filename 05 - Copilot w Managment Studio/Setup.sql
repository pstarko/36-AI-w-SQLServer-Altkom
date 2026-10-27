
DROP TABLE IF EXISTS AllData 
GO

	SELECT 
		p.BusinessEntityID ID,
		p.PersonType,
		p.Title,
		p.FirstName,
		p.LastName,
		p.EmailPromotion,
		p.rowguid,
		p.ModifiedDate,
		em.EmailAddress,
		bea.AddressTypeID,
		atype.Name AddressType,
		a.AddressLine1,
		a.AddressLine2,
		a.City,
		a.PostalCode,
		sp.Name RegionName,
		c.Name Country,
		emp.BirthDate,
		emp.Gender,
		emp.MaritalStatus,
		ROW_NUMBER() OVER(PARTITION BY be.BusinessEntityID ORDER BY be.BusinessEntityID) RN
	INTO AllData
	FROM Person.Person p
	JOIN Person.BusinessEntity be ON be.BusinessEntityID = p.BusinessEntityID
	JOIN Person.BusinessEntityAddress bea ON bea.BusinessEntityID = be.BusinessEntityID
	JOIN Person.AddressType atype ON atype.AddressTypeID = bea.AddressTypeID
	JOIN Person.Address a ON a.AddressID = bea.AddressID
	JOIN Person.StateProvince sp ON sp.StateProvinceID = a.StateProvinceID
	JOIN Person.CountryRegion c ON c.CountryRegionCode = sp.CountryRegionCode
	JOIN Person.EmailAddress em ON em.BusinessEntityID = be.BusinessEntityID 
	LEFT JOIN HumanResources.Employee emp ON emp.BusinessEntityID = be.BusinessEntityID
	WHERE 1 = 2
GO

ALTER TABLE AllData DROP COLUMN Rn
GO

DROP SEQUENCE IF EXISTS dbo.AllDataID 
GO

CREATE SEQUENCE dbo.AllDataID 
 AS [int]
 START WITH 1
 INCREMENT BY 1
GO


ALTER TABLE AllData ADD CONSTRAINT DF_AllData_ID DEFAULT (NEXT VALUE FOR AllDataID) FOR ID
GO


DROP FUNCTION IF EXISTS udf_AllData
GO

CREATE FUNCTION udf_AllData (@Loop int)
RETURNS TABLE AS
RETURN 

WITH AllDataCTE AS (

	SELECT 
		p.PersonType,
		p.Title,
		IIF(@Loop = 0, p.FirstName, p.FirstName + CAST(@Loop AS varchar(3))) AS FirstName,
		IIF(@Loop = 0, p.LastName, p.LastName + CAST(@Loop AS varchar(3))) AS LastName,
		p.EmailPromotion,
		p.rowguid,
		p.ModifiedDate,
		em.EmailAddress,
		bea.AddressTypeID,
		atype.Name AddressType,
		a.AddressLine1,
		a.AddressLine2,
		a.City,
		a.PostalCode,
		sp.Name RegionName,
		c.Name Country,
		emp.BirthDate,
		emp.Gender,
		emp.MaritalStatus,
		ROW_NUMBER() OVER(PARTITION BY be.BusinessEntityID ORDER BY be.BusinessEntityID) AS RN
	FROM Person.Person AS p
	JOIN Person.BusinessEntity AS be ON be.BusinessEntityID = p.BusinessEntityID
	JOIN Person.BusinessEntityAddress AS bea ON bea.BusinessEntityID = be.BusinessEntityID
	JOIN Person.AddressType AS atype ON atype.AddressTypeID = bea.AddressTypeID
	JOIN Person.Address AS a ON a.AddressID = bea.AddressID
	JOIN Person.StateProvince AS sp ON sp.StateProvinceID = a.StateProvinceID
	JOIN Person.CountryRegion AS c ON c.CountryRegionCode = sp.CountryRegionCode
	JOIN Person.EmailAddress AS em ON em.BusinessEntityID = be.BusinessEntityID 
	LEFT JOIN HumanResources.Employee AS emp ON emp.BusinessEntityID = be.BusinessEntityID
) 
SELECT * 
FROM AllDataCTE
WHERE Rn = 1
GO

DECLARE @i int = 0

WHILE @i < 1
BEGIN

	INSERT INTO AllData
		(PersonType, Title, FirstName, LastName, EmailPromotion, rowguid, ModifiedDate, EmailAddress, 
		AddressTypeID, AddressType, AddressLine1, AddressLine2, City, PostalCode, RegionName, Country, BirthDate,
		Gender, MaritalStatus)
	SELECT 
		PersonType, Title, FirstName, LastName, EmailPromotion, rowguid, ModifiedDate, EmailAddress, 
		AddressTypeID, AddressType, AddressLine1, AddressLine2, City, PostalCode, RegionName, Country, BirthDate,
		Gender, MaritalStatus 
	FROM udf_AllData(@i)	

	SET @i = @i + 1

END




