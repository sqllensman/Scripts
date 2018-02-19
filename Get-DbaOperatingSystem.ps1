function Get-DbaOperatingSystem {
    <#
        .SYNOPSIS
            Gets operating system information from the server.

        .DESCRIPTION
            Gets operating system information from the server and returns as an object.

        .PARAMETER ComputerName
            Target computer(s). If no computer name is specified, the local computer is targeted

        .PARAMETER Credential
            Alternate credential object to use for accessing the target computer(s).

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: ServerInfo, OperatingSystem
            Author: Shawn Melton (@wsmelton | http://blog.wsmelton.info)

            Website: https: //dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: GNU GPL v3 https: //opensource.org/licenses/GPL-3.0

        .LINK
            https://dbatools.io/Get-DbaOperatingSystem

        .EXAMPLE
            Get-DbaOperatingSystem

            Returns information about the local computer's operating system

        .EXAMPLE
            Get-DbaOperatingSystem -ComputerName sql2016

            Returns information about the sql2016's operating system
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [Alias("cn", "host", "Server")]
        [DbaInstanceParameter[]]$ComputerName = $env:COMPUTERNAME,
        [PSCredential]$Credential,
        [switch][Alias('Silent')]$EnableException
    )
    process {
        foreach ($computer in $ComputerName) {
            Write-Message -Level Verbose -Message "Connecting to $computer"
            $server = Resolve-DbaNetworkName -ComputerName $computer.ComputerName -Credential $Credential

            $computerResolved = $server.FullComputerName

            if (!$computerResolved) {
                Write-Message -Level Warning -Message "Unable to resolve hostname of $computer. Skipping."
                continue
            }

            Try {
                $TestWS = Test-WSMan -ComputerName $computerResolved -ErrorAction SilentlyContinue
            }
            Catch {
                Write-Message -Level Warning -Message "Remoting not availablle on $computer. Skipping checks"
                $TestWS = $null
            }


            $splatDbaCmObject = @{
                ComputerName   = $computerResolved
                EnableException = $true
            }
            if ($Credential) { $splatDbaCmObject["Credential"] = $Credential }

            if ($TestWS) {
                try {
                    $psVersion = Invoke-Command2 -ComputerName $computerResolved -Credential $Credential -ScriptBlock { $PSVersionTable.PSVersion }
                }
                catch {
                    Write-Message -Level Warning -Message "PowerShell Version information not available on $computer."
                    $psVersion = 'Unavailable'
                }
            }
            else {
                $psVersion = 'Unknown'
            }


            try {
                $os = Get-DbaCmObject @splatDbaCmObject -ClassName Win32_OperatingSystem
            }
            catch {
                Stop-Function -Message "Failure collecting OS information on $computer" -Target $computer -ErrorRecord $_
                return
            }

            try {
                $tz = Get-DbaCmObject @splatDbaCmObject -ClassName Win32_TimeZone
            }
            catch {
                Stop-Function -Message "Failure collecting TimeZone information on $computer" -Target $computer -ErrorRecord $_
                return
            }

            try {
                $powerPlan = Get-DbaCmObject @splatDbaCmObject -ClassName Win32_PowerPlan -Namespace "root\cimv2\power"  | Select-Object ElementName, InstanceId, IsActive
            }
            catch {
                Write-Message -Level Warning -Message "Power plan information not available on $computer."
                $powerPlan = $null
            }

            if ($powerPlan) {
                $activePowerPlan = ($powerPlan | Where-Object IsActive).ElementName -join ','
            }
            else {
                $activePowerPlan = 'Not Avaliable'
            }

            if ($psVersion) {
                $PowerShellVersion = "$($psVersion.Major).$($psVersion.Minor)"
            }
            else {
                $PowerShellVersion = ''
            }

            $language = Get-Language $os.OSLanguage

            [PSCustomObject]@{
                ComputerName             = $computerResolved
                Manufacturer             = $os.Manufacturer
                Organization             = $os.Organization
                Architecture             = $os.OSArchitecture
                Version                  = $os.Version
                Build                    = $os.BuildNumber
                OSVersion                = $os.caption;
                SPVersion                = $os.servicepackmajorversion;
                InstallDate              = [DbaDateTime]$os.InstallDate
                LastBootTime             = [DbaDateTime]$os.LastBootUpTime
                LocalDateTime            = [DbaDateTime]$os.LocalDateTime
                PowerShellVersion        = $PowerShellVersion
                TimeZone                 = $tz.Caption
                TimeZoneStandard         = $tz.StandardName
                TimeZoneDaylight         = $tz.DaylightName
                BootDevice               = $os.BootDevice
                SystemDevice             = $os.SystemDevice
                SystemDrive              = $os.SystemDrive
                WindowsDirectory         = $os.WindowsDirectory
                PagingFileSize           = $os.SizeStoredInPagingFiles
                TotalVisibleMemory       = [DbaSize]($os.TotalVisibleMemorySize * 1024)
                FreePhysicalMemory       = [DbaSize]($os.FreePhysicalMemory * 1024)
                TotalVirtualMemory       = [DbaSize]($os.TotalVirtualMemorySize * 1024)
                FreeVirtualMemory        = [DbaSize]($os.FreeVirtualMemory * 1024)
                ActivePowerPlan          = $activePowerPlan
                Status                   = $os.Status
                Language                 = $language.Name
                LanguageId               = $language.LCID
                LanguageKeyboardLayoutId = $language.KeyboardLayoutId
                LanguageTwoLetter        = $language.TwoLetterISOLanguageName
                LanguageThreeLetter      = $language.ThreeLetterISOLanguageName
                LanguageAlias            = $language.DisplayName
                LanguageNative           = $language.NativeName

                CodeSet                  = $os.CodeSet
                CountryCode              = $os.CountryCode
                Locale                   = $os.Locale

            } | Select-DefaultView -ExcludeProperty CodeSet, CountryCode, Locale, LanguageAlias
        }
    }
}