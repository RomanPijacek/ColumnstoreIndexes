--------------------------------------------------------------------------------------------------------------------------------
--  Author:         Roman Pijacek
--  Created Date:   2018-07-14
--  Description:    This script is a part of the Columnstore MERGE policy testing.
--  
--  Test Scenario:  If you have three rowgroups that qualify for merge, they are considered for merge in sequential order. 
--                  For example, rowwgroup1 (500k), rowgroup2 (500k) and rowgroup3 (500k)
--                  - we will merge the first two qualifying ones.	
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
-- TEST 4:  Load 3 batches of size 500000, so we will get 3 compressed rowgroups
--------------------------------------------------------------------------------------------------------------------------------

TRUNCATE TABLE Production.TransactionHistory_DST_4;
GO

DECLARE @batchSize INT = 500000;
DECLARE @recordsLoaded INT = 0;
DECLARE @counter TINYINT = 0;
DECLARE @sqlCmd NVARCHAR(MAX) = '';

WHILE @counter < 3
BEGIN
    SET @sqlCmd = '
        INSERT INTO Production.TransactionHistory_DST_4 WITH(TABLOCKX)
        (
            TransactionID,
            ProductID,
            ReferenceOrderID,
            ReferenceOrderLineID,
            TransactionDate,
            TransactionQty,
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
            TransactionQty,
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
-- Let's review rg physical stats and data distribution (based on the TransactionID column)
--------------------------------------------------------------------------------------------------------------------------------

-- Rowgroups physical stats:
SELECT 
    OBJECT_NAME(object_id) AS table_name, 
    row_group_id,
    total_rows,
    deleted_rows,
    state_desc,
    transition_to_compressed_state_desc
FROM 
    sys.dm_db_column_store_row_group_physical_stats 
WHERE
    object_id = OBJECT_ID('Production.TransactionHistory_DST_4')
ORDER BY
    row_group_id ASC;

-- Rougroups data distribution:
SELECT
    OBJECT_NAME(p.object_id) AS table_name,
    cs.segment_id, 
    cs.min_data_id, 
    cs.max_data_id,
    cs.row_count,
    cs.on_disk_size
FROM
    sys.column_store_segments AS cs
    INNER JOIN sys.partitions AS p ON cs.hobt_id = p.hobt_id   
WHERE 
    p.object_id = OBJECT_ID('Production.TransactionHistory_DST_4') AND
    cs.column_id = 1
ORDER BY
    cs.segment_id ASC; 

--------------------------------------------------------------------------------------------------------------------------------
-- Let’s REORGANIZE the CCI index 
--------------------------------------------------------------------------------------------------------------------------------

ALTER INDEX CCI_TransactionHistory_DST_4 ON Production.TransactionHistory_DST_4 
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
    object_id = OBJECT_ID('Production.TransactionHistory_DST_4')
ORDER BY
    row_group_id ASC;

--------------------------------------------------------------------------------------------------------------------------------
-- Clean Up
--------------------------------------------------------------------------------------------------------------------------------

TRUNCATE TABLE Production.TransactionHistory_DST_4;
GO

--------------------------------------------------------------------------------------------------------------------------------
-- EOF
--------------------------------------------------------------------------------------------------------------------------------
