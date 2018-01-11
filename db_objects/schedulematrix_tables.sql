IF NOT EXISTS (SELECT * FROM sys.schemas where name = 'schedulematrix')
	EXEC ('CREATE SCHEMA schedulematrix')
IF object_id('schedulematrix.Schedule') IS NOT NULL
	DROP TABLE schedulematrix.Schedule
GO
CREATE TABLE schedulematrix.Schedule(
  server_id int not null
, job_id int not null
, start_time datetime
, duration_sec int
, run_status int
)
GO
CREATE CLUSTERED INDEX idx_schedule ON schedulematrix.Schedule(server_id,job_id,start_time)

IF object_id('schedulematrix.Jobs') IS NOT NULL
	DROP TABLE schedulematrix.Jobs
GO
CREATE TABLE schedulematrix.Jobs(
  job_id int identity primary key clustered
, job_name nvarchar(256)
)
GO

CREATE NONCLUSTERED INDEX idx_jobs_name ON schedulematrix.Jobs(job_name) INCLUDE (job_id)
GO

IF object_id('schedulematrix.Servers') IS NOT NULL
	DROP TABLE schedulematrix.Servers
GO
CREATE TABLE schedulematrix.Servers(
  server_id int identity primary key clustered
, server_name nvarchar(128)
, instance_name nvarchar(256)
, server_type varchar(10)
)
GO

CREATE NONCLUSTERED INDEX idx_servers_name ON schedulematrix.Servers(instance_name, server_name) INCLUDE (server_id)
GO

IF object_id('schedulematrix.JobsServers_Link') IS NOT NULL
	DROP TABLE schedulematrix.JobsServers_Link
GO

CREATE TABLE schedulematrix.JobsServers_Link(
  serverjob_link_id int identity primary key clustered
, job_id int 
, server_id int
)
GO

CREATE NONCLUSTERED INDEX idx_jobsservers_link_server_id ON schedulematrix.JobsServers_Link(server_id, job_id)
GO

IF object_id('schedulematrix.vJobSchedule') IS NOT NULL
	DROP VIEW schedulematrix.vJobSchedule
GO
CREATE VIEW schedulematrix.vJobSchedule
AS
SELECT 
  srv.server_name
, srv.instance_name
, srv.server_id
, j.job_id
, j.job_name
, s.start_time
, s.duration_sec
, s.run_status
, srv.server_type
FROM schedulematrix.Schedule s
INNER JOIN schedulematrix.Jobs j ON s.job_id = j.job_id
INNER JOIN schedulematrix.Servers srv ON srv.server_id = s.server_id
GO

IF OBJECT_ID('schedulematrix.JobScheduleStage') IS NOT NULL
	DROP TABLE schedulematrix.JobScheduleStage
CREATE TABLE schedulematrix.JobScheduleStage(
  server_name nvarchar(128)
, instance_name nvarchar(128)
, job_name nvarchar(256)
, start_time datetime
, duration_sec int
, run_status int
, server_type varchar(10)
)

IF NOT EXISTS (SELECT * FROM sys.types WHERE name = 'IntSet')
CREATE TYPE IntSet AS TABLE 
(
 id int
)
GO