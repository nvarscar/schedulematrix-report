# about
This is a report that would allow you to see the execution of database Jobs across your environment throughout the week.
Job Schedule Matrix - matrix-based report, more reliable, can be exported to Excel, but struggles with performance when there is too much data
Job Schedule Chart - chart-based report, simple yet effective, might have issues with some browsers (would not load), but otherwise works faster than matrix

load script relies on the dbatools Powershell module - http://dbatools.io or http://github.com/sqlcollaborative/dbatools

# requirements
- SQL Server 2008R2+
- Database Services
- Reporting Services
- (optional; for data collection) Powershell 3.0 + dbatools module

# setup
1. Run sql scripts from .\db_objects in the database of your choice:
   - schedulematrix_tables.sql
   - schedulematrix_loadStageData.sql
   - schedulematrix_rptJobScheduleChart.sql
   - schedulematrix_rptJobScheduleMatrix.sql
   
   This would create necessary objects in the schedulematrix schema.
   
2. Upload reports from .\reports to your Reporting Services server and configure data sources in those reports to point to the database from step 1.
3. Set up a job to collect job history data from your environment:
   - 1: Run SQL code to truncate stage table
   
        `TRUNCATE TABLE [<your DB name here>].schedulematrix.JobScheduleStage`
        
   - 2: Run Powershell script to collect data from your environment (or any other method of your choice). This example uses .\examples\schedulematrix_load.ps1 to collect data and requires dbatools module to be installed (see links above):
   
       `Powershell.exe <..>\examples\schedulematrix_load.ps1 -TargetServer sql1 -TargetDatabase MyDB -SourceServer sql2,sql3\instance1 -NonInteractive`
       
   - 3: Run stored procedure to re-populate report tables
   
        `EXEC [<your DB name here>].schedulematrix.loadStageData`

4. (optional) Download and install dbatools module if you want to utilize schedulematrix_load.ps1: 
    - Run Powershell 5.0 as administrator
    - Run `Install-Module dbatools`; agree to trust the repository.
    
# known issues
- SQL 2016 would not handle borders correctly, enforcing borders on each cell of the report.
