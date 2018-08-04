USE master;
GO

-------------------------------------------------------------------------------------------
-- Create Extended Event Session to display the Live Query Stats for a running query
-------------------------------------------------------------------------------------------

IF EXISTS(SELECT 1 FROM sys.server_event_sessions WHERE name = 'Query_Thread_Profile_Xe')
BEGIN  
    DROP EVENT session Query_Thread_Profile_Xe ON SERVER;  
END
GO

CREATE EVENT SESSION Query_Thread_Profile_Xe ON SERVER 
ADD EVENT sqlserver.query_thread_profile
WITH 
(
    MAX_MEMORY = 4096 KB, EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, 
    MAX_DISPATCH_LATENCY = 30 SECONDS, MAX_EVENT_SIZE = 0 KB, 
    MEMORY_PARTITION_MODE = NONE, TRACK_CAUSALITY = OFF, STARTUP_STATE = ON
)
GO

ALTER EVENT SESSION Query_Thread_Profile_Xe ON SERVER STATE = START;
GO

-------------------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------------------
