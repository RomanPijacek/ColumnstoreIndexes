--------------------------------------------------------------------------------------------------------------------------------
--  Author:          Roman Pijacek
--  Created Date:    2018-07-04
--  Description:     This script is a part of the Columnstore MERGE policy testing.
--                   The script creates the source DB tables, Extended Event session 
--  Source:          https://goo.gl/3xMbr7
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
-- Create an Extended Event Session to track the MERGE process
--------------------------------------------------------------------------------------------------------------------------------

IF EXISTS(SELECT 1 FROM sys.server_event_sessions WHERE name = 'Tuple_Mover_Xe')
BEGIN  
    DROP EVENT session Tuple_Mover_Xe ON SERVER;  
END
GO

CREATE EVENT SESSION Tuple_Mover_Xe
ON SERVER 
    ADD EVENT sqlserver.columnstore_rowgroup_merge_start,
    ADD EVENT sqlserver.columnstore_rowgroup_compressed,
    ADD EVENT sqlserver.columnstore_rowgroup_merge_complete,
    ADD EVENT sqlserver.columnstore_no_rowgroup_qualified_for_merge
    ADD TARGET package0.event_file
    (
        SET filename = N'Tuple_Mover_Xe', max_file_size = 10
    )
    WITH(STARTUP_STATE = OFF);
GO

ALTER EVENT SESSION Tuple_Mover_Xe ON SERVER STATE = START;
GO

--------------------------------------------------------------------------------------------------------------------------------
-- EOF
--------------------------------------------------------------------------------------------------------------------------------
