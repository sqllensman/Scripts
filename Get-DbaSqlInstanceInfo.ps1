#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function Get-DbaSqlInstanceInfo {
    <#
    .SYNOPSIS
        Gets SQL Instance information of one or more instance(s) of SQL Server in tabular form.

    .DESCRIPTION
        The Get-DbaSqlInstance command gets SQL Instance information from the instance and returns as an object.

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
        Tags: SQLInstance

        Website: https://dbatools.io
        Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
        License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
            Website: https: //dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: GNU GPL v3 https: //opensource.org/licenses/GPL-3.0

        .LINK
            https://dbatools.io/Get-DbaSqlInstanceInfo

        .EXAMPLE
            Get-DbaSqlInstanceInfo -SqlInstance localhost

            Returns SQL Instance information on the local default SQL Server instance

        .EXAMPLE
            Get-DbaSqlInstanceInfo -SqlInstance sql2, sql4\sqlexpress

            Returns SQL Instance information on default instance on sql2 and sqlexpress instance on sql4

        .EXAMPLE
            'sql2008','sql2012' | Get-DbaSqlInstanceInfo

            Returns SQL Instance information on sql2008 and sql2012

        .EXAMPLE
            $cred = Get-Credential sqladmin
            Get-DbaSqlInstanceInfo -SqlInstance sql2008 -SqlCredential $cred

            Connects using sqladmin credential and returns SQL Instance information from sql2008
#>
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param (
        [parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [switch][Alias('Silent')]$EnableException
    )
    BEGIN {
        $excludeColumns = 'IsHADREnabled', 'HADREndpointPort', 'AGs', '$AGListener'
    }

    process {
        foreach ($instance in $SqlInstance) {
            Write-Message -Level Verbose -Message "Connecting to $instance"

            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            try {
                # Pre-process
                $VersionMajor = $server.VersionMajor
                $VersionMinor = $server.VersionMinor
                if ($VersionMajor -eq 8)
                { $Version = 'SQL 2000' }
                if ($VersionMajor -eq 9)
                { $Version = 'SQL 2005' }
                if ($VersionMajor -eq 10 -and $VersionMinor -eq 0)
                { $Version = 'SQL 2008' }
                if ($VersionMajor -eq 10 -and $VersionMinor -eq 50)
                { $Version = 'SQL 2008 R2' }
                if ($VersionMajor -eq 11)
                { $Version = 'SQL 2012' }
                if ($VersionMajor -eq 12)
                { $Version = 'SQL 2014' }
                if ($VersionMajor -eq 13)
                { $Version = 'SQL 2016' }
                if ($VersionMajor -eq 14)
                { $Version = 'SQL 2017' }		
            
                if ($server.IsHadrEnabled -eq $True)
                {
	                $IsHADREnabled = $True
	                $AGs = $server.AvailabilityGroups | Select-Object Name -ExpandProperty Name | Out-String
	                $Expression = @{ Name = 'ListenerPort'; Expression = { $_.Name + ',' + $_.PortNumber } }
	                $AGListener = $server.AvailabilityGroups.AvailabilityGroupListeners | Select-Object $Expression | Select-Object ListenerPort -ExpandProperty ListenerPort
                }
                else
                {
	                $IsHADREnabled = $false
	                $AGs = 'None'
	                $AGListener = 'None'
                }
		    
                if ($server.version.Major -eq 8) # Check for SQL 2000 boxes
                {
	                $HADREndpointPort = '0'
                }
                else
                {
	                $HADREndpointPort = ($server.Endpoints | Where-Object{ $_.EndpointType -eq 'DatabaseMirroring' }).Protocol.Tcp.ListenerPort
                }
                if (!$HADREndpointPort)
                {
	                $HADREndpointPort = '0'
                }
            
               [PSCustomObject]@{
                    ComputerName                    = $server.NetName
                    InstanceName                    = $server.ServiceName
                    SqlInstance                     = $server.DomainInstanceName             
                    VersionString                   = $server.VersionString
                    VersionName                     = $Version
                    Edition                         = $server.Edition
                    ServicePack                     = $server.ProductLevel
                    ServerType                      = $server.ServerType
                    Collation                       = $server.Collation
                    IsCaseSensitive                 = $server.IsCaseSensitive
                    IsHADREnabled                   = $IsHADREnabled
                    HADREndpointPort                = $HADREndpointPort        
                    IsSQLClustered                  = $server.IsClustered
                    ClusterName                     = $server.ClusterName
                    ClusterQuorumstate              = $server.ClusterQuorumState
                    ClusterQuorumType               = $server.ClusterQuorumType
                    AGs                             = $AGs
                    AGListener                      = $AGListener
                    SQLService                      = $server.ServiceName
                    SQLServiceAccount               = $server.ServiceAccount
                    SQLServiceStartMode             = $server.ServiceStartMode
                    SQLAgentServiceAccount          = $server.JobServer.ServiceAccount
                    SQLAgentServiceStartMode        = $server.JobServer.ServiceStartMode
                    BrowserAccount                  = $server.BrowserServiceAccount
                    BrowserStartMode                = $server.BrowserStartMode
                    DefaultFile                     = $server.DefaultFile
                    DefaultLog                      = $server.DefaultLog
                    BackupDirectory                 = $server.BackupDirectory;
                    InstallDataDirectory            = $server.InstallDataDirectory
                    InstallSharedDirectory          = $server.InstallSharedDirectory
                    MasterDBPath                    = $server.MasterDBPath
                    MasterDBLogPath                 = $server.MasterDBLogPath
                    ErrorLogPath                    = $server.ErrorLogPath        
                    IsFullTextInstalled             = $server.IsFullTextInstalled
                    LinkedServer                    = $server.LinkedServers.Count
                    LoginMode                       = $server.LoginMode
                    TcpEnabled                      = $server.TcpEnabled
                    NamedPipesEnabled               = $server.NamedPipesEnabled
                    C2AuditMode                     = $server.Configuration.C2AuditMode.RunValue
                    CommonCriteriaComplianceEnabled = $server.Configuration.CommonCriteriaComplianceEnabled.RunValue
                    CostThresholdForParallelism     = $server.Configuration.CostThresholdForParallelism.RunValue
                    DBMailEnabled                   = $server.Configuration.DatabaseMailEnabled.RunValue
                    DefaultBackupCompression        = $server.Configuration.DefaultBackupCompression.RunValue
                    FillFactor                      = $server.Configuration.FillFactor.RunValue
                    MaxDegreeOfParallelism          = $server.Configuration.MaxDegreeOfParallelism.RunValue
                    MaxMem                          = $server.Configuration.MaxServerMemory.RunValue
                    MinMem                          = $server.Configuration.MinServerMemory.RunValue
                    OptimizeAdhocWorkloads          = $server.Configuration.OptimizeAdhocWorkloads.RunValue
                    RemoteDacEnabled                = $server.Configuration.RemoteDacConnectionsEnabled.RunValue
                    XPCmdShellEnabled               = $server.Configuration.XPCmdShellEnabled.RunValue  
                } | Select-DefaultView -ExcludeProperty $excludeColumns
		    }
		    catch {		
                Stop-Function -Message "Issue gathering SQL Instance information for $instance." -Target $instance -ErrorRecord $_ -Continue
		    } 
        }
    }
}