--------------------------------------------------------------------------------------------------------------------------------
--  Author:         Roman Pijacek
--  Created Date:   2018-07-09
--  Description:    This script is a part of the Columnstore MERGE policy testing.
--  
--  Test Scenario:  Combine one or more compressed rowgroups such that total number of rows <= 1,024,576.  
--                  For example, if you bulk import 5 batches of size 102400, you will get 5 compressed rowgroups. 
--                  Now if you run REORGANIZE command, these rowgroups will get merged into 1 compressed rowgroup 
--                  of size 512000 rows	assuming there were no dictionary size or memory limitation.				
--  
--  Source:         https://goo.gl/3xMbr7
--                  https://goo.gl/u6vnGC
--------------------------------------------------------------------------------------------------------------------------------

USE AdventureWorks2017;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

--------------------------------------------------------------------------------------------------------------------------------
-- TEST 1:  Load 5 batches of size 102400, so we will get 5 compressed rowgroups
--------------------------------------------------------------------------------------------------------------------------------

TRUNCATE TABLE Production.TransactionHistory_DST;
GO

DECLARE @batchSize INT = 102400;
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
-- Let's review how many RGs do we have - we should have 5 RGs, each should have 102400 rows
--------------------------------------------------------------------------------------------------------------------------------

SELECT 
    OBJECT_NAME(object_id) AS table_name, 
    row_group_id,
    total_rows,
    state_desc,
    transition_to_compressed_state_desc
FROM 
    sys.dm_db_column_store_row_group_physical_stats 
WHERE
    object_id = OBJECT_ID('Production.TransactionHistory_DST')
ORDER BY
    row_group_id ASC;

--------------------------------------------------------------------------------------------------------------------------------
-- Let’s REORGANIZE the CCI index 
--------------------------------------------------------------------------------------------------------------------------------

ALTER INDEX CCI_TransactionHistory_DST ON Production.TransactionHistory_DST 
REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON);

--------------------------------------------------------------------------------------------------------------------------------
-- Let's review how many RGs do we have after REORGANIZE - expected 1 RGs with 512000 rows - rest will be removed by TupleMover
--------------------------------------------------------------------------------------------------------------------------------

SELECT 
    OBJECT_NAME(object_id) AS table_name, 
    row_group_id,
    total_rows,
    state_desc,
    transition_to_compressed_state_desc
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
