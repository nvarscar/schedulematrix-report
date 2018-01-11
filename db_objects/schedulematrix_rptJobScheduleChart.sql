IF OBJECT_ID('schedulematrix.rptJobScheduleChart') IS NULL
	EXEC ('CREATE PROCEDURE schedulematrix.rptJobScheduleChart AS SELECT 1')
GO
ALTER PROCEDURE schedulematrix.rptJobScheduleChart
(
	@WeekStartTime datetime = NULL -- start point of the week schedule
  , @ServerList IntSet READONLY -- list of server IDs
  , @JobList IntSet READONLY -- list of job IDs
  , @Bucketsize int = 30 -- bucket size in minutes; hour subdivision cells
)
AS
BEGIN
--Procedure starts

DECLARE @AdjustedWeekDate datetime = @WeekStartTime;
DECLARE @ColourTable TABLE (id int identity(0,1), name varchar(32), hex char(7))
DECLARE @BGColour char(7) = '#333333' -- Background colour of the canvas

-- Select colours for jobs
INSERT INTO @ColourTable (name, hex) VALUES
('Lime','#00FF00'),('Blue','#0000FF'),('Yellow','#FFFF00'),('Cyan','#00FFFF')
,('Maroon','#800000'),('Olive','#808000'),('Green','#008000'),('Purple','#800080')
,('Teal','#008080'),('Navy','#000080'),
('dark orange','#FF8C00'),('beige','#F5F5DC'),
('orange','#FFA500'),('bisque','#FFE4C4'),
('gold','#FFD700'),('medium blue','#0000CD'),('blanched almond','#FFEBCD'),
('dark golden rod','#B8860B'),('royal blue','#4169E1'),('wheat','#F5DEB3'),
('golden rod','#DAA520'),('blue violet','#8A2BE2'),('corn silk','#FFF8DC'),
('pale golden rod','#EEE8AA'),('indigo','#4B0082'),('lemon chiffon','#FFFACD'),
('light golden rod yellow','#FAFAD2'),
('khaki','#F0E68C'),('slate blue','#6A5ACD'),('light yellow','#FFFFE0'),
('yellow green','#9ACD32'),('medium slate blue','#7B68EE'),('saddle brown','#8B4513'),
('dark olive green','#556B2F'),('medium purple','#9370DB'),('sienna','#A0522D'),
('olive drab','#6B8E23'),('dark magenta','#8B008B'),('chocolate','#D2691E'),
('lawn green','#7CFC00'),('peru','#CD853F'),
('chart reuse','#7FFF00'),('dark orchid','#9932CC'),('sandy brown','#F4A460'),
('green yellow','#ADFF2F'),('medium orchid','#BA55D3'),('burly wood','#DEB887'),
('plum','#DDA0DD'),('tan','#D2B48C'),
('forest green','#228B22'),('violet','#EE82EE'),('rosy brown','#BC8F8F'),
('lime green','#32CD32'),('magenta / fuchsia','#FF00FF'),('moccasin','#FFE4B5'),
('light green','#90EE90'),('orchid','#DA70D6'),('navajo white','#FFDEAD'),
('pale green','#98FB98'),('medium violet red','#C71585'),('peach puff','#FFDAB9'),
('dark sea green','#8FBC8F'),('pale violet red','#DB7093'),('misty rose','#FFE4E1'),
('medium spring green','#00FA9A'),('deep pink','#FF1493'),('lavender blush','#FFF0F5'),
('spring green','#00FF7F'),('hot pink','#FF69B4'),('linen','#FAF0E6'),
('sea green','#2E8B57'),('light pink','#FFB6C1'),('old lace','#FDF5E6'),
('medium aqua marine','#66CDAA'),('pink','#FFC0CB'),('papaya whip','#FFEFD5'),
('medium sea green','#3CB371'),('antique white','#FAEBD7'),('sea shell','#FFF5EE')

-- Create temporary objects
IF OBJECT_ID('tempdb..#JobSchedule') IS NOT NULL 
	DROP TABLE #JobSchedule
CREATE TABLE #JobSchedule(
  server_name nvarchar(128)
, job_name nvarchar(256)
, instance_name nvarchar(128)
, BucketStart datetime
, BucketEnd datetime
, start_time datetime
, duration int
, [run_status] int
, execution_count int
)

IF OBJECT_ID('tempdb..#JobColours') IS NOT NULL 
	DROP TABLE #JobColours
CREATE TABLE #JobColours(
job_name nvarchar(256)
, Colour char(7)
)

CREATE CLUSTERED INDEX idx_cltjobcolours ON #JobColours([job_name])

IF OBJECT_ID('tempdb..#WeekSchedule') IS NOT NULL 
	DROP TABLE #WeekSchedule
CREATE TABLE #WeekSchedule(
  server_name nvarchar(128)
, job_name nvarchar(256)
, instance_name nvarchar(128)
, BucketStart datetime
, Colour char(7)
, start_time datetime
, duration int
, succeeded int
, execution_count int
, RangePosition int
)

CREATE CLUSTERED INDEX idx_clt_WeekSchedule ON #WeekSchedule( [server_name], BucketStart, execution_count)

-- Set default date to getdate()-7 if NULL
IF @AdjustedWeekDate IS NULL
	SET @AdjustedWeekDate = getdate()-7;

-- Adjust the date to match the @Bucketsize minutes bucket start time
SET @AdjustedWeekDate = dateadd(minute
              ,@Bucketsize * CAST(datepart(minute,@AdjustedWeekDate)/@Bucketsize AS int) -- match the bucket start time with the date specified
							,dateadd(hour, datediff(hour, '20000101', @AdjustedWeekDate), '20000101') --round down to last hour
							);
--Get schedule data from repository
INSERT INTO #JobSchedule(
	 server_name
	,job_name
	,instance_name
	,BucketStart
	,BucketEnd
	,start_time
	,duration
	,run_status
	,execution_count
)
SELECT
	 [server_name]
	,[job_name]
	,[instance_name]
	,dateadd(minute
        ,@Bucketsize * CAST(datepart(minute,start_time)/@Bucketsize AS int) -- match the bucket start time with the date specified
					,dateadd(hour, datediff(hour, '20000101', start_time), '20000101') --round down to last hour
	) as BucketStart
	,dateadd(minute
            ,@Bucketsize * CAST(datepart(minute,dateadd(second,[duration_sec],start_time))/@Bucketsize AS int) -- match the bucket end time with the date specified
						,dateadd(hour, datediff(hour, '20000101', dateadd(second,[duration_sec],start_time)), '20000101') --round down to last hour
		) as BucketEnd
	,[start_time] as [start_time]
	,[duration_sec] as duration
	,[run_status] as [run_status]
	, 1 as execution_count
FROM schedulematrix.vJobSchedule j
WHERE j.start_time >= @AdjustedWeekDate
	AND j.start_time < @AdjustedWeekDate+7
	AND (j.server_id IN (SELECT id from @ServerList) OR NOT EXISTS (SELECT * FROM @ServerList))
	AND (j.job_id IN (SELECT id from @JobList) OR NOT EXISTS (SELECT * FROM @JobList))

--Provide each job with unique colour
INSERT INTO #JobColours (job_name, Colour)
SELECT 
	sh.job_name
	, c.hex as Colour
FROM (
	SELECT
		[job_name]
		, ROW_NUMBER() OVER (ORDER BY job_name) AS job_number 
	FROM #JobSchedule
	GROUP BY [job_name]
	) sh
INNER JOIN @ColourTable c ON c.id = sh.job_number % (SELECT max(id) FROM @ColourTable)

-- Using numeric tables...
;WITH
	L0   AS(SELECT 1 AS C UNION ALL SELECT 1 AS O), -- 2 rows
	L1   AS(SELECT 1 AS C FROM L0 AS A CROSS JOIN L0 AS B), -- 4 rows
	L2   AS(SELECT 1 AS C FROM L1 AS A CROSS JOIN L1 AS B), -- 16 rows
	L3   AS(SELECT 1 AS C FROM L2 AS A CROSS JOIN L2 AS B), -- 256 rows
	L4   AS(SELECT 1 AS C FROM L3 AS A CROSS JOIN L3 AS B), -- 16K rows
	Nums AS(SELECT ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS N FROM L4),
--...generate buckets for specified week based on size of the bucket
Dates AS (
	SELECT TOP (24*7*60/@Bucketsize) 
	  dateadd(minute, (j.n-1)*@Bucketsize, @AdjustedWeekDate) as BucketStart
	  ,dateadd(minute, (j.n)*@Bucketsize, @AdjustedWeekDate) as BucketEnd
	FROM nums j
	ORDER BY j.n
)
, Jobs AS (
-- Create calendar grid for each existing job and assign it with colour
SELECT s.server_name
		, s.job_name
		, s.instance_name
		, d.BucketStart
		, c.Colour
FROM (
	SELECT DISTINCT
		sh.[server_name]
		,sh.[job_name]
		,sh.[instance_name]
	FROM #JobSchedule sh
	
) s
INNER JOIN #JobColours c ON c.job_name = s.job_name --adding colours
CROSS JOIN Dates d
)
INSERT INTO #WeekSchedule
 (
  server_name 
, job_name 
, instance_name 
, BucketStart 
, Colour
, start_time 
, duration 
, succeeded 
, execution_count 
, RangePosition 
)
SELECT
	dt.server_name
	,dt.job_name
	,dt.instance_name
	,dt.BucketStart
	,min(Colour) as Colour
	,min(j.[start_time]) as [start_time]
	,avg(ISNULL(j.duration,-1)) as duration
	,sum(ISNULL(j.[run_status],0)) as succeeded
	,sum(ISNULL(j.execution_count,0)) as execution_count
	, CASE -- Check if this bucket is a starting point of one of the jobs: 1 = true, 0 = false
		WHEN (min(j.[start_time]) >= dt.BucketStart AND min(j.[start_time]) < dateadd(minute,@BucketSize,dt.BucketStart)) THEN 1 
		ELSE 0 
	END as RangePosition
FROM Jobs dt
LEFT OUTER JOIN #JobSchedule j ON j.server_name = dt.server_name AND j.instance_name = dt.instance_name AND j.job_name = dt.job_name AND dt.BucketStart BETWEEN j.BucketStart AND j.BucketEnd
	GROUP BY dt.server_name, dt.instance_name, dt.job_name ,dt.BucketStart --,dt.BucketEnd

CREATE NONCLUSTERED INDEX idx_WeekSchedule_job ON #WeekSchedule([server_name], BucketStart, [job_name]) WHERE execution_count > 0

;WITH
-- Prepare fields for ease of use in next SELECT
PositionedSchedule AS (
SELECT
  s.server_name
, s.job_name
, s.instance_name
, s.BucketStart
, s.start_time
, s.duration
, s.Colour
, s.execution_count
, datename(weekday, s.BucketStart) + ', ' + LEFT(datename(month, s.BucketStart),3) + ' ' + CAST(datename(day, s.BucketStart) as varchar(2)) AS Weekdays
, datepart(hour, s.BucketStart) AS Hours
, datepart(minute, s.BucketStart) AS Minutes
, datepart(weekday, s.BucketStart) + CASE WHEN datepart(weekday, s.BucketStart) < datepart(weekday,@AdjustedWeekDate) THEN 7 ELSE 0 END as WeekdaysOrder
, s.execution_count-s.succeeded as failed_executions
, s.RangePosition
, ROW_NUMBER() OVER (PARTITION BY s.server_name, s.job_name, s.instance_name, s.start_time ORDER BY s.BucketStart) as rn
FROM #WeekSchedule s 
)
SELECT
  gs.server_name
, gs.job_name
, gs.instance_name
, MIN(gs.BucketStart) as BucketStart
, SUM(gs.execution_count) AS execution_count
, DENSE_RANK() OVER (ORDER BY gs.server_name) as ServerOrder
, CASE WHEN SUM(gs.execution_count) > 0 THEN gs.Colour	
	   ELSE @BGColour
	END AS Colour
, gs.instance_name + ' - ' + gs.job_name + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +
  'Executions: ' + CAST(SUM(gs.execution_count) AS VARCHAR(10)) + 
	CASE WHEN SUM(gs.failed_executions) > 0 
		THEN ' (' + CAST(SUM(gs.failed_executions) AS  VARCHAR(10)) + ' failed)' 
		ELSE '' 
	END + CHAR(13) + CHAR(10) +
  CASE WHEN SUM(gs.execution_count) > 1 THEN 'First occurrence: ' ELSE 'Start time: ' END + CONVERT(varchar(30),gs.start_time,120) + CHAR(13) + CHAR(10) +
  CASE WHEN SUM(gs.execution_count) > 1 THEN 'Average duration: ' ELSE 'Duration: ' END + 
  CASE WHEN SUM(gs.execution_count) > 3600 THEN CAST(AVG(gs.duration)/3600 AS VARCHAR(10)) + 'h ' ELSE '' END +
  CASE WHEN SUM(gs.execution_count) > 60 THEN CAST((AVG(gs.duration)/60) % 60 AS VARCHAR(10)) + 'm ' ELSE '' END +
  CAST(AVG(gs.duration) % 60 AS VARCHAR(10)) + 's' AS JobTooltip
, COUNT(*) as WindowCount
FROM PositionedSchedule gs
GROUP BY 
  gs.server_name
, gs.job_name
, gs.instance_name
, gs.Colour
, gs.start_time
, dateadd(minute,-@Bucketsize*rn,BucketStart)
ORDER BY server_name, instance_name, job_name, BucketStart
END