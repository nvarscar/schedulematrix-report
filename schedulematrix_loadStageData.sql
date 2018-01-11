IF OBJECT_ID('schedulematrix.loadStageData') IS NULL
	EXEC ('CREATE PROCEDURE schedulematrix.loadStageData AS SELECT 1')
GO
ALTER PROCEDURE schedulematrix.loadStageData
AS
BEGIN
	-- Truncate data from existing tables
	TRUNCATE TABLE schedulematrix.Servers
	TRUNCATE TABLE schedulematrix.Jobs
	TRUNCATE TABLE schedulematrix.JobsServers_Link
	TRUNCATE TABLE schedulematrix.Schedule

	--Insert unique servers
	INSERT INTO schedulematrix.Servers (server_name,instance_name,server_type)
	SELECT DISTINCT 
		[server_name]
		, [instance_name]
		, [server_type]
	FROM schedulematrix.JobScheduleStage

	--Insert unique jobs
	INSERT INTO schedulematrix.Jobs (job_name)
	SELECT DISTINCT 
	job_name
	FROM schedulematrix.JobScheduleStage s

	--Link jobs and instances
	INSERT INTO schedulematrix.JobsServers_Link (server_id, job_id)
	SELECT DISTINCT 
	srv.server_id
	, j.job_id 
	FROM schedulematrix.JobScheduleStage s
	INNER JOIN schedulematrix.Jobs j ON s.job_name = j.job_name
	INNER JOIN schedulematrix.Servers srv ON srv.instance_name = s.instance_name AND srv.server_name = s.server_name

	--Insert job execution data
	INSERT INTO schedulematrix.Schedule (
	server_id
	, job_id 
	, start_time
	, duration_sec
	, run_status -- 0: failed; 1: succeeded; other values are not supported right now.
	)
	SELECT 
	srv.server_id
	, j.job_id 
	, s.start_time
	, s.duration_sec
	, s.run_status
	FROM schedulematrix.JobScheduleStage s
	INNER JOIN schedulematrix.Jobs j ON s.job_name = j.job_name
	INNER JOIN schedulematrix.Servers srv ON srv.instance_name = s.instance_name AND srv.server_name = s.server_name

END