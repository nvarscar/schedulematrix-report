<#
.SYNOPSIS 
    Adds agent job history data to the schedulematrix stage table
.DESCRIPTION 
    Connects to a server, reads agent job history, and adds data to the schedulematrix stage table
.NOTES 
Copyright (C) 2018 Kirill Kravtsov
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
#>

[CmdletBinding()]
Param (
	[object]$TargetServer = "localhost",
	[object]$TargetCredential,
	[string]$TargetDatabase = "tempdb",
	[object[]]$SourceServer = "localhost",
	[object]$SourceCredential,
	[string]$LogFileFolder = "."
)
BEGIN {
	Write-Verbose -Message "Agent Job History started: $((Get-Date).DateTime)"
	
	# Specify table name that we'll be inserting into
	$table = "schedulematrix.JobScheduleStage"
	$schema = $table.Split(".")[0]
	$tablename = $table.Split(".")[1]
	
	# Connect to the target server
	Write-Verbose -Message "Connecting to $TargetServer"
	$tgtserver = Connect-DbaInstance -SqlInstance $TargetServer -SqlCredential $TargetCredential -ErrorAction Stop
}
PROCESS {
	foreach ($sqlsrv in $SourceServer) {
		# Connect to Instance
		try {
			Write-Verbose -Message "Connecting to $sqlsrv"
			$server = Connect-DbaInstance -SqlInstance $sqlsrv -SqlCredential $SourceCredential -ErrorAction Stop 
		}
		catch {
			Write-Warning -Message "Failed to connect to $sqlsrv - $_"
			continue
		}
		
		# Get job history
		Write-Verbose -Message "Collecting job history from $sqlsrv"
		$jobHistory = Get-DbaAgentJobHistory -SqlInstance $server -NoJobSteps | 
			Where-Object { $_.RunStatus -in 1, 0 } | #Only Successful or Failed jobs
			Select-Object -Property @(
			@{ Name = 'server_name'; Expression = {$_.ComputerName}},
			@{ Name = 'instance_name'; Expression = {$_.SqlInstance}},
			@{ Name = 'job_name'; Expression = {$_.Job}},
			@{ Name = 'start_time'; Expression = {$_.RunDate}},
			@{ Name = 'duration_sec'; Expression = {$_.RunDuration}},
			@{ Name = 'run_status'; Expression = {$_.RunStatus}},
			@{ Name = 'server_type'; Expression = {"Sql Server"}}
		)
		#Insert into staging table	
		try {
			Write-Verbose -Message "Writing data from $sqlsrv to $tgtserver.$TargetDatabase"
			Out-DbaDataTable -InputObject $jobHistory | Write-DbaDataTable -SqlInstance $tgtserver -Database $TargetDatabase -Schema $schema -Table $tablename -EnableException -ErrorAction Stop
		}
		catch {
			Write-Warning -Message "Failed to write data to $tgtserver - $_"
			continue
		}
		finally {
			$server.ConnectionContext.Disconnect()
		}
	}
}

END {
	Write-Verbose -Message "Agent Job History finished: $((Get-Date).DateTime)"
	$tgtserver.ConnectionContext.Disconnect()
}