--------------------------------------------------------------------------------------------------------------------------------
--  Author:         Roman Pijacek
--  Created Date:   2018-07-11
--  Description:    This script is a part of the Columnstore MERGE policy testing.
--  
--  Test Scenario:  If there is a choice between self-merge or merging two or more rowgroups, 
--                  the merging of two or more rowgroups is favored. For example, if there are two compressed rowgroups 
--                  RG1 with 500k rows and RG2 with 1,048,576 rows but 60% of the rows are deleted. In this case, instead of 
--                  self-merging RG2, the merge policy will combine RG1 and RG2 into one compressed rowgroup.			
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
-- TEST 2:  Load 2 batches: first one that has 500k rows and a second one that has 1,048,576 million rows
--------------------------------------------------------------------------------------------------------------------------------

TRUNCATE TABLE Production.TransactionHistory_DST_3;
GO

DECLARE @batchSizeRG1 INT = 500000;
DECLARE @batchSizeRG2 INT = 1048576;
DECLARE @recordsLoaded INT = 0;
DECLARE @counter TINYINT = 1;
DECLARE @sqlCmd NVARCHAR(MAX) = '';

WHILE @counter <= 2
BEGIN
    SET @sqlCmd = '
        INSERT INTO Production.TransactionHistory_DST_3 WITH(TABLOCKX)
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
        OFFSET ' + CAST (@recordsLoaded AS VARCHAR) + ' ROWS FETCH NEXT ' 
            + CAST(IIF((@counter = 1), @batchSizeRG1, @batchSizeRG2) AS VARCHAR) + ' ROWS ONLY
        OPTION (MAXDOP 1);';
    
    EXECUTE sp_executesql @sqlCmd;
    
    SET @recordsLoaded += IIF((@counter = 1), @batchSizeRG1, @batchSizeRG2 );
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
    object_id = OBJECT_ID('Production.TransactionHistory_DST_3')
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
    p.object_id = OBJECT_ID('Production.TransactionHistory_DST_3') AND
    cs.column_id = 1
ORDER BY
    cs.segment_id ASC; 

--------------------------------------------------------------------------------------------------------------------------------
-- Let's delete 60% of rows from the 2nd group
--------------------------------------------------------------------------------------------------------------------------------

DELETE TOP (60) PERCENT
FROM 
    Production.TransactionHistory_DST_3
WHERE
    TransactionID BETWEEN -2146983648 AND -2145935073; -- Range for the 2nd group

--------------------------------------------------------------------------------------------------------------------------------
-- Now, it's time to REORGANIZE the CCI index 
--------------------------------------------------------------------------------------------------------------------------------

ALTER INDEX CCI_TransactionHistory_DST_3 ON Production.TransactionHistory_DST_3
REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON);

--------------------------------------------------------------------------------------------------------------------------------
-- After REORGANIZE, let's review rg physical stats and data distribution (based on the TransactionID column)
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
    object_id = OBJECT_ID('Production.TransactionHistory_DST_3')
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
    p.object_id = OBJECT_ID('Production.TransactionHistory_DST_3') AND
    cs.column_id = 1
ORDER BY
    cs.segment_id ASC; 

--------------------------------------------------------------------------------------------------------------------------------
-- Clean Up
--------------------------------------------------------------------------------------------------------------------------------

TRUNCATE TABLE Production.TransactionHistory_DST_3;
GO

--------------------------------------------------------------------------------------------------------------------------------
-- EOF
--------------------------------------------------------------------------------------------------------------------------------
