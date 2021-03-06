USE AdventureWorksDW2017;
GO

SET NOCOUNT ON;
GO

DROP TABLE IF EXISTS dbo.FactProductInventory_DST;
GO
 
CREATE TABLE dbo.FactProductInventory_DST
(
	ProductKey INT NOT NULL,
	DateKey INT NOT NULL,
	MovementDate DATE NOT NULL,
	UnitCost MONEY NOT NULL,
	UnitsIn INT NOT NULL,
	UnitsOut INT NOT NULL,
	UnitsBalance INT NOT NULL,
	QuarterRange VARCHAR(16) NOT NULL,
    Column1 VARCHAR(64) NULL,
    Column2 VARCHAR(64) NULL,
    Column3 VARCHAR(64) NULL,
    Column4 VARCHAR(64) NULL
);

CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactProductInventory ON dbo.FactProductInventory_DST;

---------------------------------------------------------------------------------------------------
-- Populate table with some records
---------------------------------------------------------------------------------------------------

TRUNCATE TABLE dbo.FactProductInventory_DST;
GO

DECLARE @batchSize INT = 775000; 
DECLARE @counter TINYINT = 0;
DECLARE @sqlCmd NVARCHAR(MAX) = '';
DECLARE @randomString VARCHAR(64) = LEFT(NEWID(), 64);

WHILE @counter < 100
BEGIN    
    SET @sqlCmd = '
        INSERT INTO dbo.FactProductInventory_DST WITH(TABLOCKX)
        (
	        ProductKey,
	        DateKey,
	        MovementDate,
	        UnitCost,
	        UnitsIn,
	        UnitsOut,
	        UnitsBalance,
	        QuarterRange,
            Column1,
            Column2,
            Column3,
            Column4
        )
        SELECT TOP (' + CAST(@batchSize AS VARCHAR(12)) + ')
	        ProductKey,
	        DateKey,
	        MovementDate,
	        UnitCost,
	        UnitsIn,
	        UnitsOut,
	        UnitsBalance,
	        QuarterRange,
            '''  + IIF(@counter % 2 = 0, LEFT(NEWID(), 64), @randomString) + ''' AS Column1,
            '''  + IIF(@counter % 3 = 0, LEFT(NEWID(), 64), @randomString) + ''' AS Column2,
            '''  + IIF(@counter % 4 = 0, LEFT(NEWID(), 64), @randomString) + ''' AS Column3,
            '''  + IIF(@counter % 2 = 0, LEFT(NEWID(), 64), @randomString) + ''' AS Column4
        FROM 
            dbo.FactProductInventory
        OPTION (MAXDOP 1)';
    
    EXECUTE sp_executesql @sqlCmd;
    
    SET @counter += 1;
END


SELECT COUNT(1) FROM dbo.FactProductInventory_DST;
-- 77 500 000

---------------------------------------------------------------------------------------------------
-- Let's review how many RGs do we have
---------------------------------------------------------------------------------------------------

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
    object_id = OBJECT_ID('dbo.FactProductInventory_DST')
ORDER BY
    row_group_id ASC;

---------------------------------------------------------------------------------------------------
-- 1.) Lets perform a test with JOIN
---------------------------------------------------------------------------------------------------

SET STATISTICS IO, TIME ON;
GO

SELECT
    q.CalendarYear,
    SUM(UnitCost) AS TotalUnitCost,
    f.Column1,
    f.Column2,
    f.Column3,
    f.Column4
FROM 
    dbo.FactProductInventory_DST AS f
    INNER JOIN v_CalendarQuarters AS q ON q.QuarterRange = f.QuarterRange
GROUP BY
    q.CalendarYear,
    f.Column1,
    f.Column2,
    f.Column3,
    f.Column4;   

---------------------------------------------------------------------------------------------------
-- 2.) Lets perform a test using the LEFT() function
---------------------------------------------------------------------------------------------------

SELECT
    LEFT(f.QuarterRange, 4) AS CalendarYear,
    SUM(UnitCost) AS TotalUnitCost,
    f.Column1,
    f.Column2,
    f.Column3,
    f.Column4
FROM 
    dbo.FactProductInventory_DST AS f
GROUP BY
    LEFT(f.QuarterRange, 4),
    f.Column1,
    f.Column2,
    f.Column3,
    f.Column4;

---------------------------------------------------------------------------------------------------
-- EOF
---------------------------------------------------------------------------------------------------
