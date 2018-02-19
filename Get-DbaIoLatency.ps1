﻿function Get-DbaIoLatency {
    <#
        .SYNOPSIS
            Displays IO subsystem latency statistics from sys.dm_io_virtual_file_stats.  Works on SQL Server 2005 and above.
        
        .DESCRIPTION
                This command is based off of Paul Randal's post "Advanced SQL Server performance tuning"
        
                Returns both raw and aggregate information  
        
                Reference:  https://www.sqlskills.com/blogs/paul/how-to-examine-io-subsystem-latencies-from-within-sql-server/
        
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
            Tags: IOLatency 
        
            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
        
        .LINK
            https://dbatools.io/Get-DbaIoLatency
        
        .EXAMPLE
            Get-DbaIoLatency -SqlInstance sql2008, sqlserver2012
            Get IO subsystem latency statistics for servers sql2008 and sqlserver2012.
        
        .EXAMPLE
            $output = Get-DbaIoLatency -SqlInstance sql2008 | Select * | ConvertTo-DbaDataTable
                 
            Collects all IO subsystem latency statistics on server sql2008 into a Data Table.
        
        .EXAMPLE
            'sql2008','sqlserver2012' | Get-DbaIoLatency
            Get IO subsystem latency statistics for servers sql2008 and sqlserver2012 via pipline
        
        .EXAMPLE
            $cred = Get-Credential sqladmin
            Get-DbaIoLatency -SqlInstance sql2008 -SqlCredential $cred
        
            Connects using sqladmin credential and returns IO subsystem latency statistics from sql2008
    #>
    [CmdletBinding()]
    Param (
        [parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
        [Alias("ServerInstance", "SqlServer", "SqlServers")]
        [DbaInstance[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [int]$Threshold = 95,
        [switch][Alias('Silent')]$EnableException
    )

    BEGIN {

        $sql = "SELECT
                    [vfs].[database_id],
                    DB_NAME ([vfs].[database_id]) AS [DatabaseName],
                    [vfs].[file_id],
                    [mf].[physical_name],
                    [num_of_reads],
                    [io_stall_read_ms],
                    [num_of_writes],
                    [io_stall_write_ms],
                    [io_stall],
                    [num_of_bytes_read],
                    [num_of_bytes_written],
                    [sample_ms],
	                [size_on_disk_bytes],
                    [file_handle],
                    [ReadLatency] =
                        CASE WHEN [num_of_reads] = 0
                            THEN 0 
                            ELSE ([io_stall_read_ms] / [num_of_reads]) 
                        END,
                    [WriteLatency] =
                        CASE WHEN [num_of_writes] = 0
                            THEN 0 
                            ELSE ([io_stall_write_ms] / [num_of_writes]) 
                        END,
                    [Latency] =
                        CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
                            THEN 0 
                            ELSE ([io_stall] / ([num_of_reads] + [num_of_writes])) 
                        END,
                    [AvgBPerRead] =
                        CASE WHEN [num_of_reads] = 0
                            THEN 0 
                            ELSE ([num_of_bytes_read] / [num_of_reads]) 
                        END,
                    [AvgBPerWrite] =
                        CASE WHEN [num_of_writes] = 0
                            THEN 0 
                            ELSE ([num_of_bytes_written] / [num_of_writes]) 
                        END,
                    [AvgBPerTransfer] =
                        CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
                            THEN 0 
                            ELSE
                                (([num_of_bytes_read] + [num_of_bytes_written]) /
                                ([num_of_reads] + [num_of_writes])) 
                            END
                FROM sys.dm_io_virtual_file_stats (NULL,NULL) AS [vfs]
                INNER JOIN sys.master_files AS [mf]
                    ON [vfs].[database_id] = [mf].[database_id]
                    AND [vfs].[file_id] = [mf].[file_id];"
        
        Write-Message -Level Debug -Message $sql

        $excludeColumns = 'FileHandle', 'ReadLatency', 'WriteLatency', 'Latency', 'AvgBPerRead', 'AvgBPerWrite', 'AvgBPerTransfer'
    }

    process {
        foreach ($instance in $SqlInstance) {
            Write-Message -Level Verbose -Message "Connecting to $instance"

            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential -MinimumVersion 9
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
                    DatabaseId             = $row.database_id
                    DatabaseName           = $row.DatabaseName
                    FileId                 = $row.file_id
                    PhysicalName           = $row.physical_name
                    NumberOfReads          = $row.num_of_reads
                    IoStallRead            = $row.io_stall_read_ms
                    NumberOfwrites         = $row.num_of_writes
                    IoStallWrite           = $row.io_stall_write_ms
                    IoStall                = $row.io_stall
                    NumberOfBytesRead      = $row.num_of_bytes_read
                    NumberOfBytesWritten   = $row.num_of_bytes_written
                    SampleMilliseconds     = $row.sample_ms
                    SizeOnDiskBytes        = $row.num_of_bytes_written
                    FileHandle             = $row.file_handle
                    ReadLatency            = $row.ReadLatency
                    WriteLatency           = $row.WriteLatency
                    Latency                = $row.Latency
                    AvgBPerRead            = $row.AvgBPerRead
                    AvgBPerWrite           = $row.AvgBPerWrite
                    AvgBPerTransfer        = $row.AvgBPerTransfer
                } | Select-DefaultView -ExcludeProperty $excludeColumns
            }
        }
    }
}

