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
-- Check how many rows do we have in staging tables - should be 4M records in each table
-------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT COUNT(1) AS NrOfRecords FROM stg.TranHist_Partition_1 WITH (NOLOCK);
SELECT COUNT(1) AS NrOfRecords FROM stg.TranHist_Partition_2 WITH (NOLOCK);
SELECT COUNT(1) AS NrOfRecords FROM stg.TranHist_Partition_3 WITH (NOLOCK);
SELECT COUNT(1) AS NrOfRecords FROM stg.TranHist_Partition_4 WITH (NOLOCK);

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Add constraints for each staging table so we can perform partition SWITCH
-------------------------------------------------------------------------------------------------------------------------------------------------------

ALTER TABLE stg.TranHist_Partition_1 WITH CHECK ADD CONSTRAINT ckTranIDPart1 CHECK 
(
	TransactionID IS NOT NULL AND 
	TransactionID > 0 AND 
	TransactionID <= 4000000
);
ALTER TABLE stg.TranHist_Partition_2 WITH CHECK ADD CONSTRAINT ckTranIDPart2 CHECK 
(
	TransactionID IS NOT NULL AND 
	TransactionID > 4000000 AND 
	TransactionID <= 8000000
);
ALTER TABLE stg.TranHist_Partition_3 WITH CHECK ADD CONSTRAINT ckTranIDPart3 CHECK 
(
	TransactionID IS NOT NULL AND 
	TransactionID > 8000000 AND 
	TransactionID <= 12000000
);
ALTER TABLE stg.TranHist_Partition_4 WITH CHECK ADD CONSTRAINT ckTranIDPart4 CHECK 
(
	TransactionID IS NOT NULL AND 
	TransactionID > 12000000 AND 
	TransactionID <= 16000000
);
GO

/*
-- Review and ensure that constraints are trusted and not disabled
SELECT [name], [type_desc], is_disabled, is_not_trusted FROM sys.check_constraints WHERE name LIKE 'ckTranIDPart%';

-- To make constraints trusted again:
ALTER TABLE stg.TranHist_Partition_1 WITH CHECK CHECK CONSTRAINT ckTranIDPart1;
ALTER TABLE stg.TranHist_Partition_2 WITH CHECK CHECK CONSTRAINT ckTranIDPart2;
ALTER TABLE stg.TranHist_Partition_3 WITH CHECK CHECK CONSTRAINT ckTranIDPart3;
ALTER TABLE stg.TranHist_Partition_4 WITH CHECK CHECK CONSTRAINT ckTranIDPart4;
*/

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Switch them all to target
-------------------------------------------------------------------------------------------------------------------------------------------------------

ALTER TABLE stg.TranHist_Partition_1 SWITCH TO Production.TransactionHistory_Part_DST PARTITION 2;
ALTER TABLE stg.TranHist_Partition_2 SWITCH TO Production.TransactionHistory_Part_DST PARTITION 3;
ALTER TABLE stg.TranHist_Partition_3 SWITCH TO Production.TransactionHistory_Part_DST PARTITION 4;
ALTER TABLE stg.TranHist_Partition_4 SWITCH TO Production.TransactionHistory_Part_DST PARTITION 5;
GO

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Check how many records do we have in destination table 
-------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT COUNT(1) AS NrOfRecords FROM Production.TransactionHistory_Part_DST WITH (NOLOCK);

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------------------------------------------------------------------------------
