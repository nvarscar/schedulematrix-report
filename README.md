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
1. Run all of the sql scripts from .\db_objects in the database of your choice. 
   This would create necessary objects in the schedulematrix schema.
2. Upload reports to your Reporting Services server and configure data sources to point to the database in step 1.
3. Set up a job to collect job history data from your environment:
   - 1: Run SQL code to truncate stage table
   
        `TRUNCATE TABLE [<your DB name here>].schedulematrix.JobScheduleStage`
        
        
   - 2: Run Powershell script to collect data from your environment (or any other method of your choice)
   
       This is just an *example*: `Powershell.exe <..>\examples\schedulematrix_load.ps1 -NonInteractive`
       
   - 3: Run stored procedure to re-populate report tables
   
        `EXEC [<your DB name here>].schedulematrix.loadStageData`
        
# known issues
- SQL 2016 would not handle borders correctly, enforcing borders on each cell of the report, 
