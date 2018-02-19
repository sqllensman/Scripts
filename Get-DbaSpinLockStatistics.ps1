function Get-DbaSpinLockStatistics {
    <#
        .SYNOPSIS
            Displays information from sys.dm_os_spinlock_stats.  Works on SQL Server 2008 and above.
        
        .DESCRIPTION
                This command is based off of Paul Randal's post "Advanced SQL Server performance tuning"
        
                Returns:
                        SpinLockName
                        Collisions
                        Spins
                        SpinsPerCollision
                        SleepTime
                        Backoffs  
        
                Reference:  https://www.sqlskills.com/blogs/paul/advanced-performance-troubleshooting-waits-latches-spinlocks/
        
        .PARAMETER SqlInstance
            Allows you to specify a comma separated list of servers to query.
        
        .PARAMETER SqlCredential
            Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:
            $cred = Get-Credential, this pass this $cred to the param.
        
            Windows Authentication will be used if DestinationSqlCredential is not specified. To connect as a different Windows user, run PowerShell as that user.
        
        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
        
        .NOTES
            Author: Patrick Flynn, @sqllensman
            Tags: SpinLockStatistics
        
            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
        
        .LINK
            https://dbatools.io/Get-DbaIdentityUsage
        
        .EXAMPLE
            Get-DbaSpinLockStatistics -SqlInstance sql2008, sqlserver2012
            Get SpinLock Statistics for servers sql2008 and sqlserver2012.
        
        .EXAMPLE
            $output = Get-DbaSpinLockStatistics -SqlInstance sql2008 | Select * | ConvertTo-DbaDataTable
                 
            Collects all SpinLock Statistics on server sql2008 into a Data Table.
        
        .EXAMPLE
            'sql2008','sqlserver2012' | Get-DbaSpinLockStatistics
            Get SpinLock Statistics for servers sql2008 and sqlserver2012 via pipline
        
        .EXAMPLE
            $cred = Get-Credential sqladmin
            Get-DbaSpinLockStatistics -SqlInstance sql2008 -SqlCredential $cred
        
            Connects using sqladmin credential and returns SpinLock Statistics from sql2008
    #>
    [CmdletBinding()]
    Param (
        [parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
        [Alias("ServerInstance", "SqlServer", "SqlServers")]
        [DbaInstance[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [switch][Alias('Silent')]$EnableException
    )

    BEGIN {

        $sql = "SELECT 
                	name, 
                	collisions, 
                	spins, 
                	spins_per_collision, 
                	sleep_time, 
                	backoffs
                FROM sys.dm_os_spinlock_stats;"
        
        Write-Message -Level Debug -Message $sql
    }

    process {
        foreach ($instance in $SqlInstance) {
            Write-Message -Level Verbose -Message "Connecting to $instance"

            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential -MinimumVersion 10
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }
            Write-Message -Level Verbose -Message "Connected to $instance"

            foreach ($row in $server.Query($sql)) {
 
                [PSCustomObject]@{
                    ComputerName           = $server.NetName
                    InstanceName           = $server.ServiceName
                    SqlInstance            = $server.DomainInstanceName
                    SpinLockName           = $row.name
                    Collisions             = $row.collisions
                    Spins                  = $row.spins
                    SpinsPerCollision      = $row.spins_per_collision
                    SleepTime              = $row.sleep_time
                    Backoffs               = $row.backoffs
                } 
            }
        }
    }
}