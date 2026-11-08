Set-StrictMode -Version Latest

function Get-NodeNpmDoctorStatus {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [bool] $FoundOnPath,
        [Parameter(Mandatory)] [bool] $FoundElsewhere
    )

    if ($FoundOnPath) { return 'Available' }
    if ($FoundElsewhere) { return 'FoundButNotOnPath' }
    return 'NotFound'
}

function Get-NodeNpmDoctorCommandPath {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string[]] $Name)

    foreach ($commandName in $Name) {
        $commands = @(Get-Command -Name $commandName -All -ErrorAction SilentlyContinue)
        foreach ($command in $commands) {
            if ($command.CommandType -ne 'Application') { continue }

            $candidate = $null
            if ($command.Path) {
                $candidate = $command.Path
            } elseif ($command.Source) {
                $candidate = $command.Source
            }

            if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                return [System.IO.Path]::GetFullPath($candidate)
            }
        }
    }

    return $null
}

function Get-NodeNpmDoctorKnownFile {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $directories = [System.Collections.Generic.List[string]]::new()

    if ($env:ProgramFiles) {
        $directories.Add((Join-Path $env:ProgramFiles 'nodejs'))
    }
    if (${env:ProgramFiles(x86)}) {
        $directories.Add((Join-Path ${env:ProgramFiles(x86)} 'nodejs'))
    }
    if ($env:LOCALAPPDATA) {
        $directories.Add((Join-Path $env:LOCALAPPDATA 'Programs\nodejs'))
    }
    if ($env:NVM_SYMLINK) {
        $directories.Add($env:NVM_SYMLINK)
    }
    if ($env:VOLTA_HOME) {
        $directories.Add((Join-Path $env:VOLTA_HOME 'bin'))
    }

    $files = [System.Collections.Generic.List[object]]::new()
    foreach ($directory in ($directories | Select-Object -Unique)) {
        $files.Add([pscustomobject]@{ Name = 'Node'; Path = Join-Path $directory 'node.exe' })
        $files.Add([pscustomobject]@{ Name = 'npm'; Path = Join-Path $directory 'npm.cmd' })
        $files.Add([pscustomobject]@{ Name = 'npm'; Path = Join-Path $directory 'npm.exe' })
    }

    return @($files)
}

function Resolve-NodeNpmDoctorCommand {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [ValidateSet('Node', 'npm')] [string] $Name)

    if ($Name -eq 'Node') {
        $pathCommand = Get-NodeNpmDoctorCommandPath -Name @('node.exe', 'node')
    } else {
        # Prefer npm.cmd on Windows. Avoid selecting npm.ps1, which may be
        # blocked by the caller's execution policy.
        $pathCommand = Get-NodeNpmDoctorCommandPath -Name @('npm.cmd', 'npm.exe', 'npm')
    }

    if ($pathCommand) {
        return [pscustomobject]@{
            Name = $Name
            Path = $pathCommand
            FoundOnPath = $true
            FoundElsewhere = $true
            Source = 'PATH'
        }
    }

    $knownFiles = @(Get-NodeNpmDoctorKnownFile | Where-Object { $_.Name -eq $Name })
    foreach ($knownFile in $knownFiles) {
        if (Test-Path -LiteralPath $knownFile.Path -PathType Leaf) {
            return [pscustomobject]@{
                Name = $Name
                Path = [System.IO.Path]::GetFullPath($knownFile.Path)
                FoundOnPath = $false
                FoundElsewhere = $true
                Source = 'KnownInstallLocation'
            }
        }
    }

    return [pscustomobject]@{
        Name = $Name
        Path = $null
        FoundOnPath = $false
        FoundElsewhere = $false
        Source = 'NotFound'
    }
}

function Get-NodeNpmDoctorVersion {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    try {
        $output = @(& $Path '--version' 2>&1)
        $exitCode = $LASTEXITCODE
        $text = (($output | ForEach-Object { [string]$_ }) -join "`n").Trim()

        if ($null -eq $exitCode) { $exitCode = 0 }
        if ($exitCode -ne 0) {
            return [pscustomobject]@{ Value = $null; Success = $false; Error = "Command exited with code $exitCode." }
        }
        if ([string]::IsNullOrWhiteSpace($text)) {
            return [pscustomobject]@{ Value = $null; Success = $false; Error = 'The command returned no version text.' }
        }

        return [pscustomobject]@{ Value = $text; Success = $true; Error = $null }
    } catch {
        return [pscustomobject]@{ Value = $null; Success = $false; Error = $_.Exception.Message }
    }
}

function Get-NodeNpmDoctorRecommendation {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $NodeStatus,
        [Parameter(Mandatory)] [string] $NpmStatus,
        [Parameter(Mandatory)] [bool] $NodeVersionOk,
        [Parameter(Mandatory)] [bool] $NpmVersionOk
    )

    $recommendations = [System.Collections.Generic.List[string]]::new()

    foreach ($item in @(@{ Name = 'Node.js'; Status = $NodeStatus }, @{ Name = 'npm'; Status = $NpmStatus })) {
        if ($item.Status -eq 'NotFound') {
            $recommendations.Add("$($item.Name) was not found. Install the current Node.js LTS release from https://nodejs.org/en/download and reopen the terminal.")
        } elseif ($item.Status -eq 'FoundButNotOnPath') {
            $recommendations.Add("$($item.Name) exists in a recognized install directory but is not on PATH. Add its directory to your user PATH, then reopen the terminal. This tool does not change PATH.")
        }
    }

    if ($NodeStatus -eq 'Available' -and -not $NodeVersionOk) {
        $recommendations.Add('Node.js was found on PATH but its version command failed. Check the executable and terminal error output.')
    }
    if ($NpmStatus -eq 'Available' -and -not $NpmVersionOk) {
        $recommendations.Add('npm was found on PATH but its version command failed. Check the npm installation and terminal execution policy.')
    }
    if ($recommendations.Count -eq 0) {
        $recommendations.Add('Node.js and npm were found on PATH and both version commands completed successfully.')
    }

    return @($recommendations)
}

function Invoke-NodeNpmDoctor {
    <#
    .SYNOPSIS
        Diagnoses whether Node.js and npm are installed and available on PATH.

    .DESCRIPTION
        Performs read-only discovery of Node.js and npm executables, checks their
        version commands, and returns a structured diagnostic report. The function
        does not modify PATH, install software, change execution policy, or write
        diagnostic files.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .EXAMPLE
        Invoke-NodeNpmDoctor

        Returns a structured report describing Node.js and npm availability.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $node = Resolve-NodeNpmDoctorCommand -Name 'Node'
    $npm = Resolve-NodeNpmDoctorCommand -Name 'npm'

    $nodeStatus = Get-NodeNpmDoctorStatus -FoundOnPath $node.FoundOnPath -FoundElsewhere $node.FoundElsewhere
    $npmStatus = Get-NodeNpmDoctorStatus -FoundOnPath $npm.FoundOnPath -FoundElsewhere $npm.FoundElsewhere

    $nodeVersion = if ($node.Path) { Get-NodeNpmDoctorVersion -Path $node.Path } else { [pscustomobject]@{ Value = $null; Success = $false; Error = 'Executable not found.' } }
    $npmVersion = if ($npm.Path) { Get-NodeNpmDoctorVersion -Path $npm.Path } else { [pscustomobject]@{ Value = $null; Success = $false; Error = 'Executable not found.' } }

    $ready = ($nodeStatus -eq 'Available' -and $npmStatus -eq 'Available' -and $nodeVersion.Success -and $npmVersion.Success)
    $recommendations = @(Get-NodeNpmDoctorRecommendation -NodeStatus $nodeStatus -NpmStatus $npmStatus -NodeVersionOk $nodeVersion.Success -NpmVersionOk $npmVersion.Success)

    return [pscustomobject]@{
        SchemaVersion = '1.0'
        GeneratedAtUtc = [DateTime]::UtcNow.ToString('o')
        Ready = [bool]$ready
        OperatingSystem = [System.Environment]::OSVersion.VersionString
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Node = [pscustomobject]@{
            Status = $nodeStatus
            Path = $node.Path
            DiscoverySource = $node.Source
            Version = $nodeVersion.Value
            VersionCheckSucceeded = [bool]$nodeVersion.Success
            Error = $nodeVersion.Error
        }
        Npm = [pscustomobject]@{
            Status = $npmStatus
            Path = $npm.Path
            DiscoverySource = $npm.Source
            Version = $npmVersion.Value
            VersionCheckSucceeded = [bool]$npmVersion.Success
            Error = $npmVersion.Error
        }
        Recommendations = $recommendations
        ReadOnly = $true
    }
}

Export-ModuleMember -Function Invoke-NodeNpmDoctor
