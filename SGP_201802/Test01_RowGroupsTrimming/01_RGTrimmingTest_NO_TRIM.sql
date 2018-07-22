--------------------------------------------------------------------------------------------------------------------------------
--  Author:          Roman Pijacek
--  Created Date:    2018-07-22
--  Description:     This script is a part of the Columnstore RG Trimming tests.
--  
--  Test Scenario:   1 - NO_TRIM: The row group was not trimmed. The row group was compressed with the maximum of 1,048,476 rows. 
--                   The number of rows could be less if a subsset of rows was deleted after delta rowgroup was closed.				
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
-- TEST 1:  Load 5 batches of size 1048576, so we will get 5 compressed rowgroups with NO_TRIM trim reason
--------------------------------------------------------------------------------------------------------------------------------

TRUNCATE TABLE Production.TransactionHistory_DST;
GO

DECLARE @batchSize INT = 1048576; -- Max Size so we do not trim RGs
DECLARE @recordsLoaded INT = 0;
DECLARE @counter TINYINT = 0;
DECLARE @sqlCmd NVARCHAR(MAX) = '';

WHILE @counter < 5
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
-- Let's review how many RGs do we have - we should have 5 RGs, each should NO_TRIM trim reason.
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
