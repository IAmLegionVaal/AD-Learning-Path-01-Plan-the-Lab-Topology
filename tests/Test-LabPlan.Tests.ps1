#requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Test-LabPlan.ps1' {
    BeforeAll {
        $repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
        $scriptPath = Join-Path $repositoryRoot 'scripts/Test-LabPlan.ps1'
        $examplePath = Join-Path $repositoryRoot 'lab-plan.example.json'
        $powerShellExecutable = (Get-Process -Id $PID).Path
    }

    It 'accepts the supplied example plan' {
        & $powerShellExecutable `
            -NoLogo `
            -NoProfile `
            -File $scriptPath `
            -Path $examplePath

        $LASTEXITCODE | Should -Be 0
    }

    It 'rejects duplicate IPv4 addresses' {
        $plan = Get-Content -LiteralPath $examplePath -Raw -Encoding UTF8 |
            ConvertFrom-Json

        $plan.systems[1].ipv4Address = $plan.systems[0].ipv4Address
        $invalidPath = Join-Path $TestDrive 'duplicate-address.json'

        $plan |
            ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $invalidPath -Encoding UTF8

        & $powerShellExecutable `
            -NoLogo `
            -NoProfile `
            -File $scriptPath `
            -Path $invalidPath

        $LASTEXITCODE | Should -Be 1
    }

    It 'rejects a domain controller with dynamic addressing' {
        $plan = Get-Content -LiteralPath $examplePath -Raw -Encoding UTF8 |
            ConvertFrom-Json

        $plan.systems[0].staticAddress = $false
        $invalidPath = Join-Path $TestDrive 'dynamic-domain-controller.json'

        $plan |
            ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $invalidPath -Encoding UTF8

        & $powerShellExecutable `
            -NoLogo `
            -NoProfile `
            -File $scriptPath `
            -Path $invalidPath

        $LASTEXITCODE | Should -Be 1
    }

    It 'rejects a single-label forest DNS name' {
        $plan = Get-Content -LiteralPath $examplePath -Raw -Encoding UTF8 |
            ConvertFrom-Json

        $plan.forest.dnsName = 'CORP'
        $invalidPath = Join-Path $TestDrive 'single-label-domain.json'

        $plan |
            ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $invalidPath -Encoding UTF8

        & $powerShellExecutable `
            -NoLogo `
            -NoProfile `
            -File $scriptPath `
            -Path $invalidPath

        $LASTEXITCODE | Should -Be 1
    }
}
