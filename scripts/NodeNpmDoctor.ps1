[CmdletBinding()]
param(
    [switch] $Json,
    [switch] $FailOnMissing
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot '..\src\NodeNpmDoctor\NodeNpmDoctor.psm1'
Import-Module -Name $modulePath -Force

$result = Invoke-NodeNpmDoctor

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    # Emit one human-readable string on the success stream. This keeps the CLI
    # output visible in a terminal while allowing callers to capture or redirect it.
    $outputLines = [System.Collections.Generic.List[string]]::new()
    $outputLines.Add('Node.js & npm Doctor')
    $outputLines.Add('====================')
    $outputLines.Add(("Overall status : {0}" -f $(if ($result.Ready) { 'READY' } else { 'CHECK REQUIRED' })))
    $outputLines.Add('')
    $outputLines.Add('Node.js')
    $outputLines.Add(("  Status       : {0}" -f $result.Node.Status))
    $outputLines.Add(("  Version      : {0}" -f $(if ($result.Node.Version) { $result.Node.Version } else { 'Unavailable' })))
    $outputLines.Add(("  Path         : {0}" -f $(if ($result.Node.Path) { $result.Node.Path } else { 'Not found' })))
    if ($result.Node.Error) { $outputLines.Add(("  Error        : {0}" -f $result.Node.Error)) }
    $outputLines.Add('')
    $outputLines.Add('npm')
    $outputLines.Add(("  Status       : {0}" -f $result.Npm.Status))
    $outputLines.Add(("  Version      : {0}" -f $(if ($result.Npm.Version) { $result.Npm.Version } else { 'Unavailable' })))
    $outputLines.Add(("  Path         : {0}" -f $(if ($result.Npm.Path) { $result.Npm.Path } else { 'Not found' })))
    if ($result.Npm.Error) { $outputLines.Add(("  Error        : {0}" -f $result.Npm.Error)) }
    $outputLines.Add('')
    $outputLines.Add('Recommendations')
    foreach ($recommendation in $result.Recommendations) {
        $outputLines.Add(("  - {0}" -f $recommendation))
    }
    $outputLines.Add('')
    $outputLines.Add('This diagnostic does not modify PATH, install software, or change system settings.')
    $outputLines -join [System.Environment]::NewLine
}

if ($FailOnMissing -and -not $result.Ready) {
    throw 'Node.js/npm checks did not pass. Review the diagnostic output above.'
}
