USE AdventureWorks2012;
GO

/*
a) добавьте в таблицу dbo.PersonPhone поле City типа nvarchar(30);
*/
ALTER TABLE dbo.PersonPhone
	ADD City NVARCHAR(30);
GO

/*
b) объявите табличную переменную с такой же структурой как dbo.PersonPhone и заполните ее данными из dbo.PersonPhone. 
Поле City заполните значениями из таблицы Person.Address поля City, а поле PostalCode 
значениями из Person.Address поля PostalCode. Если поле PostalCode содержит буквы — заполните поле значением по умолчанию;
*/
DECLARE @PersonPhoneTableVar TABLE (
	BusinessEntityId INT NOT NULL,
	PhoneNumber NVARCHAR(25) NOT NULL,
	PhoneNumberTypeId BIGINT,
	ModifiedDate DATETIME NOT NULL,
	PostalCode NVARCHAR(15),
	City NVARCHAR(30)
);

-- Заполнение созданной табличной переменной данными из dbo.PersonPhone
INSERT INTO @PersonPhoneTableVar(
	BusinessEntityId,
	PhoneNumber,
	PhoneNumberTypeId,
	ModifiedDate,
	PostalCode,
	City
)
SELECT 
	PersonPhone.BusinessEntityID,
	PersonPhone.PhoneNumber,
	PersonPhone.PhoneNumberTypeID,
	PersonPhone.ModifiedDate,
	CASE
		WHEN Address.PostalCode LIKE '[A-Za-z]%' THEN '0'
		ELSE Address.PostalCode
	END,
	Address.City
FROM dbo.PersonPhone AS PersonPhone
INNER JOIN Person.BusinessEntityAddress 
ON PersonPhone.BusinessEntityID = Person.BusinessEntityAddress.BusinessEntityID
INNER JOIN Person.Address AS Address
ON Address.AddressID = Person.BusinessEntityAddress.AddressID;

/*
c) обновите данные в полях PostalCode и City в dbo.PersonPhone данными из табличной переменной. 
Также обновите данные в поле PhoneNumber. Добавьте код ‘1 (11)’ для тех телефонов, для которых этот код не указан;
*/

UPDATE dbo.PersonPhone
	SET 
		dbo.PersonPhone.PostalCode = PersonPhoneTableVar.PostalCode,
		dbo.PersonPhone.City = PersonPhoneTableVar.City,
		dbo.PersonPhone.PhoneNumber = 
		CASE 
			WHEN PATINDEX('%1 (11)%', dbo.PersonPhone.PhoneNumber) = 0 THEN
			'1 (11)' + dbo.PersonPhone.PhoneNumber 
			ELSE
			dbo.PersonPhone.PhoneNumber
		END
FROM dbo.PersonPhone 
INNER JOIN @PersonPhoneTableVar AS PersonPhoneTableVar
ON dbo.PersonPhone.BusinessEntityID = PersonPhoneTableVar.BusinessEntityID;
GO

SELECT * FROM dbo.PersonPhone;

/*
d) удалите данные из dbo.PersonPhone для сотрудников компании, то есть где PersonType в Person.Person равен ‘EM’;
*/
SELECT * from Person.Person;
SELECT * from dbo.PersonPhone;

DELETE FROM dbo.PersonPhone
WHERE EXISTS(
	SELECT BusinessEntityID, PersonType 
	FROM Person.Person
	WHERE Person.BusinessEntityID = dbo.PersonPhone.BusinessEntityID
	AND Person.PersonType = 'EM'
);
GO

SELECT * FROM dbo.PersonPhone;
GO

/*
e) удалите полe City из таблицы, удалите все созданные ограничения и значения по умолчанию.
*/
ALTER TABLE dbo.PersonPhone
DROP COLUMN City;
GO

-- Поиск имён ограничений в метаданных.
SELECT *
FROM AdventureWorks2012.INFORMATION_SCHEMA.CONSTRAINT_TABLE_USAGE
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'PersonPhone';
GO

-- Поиск значений по умолчанию в метаданных.
SELECT *
FROM AdventureWorks2012.INFORMATION_SCHEMA.CHECK_CONSTRAINTS;
GO

ALTER TABLE dbo.PersonPhone
DROP CONSTRAINT CHK_PostalCode;
GO

ALTER TABLE dbo.PersonPhone
DROP CONSTRAINT DF_PersonPhone_PostalCode;
GO

/*
f) удалите таблицу dbo.PersonPhone.
*/
DROP TABLE dbo.PersonPhone;
GO

USE AdventureWorks2012;
GO

/*
a) Добавьте в таблицу dbo.PersonPhone поля OrdersCount INT и CardType NVARCHAR(50). 
Также создайте в таблице вычисляемое поле IsSuperior, которое будет хранить 1, если тип карты ‘SuperiorCard’ и 0 для остальных карт.
*/
ALTER TABLE dbo.PersonPhone
	ADD 
		[OrdersCount] INT, 
		[CardType] NVARCHAR(50),
		[IsSuperior] AS 
		CASE
			WHEN [CardType] = 'SuperiorCard' THEN 1
			ELSE 0
		END;
GO

/*
b) создайте временную таблицу #PersonPhone, с первичным ключом по полю BusinessEntityID. 
Временная таблица должна включать все поля таблицы dbo.PersonPhone за исключением поля IsSuperior.
*/
DROP TABLE #PersonPhone
GO
CREATE TABLE #PersonPhone(
	[BusinessEntityId] INT NOT NULL,
	[PhoneNumber] NVARCHAR(25) NOT NULL,
	[PhoneNumberTypeId] BIGINT,
	[ModifiedDate] DATETIME NOT NULL,
	[PostalCode] NVARCHAR(15),
	[OrdersCount] INT,
	[CardType] NVARCHAR(50)
);
GO

ALTER TABLE #PersonPhone
	ADD CONSTRAINT PK_PersonPhones_BusinessEntityID 
	PRIMARY KEY ([BusinessEntityID]);
GO

/*
c) Заполните временную таблицу данными из dbo.PersonPhone. Поле CardType заполните данными из таблицы Sales.CreditCard. 
Посчитайте количество заказов, оплаченных каждой картой (CreditCardID) в таблице Sales.SalesOrderHeader и заполните этими значениями поле OrdersCount. 
Подсчет количества заказов осуществите в Common Table Expression (CTE).
*/

-- Определение Common Table Expression (CTE) для подсчета количества заказов
WITH SalesCount_CTE([CreditCardID], [OrdersCount]) AS
(
	SELECT SalesOrderHeader.[CreditCardID], COUNT(SalesOrderHeader.[CreditCardID]) AS OrdersCount
	FROM Sales.SalesOrderHeader AS SalesOrderHeader
	GROUP BY SalesOrderHeader.[CreditCardID]
)

INSERT INTO #PersonPhone(
	[BusinessEntityID],
	[PhoneNumber],
	[PhoneNumberTypeID],
	[ModifiedDate],
	[PostalCode],
	[OrdersCount],
	[CardType]
)
SELECT 
	PersonPhone.[BusinessEntityID],
	PersonPhone.[PhoneNumber],
	PersonPhone.[PhoneNumberTypeID],
	PersonPhone.[ModifiedDate],
	PersonPhone.[PostalCode],
	SalesCount_CTE.[OrdersCount],
	Sales.CreditCard.[CardType]
FROM dbo.PersonPhone AS PersonPhone
LEFT JOIN Sales.PersonCreditCard
	ON PersonPhone.[BusinessEntityID] = Sales.PersonCreditCard.[BusinessEntityID]
LEFT JOIN Sales.CreditCard
	ON Sales.PersonCreditCard.[CreditCardID] = Sales.CreditCard.[CreditCardID]
LEFT JOIN SalesCount_CTE
	ON Sales.CreditCard.[CreditCardID] = SalesCount_CTE.[CreditCardID];
GO

-- Выборка данных из временной таблицы для проверки корректности записи данных в нее
SELECT * FROM #PersonPhone;
GO

-- Проверка корректности выборки данных из таблицы dbo.PersonPhone
SELECT * FROM dbo.PersonPhone 
	WHERE [BusinessEntityID] = 3730;
GO

-- Вывод строки бд, в которой есть соотвествие BusinessEntityID на CreditCardID
SELECT * FROM Sales.PersonCreditCard
	WHERE [BusinessEntityID] = 3730;
GO

-- Все заказы, оплаченные картой с CreditCardID = 3092
SELECT * FROM Sales.SalesOrderHeader
	WHERE [CreditCardID] = 3092;
GO

-- Данные о карте по её идентификатору
SELECT * FROM Sales.CreditCard
WHERE [CreditCardID] = 3092;
GO

/*
d) удалите из таблицы dbo.PersonPhone одну строку (где BusinessEntityID = 297)
*/
DELETE FROM dbo.PersonPhone
	WHERE [BusinessEntityID] = 297;
GO

/*
e) напишите Merge выражение, использующее dbo.PersonPhone как target, а временную таблицу как source. 
Для связи target и source используйте BusinessEntityID. Обновите поля OrdersCount и CardType, если запись присутствует в source и target. 
Если строка присутствует во временной таблице, но не существует в target, добавьте строку в dbo.PersonPhone. 
Если в dbo.PersonPhone присутствует такая строка, которой не существует во временной таблице, удалите строку из dbo.PersonPhone.
*/
INSERT INTO dbo.PersonPhone(
	[BusinessEntityID],
	[PhoneNumber],
	[ModifiedDate],
	[PostalCode]
)
VALUES (
	99999999,
	'111-111-111',
	CURRENT_TIMESTAMP,
	'220034'
);
GO

-- Проверка вставки
SELECT * FROM dbo.PersonPhone
	WHERE [BusinessEntityID] = 99999999;
GO


-- Merge выражение
MERGE INTO dbo.PersonPhone AS [target]
USING #PersonPhone AS [source]
ON [target].[BusinessEntityID] = [source].[BusinessEntityID]
WHEN MATCHED THEN
    UPDATE
    SET [OrdersCount] = [source].[OrdersCount],
        [CardType]    = [source].[CardType]
WHEN NOT MATCHED BY TARGET THEN
    INSERT (
		[BusinessEntityID],
		[PhoneNumber],
		[PhoneNumberTypeID],
		[ModifiedDate],
		[PostalCode],
		[OrdersCount],
		[CardType]
	)
    VALUES (	
		[source].[BusinessEntityID],
		[source].[PhoneNumber],
		[source].[PhoneNumberTypeID],
		[source].[ModifiedDate],
		[source].[PostalCode],
		[source].[OrdersCount],
		[source].[CardType]
	)
WHEN NOT MATCHED BY SOURCE THEN DELETE;
GO

-- Проверка того, что после merge операции в таблице dbo.PersonPhone вновь появилась запись с BusinessEntityId = 297 
-- и запись с BusinessEntityId = 99999999 удалена
SELECT * FROM  dbo.PersonPhone
	WHERE [BusinessEntityID] = 297 OR [BusinessEntityID] = 99999999;
GO