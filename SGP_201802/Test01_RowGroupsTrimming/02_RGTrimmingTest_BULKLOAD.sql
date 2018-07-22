--------------------------------------------------------------------------------------------------------------------------------
--  Author:          Roman Pijacek
--  Created Date:    2018-07-22
--  Description:     This script is a part of the Columnstore RG Trimming tests.
--  
--  Test Scenario:   2 � BULKLOAD: The bulk load batch size limited the number of rows.				
--  
--  Source:          https://goo.gl/GcsP7A
--------------------------------------------------------------------------------------------------------------------------------

USE AdventureWorks2017;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

--------------------------------------------------------------------------------------------------------------------------------
-- TEST 2:  Load 1 batch of size 500 000, so we will get 1 compressed rowgroups with BULKLOAD trim reason.
--------------------------------------------------------------------------------------------------------------------------------

TRUNCATE TABLE Production.TransactionHistory_DST;
GO

DECLARE @batchSize INT = 500000;
DECLARE @recordsLoaded INT = 0;
DECLARE @counter TINYINT = 0;
DECLARE @sqlCmd NVARCHAR(MAX) = '';

WHILE @counter < 1
BEGIN
    SET @sqlCmd = '
        INSERT INTO Production.TransactionHistory_DST WITH(TABLOCKX)
        (
            TransactionID,
            ProductID,
            ReferenceOrderID,
            ReferenceOrderLineID,
            TransactionDate,
            TransactionType,
            Quantity,
            ActualCost,
            ModifiedDate
        )
        SELECT 
            TransactionID,
            ProductID,
            ReferenceOrderID,
            ReferenceOrderLineID,
            TransactionDate,
            TransactionType,
            Quantity,
            ActualCost,
            ModifiedDate
        FROM 
            Production.TransactionHistory_SRC
        ORDER BY 
            TransactionID ASC 
        OFFSET ' + CAST (@recordsLoaded AS VARCHAR) + ' ROWS FETCH NEXT ' + CAST(@batchSize AS VARCHAR) + ' ROWS ONLY
        OPTION (MAXDOP 1);';
    
    EXECUTE sp_executesql @sqlCmd;
    
    SET @recordsLoaded += @batchSize;
    SET @counter += 1;
END

--------------------------------------------------------------------------------------------------------------------------------
-- Let's review how many RGs do we have - we should have 1 compressed rowgroups with BULKLOAD trim reason
--------------------------------------------------------------------------------------------------------------------------------

SELECT 
    OBJECT_NAME(object_id) AS table_name, 
    row_group_id,
    total_rows,
    state_desc,
    trim_reason,
    trim_reason_desc
FROM 
    sys.dm_db_column_store_row_group_physical_stats 
WHERE
    object_id = OBJECT_ID('Production.TransactionHistory_DST')
ORDER BY
    row_group_id ASC;

--------------------------------------------------------------------------------------------------------------------------------
-- Clean Up
--------------------------------------------------------------------------------------------------------------------------------

TRUNCATE TABLE Production.TransactionHistory_DST;
GO

--------------------------------------------------------------------------------------------------------------------------------
-- EOF
--------------------------------------------------------------------------------------------------------------------------------
