USE AdventureWorks2017;
GO

SELECT 
	OBJECT_NAME(object_id) AS table_name,
	partition_number, 
	used_page_count, 
	reserved_page_count, 
	row_count 
FROM 
	sys.dm_db_partition_stats   
WHERE 
	object_id = OBJECT_ID('Production.TransactionHistory_Part_DST');  
GO  

SELECT 
	OBJECT_NAME(object_id) AS table_name,
	partition_number, 
	state_desc,
	total_rows,
	transition_to_compressed_state_desc,
	has_vertipaq_optimization
FROM 
	sys.dm_db_column_store_row_group_physical_stats
WHERE 
	object_id = OBJECT_ID('Production.TransactionHistory_Part_DST');  
GO
