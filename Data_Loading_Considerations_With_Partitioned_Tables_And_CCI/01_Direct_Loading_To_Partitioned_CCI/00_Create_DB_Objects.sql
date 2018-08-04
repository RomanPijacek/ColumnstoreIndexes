-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Set context to the AdventureWorks2017 DB
-------------------------------------------------------------------------------------------------------------------------------------------------------

USE AdventureWorks2017;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Create an empty SRC table
-------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS Production.TransactionHistory_SRC;
GO

CREATE TABLE Production.TransactionHistory_SRC
(
	TransactionID INT NOT NULL IDENTITY(1, 1),
	ProductID INT NOT NULL,
	ReferenceOrderID INT NOT NULL,
	ReferenceOrderLineID INT NOT NULL,
	TransactionDate DATETIME NOT NULL,
	TransactionType NCHAR(1) NOT NULL,
	Quantity INT NOT NULL,
	ActualCost MONEY NOT NULL,
	ModifiedDate DATETIME NOT NULL
	CONSTRAINT [PK_TranHist_TranID] PRIMARY KEY CLUSTERED 
	(
		TransactionID ASC
	) WITH 
	(
		PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, 
		IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
	) ON [PRIMARY]
) ON [PRIMARY];
GO

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Populate the SRC table - 16M records
-------------------------------------------------------------------------------------------------------------------------------------------------------

INSERT INTO Production.TransactionHistory_SRC WITH (TABLOCKX)
(
	ProductID,
	ReferenceOrderID,
	ReferenceOrderLineID,
	TransactionDate,
	TransactionType,
	Quantity,
	ActualCost,
	ModifiedDate
)
SELECT TOP (100000)
	ProductID,
	ReferenceOrderID,
	ReferenceOrderLineID,
	TransactionDate,
	TransactionType,
	Quantity,
	ActualCost,
	ModifiedDate
FROM
	Production.TransactionHistory;
GO 160

SELECT COUNT(1) AS NrOfRecords FROM Production.TransactionHistory_SRC WITH(NOLOCK);
-- 16 000 000 

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Create Partition Function and Partition Schema
-------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PARTITION FUNCTION pf_TranID(INT) AS 
RANGE LEFT FOR VALUES (0, 4000000, 8000000, 12000000, 16000000, 20000000);
GO

CREATE PARTITION SCHEME ps_TranID AS PARTITION pf_TranID ALL TO ([PRIMARY]);
GO

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Create the partitioned destination table with CCI
-------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS Production.TransactionHistory_Part_DST;
GO

CREATE TABLE Production.TransactionHistory_Part_DST
(
	TransactionID INT NOT NULL,
	ProductID INT NOT NULL,
	ReferenceOrderID INT NOT NULL,
	ReferenceOrderLineID INT NOT NULL,
	TransactionDate DATETIME NOT NULL,
	TransactionType NCHAR(1) NOT NULL,
	Quantity INT NOT NULL,
	ActualCost MONEY NOT NULL,
	ModifiedDate DATETIME NOT NULL
) ON ps_TranID(TransactionID);
GO

CREATE CLUSTERED COLUMNSTORE INDEX CCI_TransHistPartDST ON Production.TransactionHistory_Part_DST ON ps_TranID(TransactionID); 
GO

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------------------------------------------------------------------------------
