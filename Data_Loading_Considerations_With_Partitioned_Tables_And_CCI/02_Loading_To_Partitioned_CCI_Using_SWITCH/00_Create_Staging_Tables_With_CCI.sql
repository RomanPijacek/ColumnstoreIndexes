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
-- Create a new schema stg if it doesn't exist
-------------------------------------------------------------------------------------------------------------------------------------------------------

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stg' )
BEGIN
    EXEC('CREATE SCHEMA [stg] AUTHORIZATION [dbo]');
END
GO

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Create Staging Tables - 4 staging tables (4M records each)
-------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS stg.TranHist_Partition_1;
GO

CREATE TABLE stg.TranHist_Partition_1
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
) ON [PRIMARY];
GO

DROP TABLE IF EXISTS stg.TranHist_Partition_2;
GO

CREATE TABLE stg.TranHist_Partition_2
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
) ON [PRIMARY];
GO

DROP TABLE IF EXISTS stg.TranHist_Partition_3;
GO

CREATE TABLE stg.TranHist_Partition_3
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
) ON [PRIMARY];
GO

DROP TABLE IF EXISTS stg.TranHist_Partition_4;
GO

CREATE TABLE stg.TranHist_Partition_4
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
) ON [PRIMARY];
GO

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Create Clustered Columnstore Index on each staging table so its aligned with the DST table
-------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE CLUSTERED COLUMNSTORE INDEX CCI_TranHist_Partition_1 ON stg.TranHist_Partition_1 ON [PRIMARY]; 
CREATE CLUSTERED COLUMNSTORE INDEX CCI_TranHist_Partition_2 ON stg.TranHist_Partition_2 ON [PRIMARY]; 
CREATE CLUSTERED COLUMNSTORE INDEX CCI_TranHist_Partition_3 ON stg.TranHist_Partition_3 ON [PRIMARY]; 
CREATE CLUSTERED COLUMNSTORE INDEX CCI_TranHist_Partition_4 ON stg.TranHist_Partition_4 ON [PRIMARY]; 
GO

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------------------------------------------------------------------------------
