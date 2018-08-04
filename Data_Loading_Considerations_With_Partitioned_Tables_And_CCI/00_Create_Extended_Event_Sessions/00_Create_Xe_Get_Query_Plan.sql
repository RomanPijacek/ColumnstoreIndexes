USE master;
GO

-------------------------------------------------------------------------------------------
-- Create Extended Event Session to catch the Actual Exec Plan
-------------------------------------------------------------------------------------------

IF EXISTS(SELECT 1 FROM sys.server_event_sessions WHERE name = 'Get_Query_Plan_Xe')
BEGIN  
    DROP EVENT session Get_Query_Plan_Xe ON SERVER;  
END
GO

CREATE EVENT SESSION Get_Query_Plan_Xe ON SERVER 
ADD EVENT sqlserver.query_post_execution_showplan
(
    ACTION (sqlserver.database_name, sqlserver.sql_text)
    WHERE (sqlserver.database_name = N'AdventureWorks2017')
)
ADD TARGET 
    package0.event_file(SET filename = N'Get_Query_Plan_Xe', max_file_size = (10))
WITH 
(
    MAX_MEMORY = 4096 KB, EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, 
    MAX_DISPATCH_LATENCY = 30 SECONDS, MAX_EVENT_SIZE = 0 KB,
    MEMORY_PARTITION_MODE = NONE, TRACK_CAUSALITY = OFF, STARTUP_STATE = ON
)
GO

ALTER EVENT SESSION Get_Query_Plan_Xe ON SERVER STATE = START;
GO

-------------------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------------------
