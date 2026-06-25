#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter()]
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-IPv4UInt32 {
    [CmdletBinding()]
    [OutputType([uint32])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Address
    )

    $parsedAddress = $null
    if (-not [System.Net.IPAddress]::TryParse($Address, [ref]$parsedAddress)) {
        throw "'$Address' is not a valid IP address."
    }

    $bytes = $parsedAddress.GetAddressBytes()
    if ($bytes.Count -ne 4) {
        throw "'$Address' is not an IPv4 address."
    }

    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function Get-IPv4MaskUInt32 {
    [CmdletBinding()]
    [OutputType([uint32])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 32)]
        [int]$PrefixLength
    )

    if ($PrefixLength -eq 0) {
        return [uint32]0
    }

    $allBits = [uint64]4294967295
    $shift = 32 - $PrefixLength
    return [uint32](($allBits -shl $shift) -band $allBits)
}

function Test-IPv4InPrefix {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address,

        [Parameter(Mandatory = $true)]
        [string]$Prefix
    )

    $parts = $Prefix.Split('/')
    if ($parts.Count -ne 2) {
        throw "Prefix '$Prefix' must use CIDR notation, for example 10.10.10.0/24."
    }

    $networkAddress = ConvertTo-IPv4UInt32 -Address $parts[0]
    $candidateAddress = ConvertTo-IPv4UInt32 -Address $Address
    $prefixLength = [int]$parts[1]
    $mask = Get-IPv4MaskUInt32 -PrefixLength $prefixLength

    return (($networkAddress -band $mask) -eq ($candidateAddress -band $mask))
}

function New-ValidationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Check,

        [Parameter(Mandatory = $true)]
        [bool]$Passed,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    [pscustomobject]@{
        Check   = $Check
        Passed  = $Passed
        Message = $Message
    }
}

function Invoke-LabPlanValidation {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PlanPath
    )

    $resolvedPath = Resolve-Path -LiteralPath $PlanPath -ErrorAction Stop
    $rawContent = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8

    try {
        $plan = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "The lab plan is not valid JSON: $($_.Exception.Message)"
    }

    $results = [System.Collections.Generic.List[object]]::new()

    $requiredTopLevelProperties = @('schemaVersion', 'labName', 'forest', 'network', 'host', 'systems')
    foreach ($propertyName in $requiredTopLevelProperties) {
        $exists = $null -ne $plan.PSObject.Properties[$propertyName]
        $results.Add((New-ValidationResult `
            -Check "Required property: $propertyName" `
            -Passed $exists `
            -Message $(if ($exists) { 'Present.' } else { 'Missing.' })))
    }

    if (@($results | Where-Object { -not $_.Passed }).Count -gt 0) {
        return $results
    }

    $dnsName = [string]$plan.forest.dnsName
    $validDnsName = $dnsName -match '^(?=.{1,253}$)(?!-)(?:[a-zA-Z0-9-]{1,63}\.)+[a-zA-Z0-9-]{2,63}$'
    $results.Add((New-ValidationResult `
        -Check 'Forest DNS name' `
        -Passed $validDnsName `
        -Message $(if ($validDnsName) { "Valid DNS name: $dnsName" } else { "Invalid or single-label DNS name: $dnsName" })))

    $netbiosName = [string]$plan.forest.netbiosName
    $validNetbiosName = $netbiosName -match '^[A-Z0-9][A-Z0-9-]{0,14}$'
    $results.Add((New-ValidationResult `
        -Check 'NetBIOS name' `
        -Passed $validNetbiosName `
        -Message $(if ($validNetbiosName) { "Valid NetBIOS name: $netbiosName" } else { 'Use 1-15 uppercase letters, digits, or hyphens.' })))

    $systems = @($plan.systems)
    $hasSystems = $systems.Count -gt 0
    $results.Add((New-ValidationResult `
        -Check 'Planned systems' `
        -Passed $hasSystems `
        -Message $(if ($hasSystems) { "$($systems.Count) systems defined." } else { 'No systems are defined.' })))

    if (-not $hasSystems) {
        return $results
    }

    $duplicateNames = @(
        $systems |
            Group-Object -Property name |
            Where-Object Count -gt 1 |
            Select-Object -ExpandProperty Name
    )

    $results.Add((New-ValidationResult `
        -Check 'Unique computer names' `
        -Passed ($duplicateNames.Count -eq 0) `
        -Message $(if ($duplicateNames.Count -eq 0) { 'All computer names are unique.' } else { "Duplicates: $($duplicateNames -join ', ')" })))

    $duplicateAddresses = @(
        $systems |
            Group-Object -Property ipv4Address |
            Where-Object Count -gt 1 |
            Select-Object -ExpandProperty Name
    )

    $results.Add((New-ValidationResult `
        -Check 'Unique IPv4 addresses' `
        -Passed ($duplicateAddresses.Count -eq 0) `
        -Message $(if ($duplicateAddresses.Count -eq 0) { 'All IPv4 addresses are unique.' } else { "Duplicates: $($duplicateAddresses -join ', ')" })))

    $networkPrefix = [string]$plan.network.ipv4Prefix
    foreach ($system in $systems) {
        $name = [string]$system.name
        $address = [string]$system.ipv4Address

        try {
            $inPrefix = Test-IPv4InPrefix -Address $address -Prefix $networkPrefix
            $message = if ($inPrefix) {
                "$address belongs to $networkPrefix."
            }
            else {
                "$address is outside $networkPrefix."
            }
        }
        catch {
            $inPrefix = $false
            $message = $_.Exception.Message
        }

        $results.Add((New-ValidationResult `
            -Check "Address membership: $name" `
            -Passed $inPrefix `
            -Message $message))
    }

    $domainControllers = @($systems | Where-Object role -eq 'DomainController')
    $hasDomainController = $domainControllers.Count -gt 0
    $results.Add((New-ValidationResult `
        -Check 'Domain controller planned' `
        -Passed $hasDomainController `
        -Message $(if ($hasDomainController) { "$($domainControllers.Count) domain controller(s) planned." } else { 'At least one domain controller is required.' })))

    foreach ($domainController in $domainControllers) {
        $isStatic = [bool]$domainController.staticAddress
        $results.Add((New-ValidationResult `
            -Check "Static address: $($domainController.name)" `
            -Passed $isStatic `
            -Message $(if ($isStatic) { 'Static addressing is enabled.' } else { 'Domain controllers must use static addressing.' })))
    }

    $domainControllerAddresses = @($domainControllers | Select-Object -ExpandProperty ipv4Address)
    foreach ($system in $systems) {
        $dnsServers = @($system.dnsServers)
        $hasInternalDns = @($dnsServers | Where-Object { $_ -in $domainControllerAddresses }).Count -gt 0

        $results.Add((New-ValidationResult `
            -Check "Internal DNS: $($system.name)" `
            -Passed $hasInternalDns `
            -Message $(if ($hasInternalDns) { "Uses an internal domain-controller DNS address: $($dnsServers -join ', ')" } else { "No domain-controller DNS address configured: $($dnsServers -join ', ')" })))
    }

    $hostCpuPassed = [int]$plan.host.minimumLogicalProcessors -ge 4
    $hostMemoryPassed = [int]$plan.host.minimumMemoryGB -ge 8
    $hostStoragePassed = [int]$plan.host.minimumFreeStorageGB -ge 100

    $results.Add((New-ValidationResult -Check 'Host CPU baseline' -Passed $hostCpuPassed -Message "Configured minimum: $($plan.host.minimumLogicalProcessors) logical processors."))
    $results.Add((New-ValidationResult -Check 'Host memory baseline' -Passed $hostMemoryPassed -Message "Configured minimum: $($plan.host.minimumMemoryGB) GB."))
    $results.Add((New-ValidationResult -Check 'Host storage baseline' -Passed $hostStoragePassed -Message "Configured minimum: $($plan.host.minimumFreeStorageGB) GB."))

    return $results
}

try {
    $validationResults = @(Invoke-LabPlanValidation -PlanPath $Path)

    foreach ($result in $validationResults) {
        if ($result.Passed) {
            Write-Host "[PASS] $($result.Check): $($result.Message)" -ForegroundColor Green
        }
        else {
            Write-Host "[FAIL] $($result.Check): $($result.Message)" -ForegroundColor Red
        }
    }

    $failedResults = @($validationResults | Where-Object { -not $_.Passed })

    if ($PassThru) {
        $validationResults
    }

    if ($failedResults.Count -gt 0) {
        Write-Error "$($failedResults.Count) validation check(s) failed."
        exit 1
    }

    Write-Host "Lab plan validation completed successfully: $($validationResults.Count) checks passed." -ForegroundColor Cyan
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
