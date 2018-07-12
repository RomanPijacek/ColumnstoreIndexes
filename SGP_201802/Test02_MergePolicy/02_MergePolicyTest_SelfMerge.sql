--------------------------------------------------------------------------------------------------------------------------------
--  Author:         Roman Pijacek
--  Created Date:   2018-07-11
--  Description:    This script is a part of the Columnstore MERGE policy testing.
--  
--  Test Scenario:  When > 102400 rows are marked deleted, a compressed RG is eligible for self-merge. 
--                  For example, if a compressed row group of 1,048,576 million rows has 110k rows deleted, 
--                  we can remove the deleted rows and recompress the rowgroup with the remaining rows. 
--                  It saves on the storage by removing deleted rows.			
--  
--  Source:         https://goo.gl/3xMbr7
--------------------------------------------------------------------------------------------------------------------------------

USE AdventureWorks2017;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

--------------------------------------------------------------------------------------------------------------------------------
-- TEST 2:  Load 3 batches of 1,048,576 million rows
--------------------------------------------------------------------------------------------------------------------------------

TRUNCATE TABLE Production.TransactionHistory_DST_2;
GO

DECLARE @batchSize INT = 1048576;
DECLARE @recordsLoaded INT = 0;
DECLARE @counter TINYINT = 0;
DECLARE @sqlCmd NVARCHAR(MAX) = '';

WHILE @counter < 3
BEGIN
    SET @sqlCmd = '
        INSERT INTO Production.TransactionHistory_DST_2 WITH(TABLOCK)
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
    state_desc,
    transition_to_compressed_state_desc
FROM 
    sys.dm_db_column_store_row_group_physical_stats 
WHERE
    object_id = OBJECT_ID('Production.TransactionHistory_DST_2')
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
    p.object_id = OBJECT_ID('Production.TransactionHistory_DST_2') AND
    cs.column_id = 1
ORDER BY
    cs.segment_id ASC;

--------------------------------------------------------------------------------------------------------------------------------
-- Let’s delete 10% of rows from the 1st group
--------------------------------------------------------------------------------------------------------------------------------

DELETE TOP (10) PERCENT
FROM 
    Production.TransactionHistory_DST_2
WHERE
    TransactionID BETWEEN -2147483648 AND -2146435073; -- Range for the 1st group

--------------------------------------------------------------------------------------------------------------------------------
-- Now, it's time to REORGANIZE the CCI index 
--------------------------------------------------------------------------------------------------------------------------------

ALTER INDEX CCI_TransactionHistory_DST_2 ON Production.TransactionHistory_DST_2 
REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON);

--------------------------------------------------------------------------------------------------------------------------------
-- After REORGANIZE, let's review rg physical stats and data distribution (based on the TransactionID column)
--------------------------------------------------------------------------------------------------------------------------------

-- Rowgroups physical stats:
SELECT 
    OBJECT_NAME(object_id) AS table_name, 
    row_group_id,
    total_rows,
    state_desc,
    transition_to_compressed_state_desc
FROM 
    sys.dm_db_column_store_row_group_physical_stats 
WHERE
    object_id = OBJECT_ID('Production.TransactionHistory_DST_2')
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
    p.object_id = OBJECT_ID('Production.TransactionHistory_DST_2') AND
    cs.column_id = 1
ORDER BY
    cs.segment_id ASC;

--------------------------------------------------------------------------------------------------------------------------------
-- EOF
--------------------------------------------------------------------------------------------------------------------------------
