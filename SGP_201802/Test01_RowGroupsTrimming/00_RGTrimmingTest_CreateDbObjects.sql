--------------------------------------------------------------------------------------------------------------------------------
--  Author:          Roman Pijacek
--  Created Date:    2018-07-22
--  Description:     This script is a part of the Columnstore RG Trimming tests.
--                   The script creates the source and destination DB tables 
--  Source:          https://goo.gl/bkKWc2
--------------------------------------------------------------------------------------------------------------------------------

USE AdventureWorks2017;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

--------------------------------------------------------------------------------------------------------------------------------
-- Create and populate the source table -- 11 MM records
--------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS Production.TransactionHistory_SRC;
GO

CREATE TABLE Production.TransactionHistory_SRC
(
    TransactionID INT IDENTITY(-2147483648, 1) NOT NULL PRIMARY KEY CLUSTERED,
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

INSERT INTO Production.TransactionHistory_SRC WITH(TABLOCKX)
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
    Production.TransactionHistory WITH(NOLOCK);
GO 110

SELECT COUNT(1) FROM Production.TransactionHistory_SRC WITH(NOLOCK);
-- 11 000 000

--------------------------------------------------------------------------------------------------------------------------------
-- Create a destination table for the 1st Test Case Scenario
--------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS Production.TransactionHistory_DST;
GO

CREATE TABLE Production.TransactionHistory_DST
(
    TransactionID INT NOT NULL,
    ProductID INT NOT NULL,
    ReferenceOrderID INT NOT NULL,
    ReferenceOrderLineID INT NOT NULL,
    TransactionDate DATETIME NOT NULL,
    TransactionType NCHAR(1) NOT NULL,
    Quantity INT NOT NULL,
    ActualCost MONEY NOT NULL,
    ModifiedDate DATETIME NOT NULL,
    TransactionDescr NVARCHAR(4000) NOT NULL DEFAULT ''
) ON [PRIMARY];
GO

CREATE CLUSTERED COLUMNSTORE INDEX CCI_TransactionHistory_DST ON Production.TransactionHistory_DST;
GO

--------------------------------------------------------------------------------------------------------------------------------
-- EOF
--------------------------------------------------------------------------------------------------------------------------------
