# InModuleScope resolves the module during Pester's discovery phase.
# Import it at file scope so it is already loaded when Pester discovers those
# containers. Keep the BeforeAll import as well so the module is available in
# the test execution phase.
$modulePath = Join-Path $PSScriptRoot '..\src\NodeNpmDoctor\NodeNpmDoctor.psm1'
Import-Module -Name $modulePath -Force

BeforeAll {
    # Pester executes BeforeAll in its own setup scope. Rebuild the path here
    # instead of relying on the file-scope $modulePath variable.
    $modulePath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\src\NodeNpmDoctor\NodeNpmDoctor.psm1'))
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        throw "NodeNpmDoctor module was not found at '$modulePath'."
    }
    Import-Module -Name $modulePath -Force -ErrorAction Stop
}

Describe 'NodeNpmDoctor status classification' {
    InModuleScope NodeNpmDoctor {
        It 'returns Available when the executable is on PATH' {
            Get-NodeNpmDoctorStatus -FoundOnPath $true -FoundElsewhere $true | Should -Be 'Available'
        }

        It 'returns FoundButNotOnPath when only a known location contains the executable' {
            Get-NodeNpmDoctorStatus -FoundOnPath $false -FoundElsewhere $true | Should -Be 'FoundButNotOnPath'
        }

        It 'returns NotFound when no executable is found' {
            Get-NodeNpmDoctorStatus -FoundOnPath $false -FoundElsewhere $false | Should -Be 'NotFound'
        }
    }
}

Describe 'NodeNpmDoctor recommendations' {
    InModuleScope NodeNpmDoctor {
        It 'recommends installation when Node.js is missing' {
            $recommendations = @(Get-NodeNpmDoctorRecommendation -NodeStatus 'NotFound' -NpmStatus 'NotFound' -NodeVersionOk $false -NpmVersionOk $false)
            ($recommendations -join ' ') | Should -Match 'nodejs.org'
        }

        It 'does not claim to change PATH when an executable is outside PATH' {
            $recommendations = @(Get-NodeNpmDoctorRecommendation -NodeStatus 'FoundButNotOnPath' -NpmStatus 'FoundButNotOnPath' -NodeVersionOk $true -NpmVersionOk $true)
            ($recommendations -join ' ') | Should -Match 'does not change PATH'
        }

        It 'reports a healthy setup without unnecessary remediation' {
            $recommendations = @(Get-NodeNpmDoctorRecommendation -NodeStatus 'Available' -NpmStatus 'Available' -NodeVersionOk $true -NpmVersionOk $true)
            $recommendations.Count | Should -Be 1
            $recommendations[0] | Should -Match 'found on PATH'
        }
    }
}

Describe 'NodeNpmDoctor read-only integration' {
    It 'returns a structured report and does not modify PATH' {
        $pathBefore = $env:Path
        $result = Invoke-NodeNpmDoctor

        $result.SchemaVersion | Should -Be '1.0'
        $result.ReadOnly | Should -BeTrue
        $result.Node.Status | Should -BeIn @('Available', 'FoundButNotOnPath', 'NotFound')
        $result.Npm.Status | Should -BeIn @('Available', 'FoundButNotOnPath', 'NotFound')
        $result.Recommendations.Count | Should -BeGreaterThan 0
        $env:Path | Should -BeExactly $pathBefore
    }
}


Describe 'NodeNpmDoctor CLI output' {
    It 'emits human-readable output on the success stream' {
        $entryPoint = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\scripts\NodeNpmDoctor.ps1'))
        $output = @(& $entryPoint) -join [System.Environment]::NewLine

        $output | Should -Match 'Node.js & npm Doctor'
        $output | Should -Match 'This diagnostic does not modify PATH'
    }

    It 'emits valid JSON when requested' {
        $entryPoint = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\scripts\NodeNpmDoctor.ps1'))
        $json = @(& $entryPoint -Json) -join [System.Environment]::NewLine
        $report = $json | ConvertFrom-Json -ErrorAction Stop

        $report.SchemaVersion | Should -Be '1.0'
        $report.ReadOnly | Should -BeTrue
    }
}
