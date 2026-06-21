#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [ValidateSet('Readiness', 'WhatIf', 'Verify', 'Closeout')]
    [string]$Mode,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$TargetObjectIds,

    [Parameter()]
    [ValidateRange(1, 100)]
    [int]$MaxObjectsPerWave = 10,

    [Parameter()]
    [bool]$StopOnFirstFailure = $false,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$BatchId = ('REV441B-' + [guid]::NewGuid().ToString('N')),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputRoot
)

$ErrorActionPreference = 'Stop'

$script:WrapperVersion = 'Rev4.41'
$script:ApprovedAction = 'ReversibleDisable'
$script:Rev441BatchSchemaVersion = 'Rev4.41-BatchPlanning'
$script:IsWhatIfMode = $false

Import-Module (Join-Path $PSScriptRoot '..\src\Modules\Utilities.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1') -Force -DisableNameChecking

function Write-NhiJsonArtifact {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }

    $json = $InputObject | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
    return $Path
}

function Get-NhiBatchRunRoot {
    param(
        [AllowNull()]
        [string]$OutputRoot,

        [switch]$CreateIfMissing
    )

    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        $runRoot = Join-Path 'C:\temp\IAM' ('Rev441BatchLifecycleRun-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    } else {
        $runRoot = [System.IO.Path]::GetFullPath($OutputRoot)
    }

    if ($CreateIfMissing) {
        if (-not (Test-Path -LiteralPath $runRoot -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $runRoot -Force
        }
    } elseif (-not (Test-Path -LiteralPath $runRoot -PathType Container)) {
        throw "STOP: Closeout requires an existing run root. '$runRoot' was not found."
    }

    return $runRoot
}

function Get-NhiBatchModeOutputPath {
    param(
        [Parameter(Mandatory)]
        [string]$RunRoot,

        [Parameter(Mandatory)]
        [string]$Mode,

        [switch]$CreateIfMissing
    )

    $outputPath = Join-Path $RunRoot $Mode.ToLowerInvariant()
    if ($CreateIfMissing) {
        if (-not (Test-Path -LiteralPath $outputPath -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $outputPath -Force
        }
    } elseif (-not (Test-Path -LiteralPath $outputPath -PathType Container)) {
        throw "STOP: Closeout requires an existing output path. '$outputPath' was not found."
    }

    return $outputPath
}

function Get-NhiBatchTargetArtifactFolder {
    param(
        [Parameter(Mandatory)]
        [string]$WaveFolder,

        [Parameter(Mandatory)]
        [int]$TargetIndex,

        [Parameter(Mandatory)]
        [string]$ServicePrincipalObjectId
    )

    $shortId = $ServicePrincipalObjectId.Replace('-', '').Substring(0, [Math]::Min(8, $ServicePrincipalObjectId.Replace('-', '').Length))
    return Join-Path $WaveFolder ('target-{0:00}-{1}' -f $TargetIndex, $shortId)
}

function Get-NhiBatchOwnerStatus {
    param(
        [Parameter()]
        [object[]]$Owners = @()
    )

    $count = @($Owners).Count
    if ($count -eq 0) { return 'NoOwners' }
    if ($count -eq 1) { return 'SingleOwner' }
    return 'MultiOwner'
}

function Get-NhiBatchPlatformIdentityClassification {
    param(
        [Parameter(Mandatory)]
        [object]$NhiObject
    )

    $classifier = Get-Command Test-DecomMicrosoftPlatformIdentity -ErrorAction SilentlyContinue
    if ($classifier) {
        return & $classifier -NhiObject $NhiObject
    }

    $appId = [string]$NhiObject.AppId
    $publisherName = [string]$NhiObject.PublisherName
    $verifiedPublisherName = [string]$NhiObject.VerifiedPublisher.displayName
    $appOwnerOrganizationId = [string]$NhiObject.AppOwnerOrganizationId

    $knownMicrosoftTenantIds = @(
        'f8cdef31-a31e-4b4a-93e4-5f571e91255a',
        '72f988bf-86f1-41af-91ab-2d7cd011db47'
    )

    $knownMicrosoftAppIds = @(
        '14d82eec-204b-4c2f-b7e8-296a70dab67e',
        '09213cdc-9f30-4e82-aa6f-9b6e8d82dab3',
        'f1143447-b07a-4557-b878-b78df8d45c13',
        '1b730954-1685-4b74-9bfd-dac224a7b894'
    )

    if ($appOwnerOrganizationId -in $knownMicrosoftTenantIds -or $verifiedPublisherName -in @('Microsoft', 'Microsoft Corporation') -or $publisherName -eq 'Microsoft Corporation' -or $appId -in $knownMicrosoftAppIds) {
        return [pscustomobject]@{
            Classification = 'MicrosoftPlatform'
            MicrosoftFirstParty = $true
            MicrosoftPlatform = $true
            EvidenceOnly = $true
            Reason = 'Microsoft metadata'
        }
    }

    $catalogGetter = Get-Command Get-DecomPlatformIdentityCatalog -ErrorAction SilentlyContinue
    if ($catalogGetter) {
        try {
            $catalog = & $catalogGetter
            foreach ($identity in @($catalog.identities)) {
                if ($identity -and $identity.PSObject.Properties['appId'] -and [string]$identity.appId -and $appId -and ([string]$identity.appId -ieq $appId)) {
                    return [pscustomobject]@{
                        Classification = [string]$identity.classification
                        MicrosoftFirstParty = [bool]$identity.firstPartyMicrosoftApp
                        MicrosoftPlatform = [bool]($identity.classification -eq 'MicrosoftPlatform')
                        EvidenceOnly = [bool]$identity.suppressCustomerRemediation
                        Reason = if ($identity.reason) { [string]$identity.reason } else { 'Platform catalog match' }
                    }
                }
            }
        } catch {
            # Fall back to local metadata heuristics when the catalog helper is unavailable in this context.
        }
    }

    return [pscustomobject]@{
        Classification = 'CustomerOwned'
        MicrosoftFirstParty = $false
        MicrosoftPlatform = $false
        EvidenceOnly = $false
        Reason = 'No platform classification matched'
    }
}

function Get-NhiBatchLastObservedActivity {
    param(
        [Parameter()]
        [object]$ServicePrincipal
    )

    if ($null -eq $ServicePrincipal) {
        return [pscustomobject]@{
            LastObservedActivity = 'Unknown'
            LastObservedUtc = $null
        }
    }

    $candidateDates = [System.Collections.Generic.List[datetime]]::new()
    if ($ServicePrincipal.PSObject.Properties['SignInActivity']) {
        $activity = $ServicePrincipal.SignInActivity
        foreach ($propertyName in @('LastSignInDateTime', 'LastNonInteractiveSignInDateTime', 'LastSuccessfulSignInDateTime')) {
            if ($activity -and $activity.PSObject.Properties[$propertyName]) {
                $raw = $activity.$propertyName
                if (-not [string]::IsNullOrWhiteSpace([string]$raw)) {
                    try {
                        $candidateDates.Add([datetime]::Parse([string]$raw).ToUniversalTime())
                    } catch { }
                }
            }
        }
    }

    if ($candidateDates.Count -eq 0) {
        return [pscustomobject]@{
            LastObservedActivity = 'Unknown'
            LastObservedUtc = $null
        }
    }

    $latest = $candidateDates | Sort-Object -Descending | Select-Object -First 1
    $ageDays = [math]::Floor(([datetime]::UtcNow - $latest).TotalDays)
    $label = if ($ageDays -lt 30) {
        'Recent'
    } elseif ($ageDays -lt 180) {
        'Stale'
    } else {
        'Inactive'
    }

    return [pscustomobject]@{
        LastObservedActivity = $label
        LastObservedUtc = $latest.ToString('o')
    }
}

function Get-NhiBatchTargetObservation {
    param(
        [Parameter(Mandatory)]
        [string]$ServicePrincipalObjectId
    )

    $sp = Get-MgServicePrincipal -ServicePrincipalId $ServicePrincipalObjectId `
        -Property 'Id,DisplayName,AppId,AccountEnabled,ServicePrincipalType,PublisherName,AppOwnerOrganizationId,Tags,Notes,SignInActivity' `
        -ErrorAction Stop

    $owners = @()
    try {
        $owners = @(Get-MgServicePrincipalOwner -ServicePrincipalId $ServicePrincipalObjectId -All -ErrorAction SilentlyContinue)
    } catch {
        $owners = @()
    }

    $platform = Get-NhiBatchPlatformIdentityClassification -NhiObject $sp
    $activity = Get-NhiBatchLastObservedActivity -ServicePrincipal $sp

    [pscustomobject]@{
        ServicePrincipal = $sp
        Owners = @($owners)
        OwnerStatus = Get-NhiBatchOwnerStatus -Owners $owners
        OwnerCount = @($owners).Count
        LastObservedActivity = $activity.LastObservedActivity
        LastObservedUtc = $activity.LastObservedUtc
        PlatformClassification = [string]$platform.Classification
        MicrosoftFirstParty = [bool]$platform.MicrosoftFirstParty
        MicrosoftPlatform = [bool]$platform.MicrosoftPlatform
        EvidenceOnly = [bool]$platform.EvidenceOnly
        PlatformReason = [string]$platform.Reason
    }
}

function Test-NhiBatchTargetEligibility {
    param(
        [Parameter(Mandatory)]
        [object]$Observation
    )

    $reasons = [System.Collections.Generic.List[string]]::new()

    $servicePrincipal = $Observation.ServicePrincipal
    $targetIdentity = [pscustomobject]@{
        ObjectId = [string]$servicePrincipal.Id
        ObjectType = 'ServicePrincipal'
        ProtectedObject = $false
        MicrosoftFirstParty = [bool]$Observation.MicrosoftFirstParty
        MicrosoftPlatform = [bool]$Observation.MicrosoftPlatform
        SuppressCustomerRemediation = [bool]$Observation.EvidenceOnly
        BreakGlassIndicator = $false
        EmergencyAccessIndicator = $false
        HighConfidenceActive = $Observation.LastObservedActivity -eq 'Recent'
        Ambiguous = $false
    }

    $targetValidation = Test-NhiControlledTarget -Target $targetIdentity
    if (-not $targetValidation.Passed) {
        foreach ($reason in @($targetValidation.Reasons)) {
            $reasons.Add([string]$reason)
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$servicePrincipal.Id)) {
        $reasons.Add('Target object id is missing.')
    }

    if ([string]::IsNullOrWhiteSpace([string]$servicePrincipal.DisplayName)) {
        $reasons.Add('Target display name is missing.')
    }

    if ([string]::IsNullOrWhiteSpace([string]$servicePrincipal.AppId)) {
        $reasons.Add('Target AppId is missing.')
    }

    if ($Observation.PlatformClassification -in @('MicrosoftPlatform', 'ExternalVendorPlatform')) {
        $reasons.Add("Platform identity is blocked: $($Observation.PlatformReason).")
    }

    if ($Observation.OwnerStatus -in @('Unknown', 'NoOwners')) {
        $reasons.Add("Owner status is $($Observation.OwnerStatus).")
    }

    if ($Observation.LastObservedActivity -eq 'Unknown') {
        $reasons.Add('Last observed activity is unknown.')
    }

    if ($Observation.ServicePrincipal.AccountEnabled -ne $true) {
        $reasons.Add('Target is already disabled.')
    }

    [pscustomobject]@{
        MutationEligible = $reasons.Count -eq 0
        ValidationStatus = if ($reasons.Count -eq 0) { 'Passed' } else { 'Blocked' }
        RiskReason = if ($reasons.Count -eq 0) { 'Eligible' } else { ($reasons -join '; ') }
        ValidationReasons = @($reasons)
        TargetValidation = $targetValidation
    }
}

function Invoke-NhiBatchReadOnlyGraphVerification {
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$BatchId,

        [Parameter(Mandatory)]
        [int]$MaxObjectsPerWave,

        [Parameter(Mandatory)]
        [bool]$StopOnFirstFailure,

        [Parameter(Mandatory)]
        [string[]]$TargetObjectIds,

        [Parameter(Mandatory)]
        [string]$Mode,

        [Parameter(Mandatory)]
        [string]$RunRoot,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $processedTargets = [System.Collections.Generic.List[object]]::new()
    $eligibleTargets = [System.Collections.Generic.List[object]]::new()
    $blockedTargets = [System.Collections.Generic.List[object]]::new()
    $stoppedEarly = $false
    $script:IsWhatIfMode = ($Mode -eq 'WhatIf')

    $uniqueTargetIds = @($TargetObjectIds | Select-Object -Unique)

    $targetsRoot = Join-Path $OutputPath 'targets'
    $null = New-Item -ItemType Directory -Path $targetsRoot -Force

    foreach ($index in 0..($uniqueTargetIds.Count - 1)) {
        $targetObjectId = [string]$uniqueTargetIds[$index]
        $targetFolder = Get-NhiBatchTargetArtifactFolder -WaveFolder $targetsRoot -TargetIndex ($index + 1) -ServicePrincipalObjectId $targetObjectId
        $null = New-Item -ItemType Directory -Path $targetFolder -Force

        try {
            $observation = Get-NhiBatchTargetObservation -ServicePrincipalObjectId $targetObjectId
            $eligibility = Test-NhiBatchTargetEligibility -Observation $observation

            $targetSummary = [pscustomobject]@{
                BatchId = $BatchId
                TenantId = $TenantId
                Mode = $Mode
                ApprovedAction = $script:ApprovedAction
                DisplayName = [string]$observation.ServicePrincipal.DisplayName
                ObjectType = 'ServicePrincipal'
                ServicePrincipalObjectId = [string]$observation.ServicePrincipal.Id
                AppId = [string]$observation.ServicePrincipal.AppId
                OwnerStatus = $observation.OwnerStatus
                OwnerCount = $observation.OwnerCount
                LastObservedActivity = $observation.LastObservedActivity
                LastObservedUtc = $observation.LastObservedUtc
                RiskReason = $eligibility.RiskReason
                ValidationStatus = $eligibility.ValidationStatus
                MutationEligible = $eligibility.MutationEligible
                WhatIfResult = if ($eligibility.MutationEligible) { if ($Mode -eq 'WhatIf') { 'Simulated' } else { 'Planned' } } else { 'Blocked' }
                WhatIf = $script:IsWhatIfMode
                RiskScore = if ($eligibility.MutationEligible) { 0 } else { [Math]::Min(100, 20 + ($eligibility.ValidationReasons.Count * 15)) }
                PlatformClassification = $observation.PlatformClassification
                MicrosoftFirstParty = $observation.MicrosoftFirstParty
                MicrosoftPlatform = $observation.MicrosoftPlatform
                EvidenceOnly = $observation.EvidenceOnly
                ValidationReasons = $eligibility.ValidationReasons
                ArtifactFolder = $targetFolder
                TargetSummaryPath = (Join-Path $targetFolder 'rev441-target-summary.json')
                WaveNumber = $null
                WaveFolder = $null
                WaveStatus = if ($eligibility.MutationEligible) { 'PendingWave' } else { 'Blocked' }
            }

            $null = Write-NhiJsonArtifact -Path $targetSummary.TargetSummaryPath -InputObject $targetSummary
            $processedTargets.Add($targetSummary)
            if ($eligibility.MutationEligible) {
                $eligibleTargets.Add($targetSummary)
            } else {
                $blockedTargets.Add($targetSummary)
                if ($StopOnFirstFailure) {
                    $stoppedEarly = $true
                    break
                }
            }
        } catch {
            $targetSummary = [pscustomobject]@{
                BatchId = $BatchId
                TenantId = $TenantId
                Mode = $Mode
                ApprovedAction = $script:ApprovedAction
                DisplayName = $null
                ObjectType = 'ServicePrincipal'
                ServicePrincipalObjectId = $targetObjectId
                AppId = $null
                OwnerStatus = 'Unknown'
                OwnerCount = 0
                LastObservedActivity = 'Unknown'
                LastObservedUtc = $null
                RiskReason = "Graph read failed: $($_.Exception.Message)"
                ValidationStatus = 'Blocked'
                MutationEligible = $false
                WhatIfResult = 'Blocked'
                WhatIf = $script:IsWhatIfMode
                RiskScore = 100
                PlatformClassification = 'Unknown'
                MicrosoftFirstParty = $false
                MicrosoftPlatform = $false
                EvidenceOnly = $false
                ValidationReasons = @($_.Exception.Message)
                ArtifactFolder = $targetFolder
                TargetSummaryPath = (Join-Path $targetFolder 'rev441-target-summary.json')
                WaveNumber = $null
                WaveFolder = $null
                WaveStatus = 'Blocked'
            }

            $null = Write-NhiJsonArtifact -Path $targetSummary.TargetSummaryPath -InputObject $targetSummary
            $processedTargets.Add($targetSummary)
            $blockedTargets.Add($targetSummary)
            if ($StopOnFirstFailure) {
                $stoppedEarly = $true
                break
            }
        }
    }

    $eligibleSorted = @($eligibleTargets | Sort-Object RiskScore, DisplayName, ServicePrincipalObjectId)
    $waves = @()
    for ($i = 0; $i -lt $eligibleSorted.Count; $i += $MaxObjectsPerWave) {
        $waveNumber = [int]([math]::Floor($i / $MaxObjectsPerWave) + 1)
        $slice = @($eligibleSorted[$i..([math]::Min($i + $MaxObjectsPerWave - 1, $eligibleSorted.Count - 1))])
        $waveFolder = Join-Path $OutputPath ('wave-{0:00}' -f $waveNumber)
        $null = New-Item -ItemType Directory -Path $waveFolder -Force

        foreach ($target in $slice) {
            $target.WaveNumber = $waveNumber
            $target.WaveFolder = $waveFolder
            $target.WaveStatus = 'Planned'
            $null = Write-NhiJsonArtifact -Path $target.TargetSummaryPath -InputObject $target
        }

        $waves += [pscustomobject]@{
            BatchId = $BatchId
            WaveNumber = $waveNumber
            TargetCount = $slice.Count
            TargetObjectIds = @($slice | ForEach-Object { $_.ServicePrincipalObjectId })
            WaveFolder = $waveFolder
        }
    }

    $batchManifest = [pscustomobject]@{
        SchemaVersion = $script:Rev441BatchSchemaVersion
        BatchId = $BatchId
        TenantId = $TenantId
        ApprovedAction = $script:ApprovedAction
        Mode = $Mode
        MaxObjectsPerWave = $MaxObjectsPerWave
        StopOnFirstFailure = $StopOnFirstFailure
        FinalDeleteApproved = $false
        CleanupApproved = $false
        GeneratedUtc = [DateTime]::UtcNow.ToString('o')
        WhatIf = $script:IsWhatIfMode
        Targets = @($processedTargets)
        Waves = @($waves)
    }

    $manifestPath = Join-Path $OutputPath 'rev441-batch-manifest.json'
    $null = Write-NhiJsonArtifact -Path $manifestPath -InputObject $batchManifest

    $batchSummary = [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $BatchId
        TenantId = $TenantId
        ApprovedAction = $script:ApprovedAction
        Mode = $Mode
        MaxObjectsPerWave = $MaxObjectsPerWave
        StopOnFirstFailure = $StopOnFirstFailure
        FinalDeleteApproved = $false
        CleanupApproved = $false
        WhatIf = $script:IsWhatIfMode
        BatchManifestPath = $manifestPath
        BatchSummaryPath = (Join-Path $OutputPath 'rev441-batch-summary.json')
        OutputRoot = $RunRoot
        TotalTargetCount = @($uniqueTargetIds).Count
        ProcessedTargetCount = $processedTargets.Count
        EligibleTargetCount = $eligibleTargets.Count
        BlockedTargetCount = $blockedTargets.Count
        WaveCount = $waves.Count
        SafetyGatePassed = $blockedTargets.Count -eq 0
        ReadOnlyGraphVerified = $true
        StoppedEarly = $stoppedEarly
        Targets = @($processedTargets)
        Waves = @($waves)
    }

    $null = Write-NhiJsonArtifact -Path $batchSummary.BatchSummaryPath -InputObject $batchSummary
    return $batchSummary
}

function Invoke-NhiBatchCloseoutSummary {
    param(
        [Parameter(Mandatory)]
        [string]$RunRoot,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$BatchId
    )

    if (-not (Test-Path -LiteralPath $RunRoot -PathType Container)) {
        throw "STOP: Closeout requires an existing run root. '$RunRoot' was not found."
    }

    if (-not (Test-Path -LiteralPath $OutputPath -PathType Container)) {
        throw "STOP: Closeout requires an existing output path. '$OutputPath' was not found."
    }

    $artifacts = Get-ChildItem -Path $RunRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'rev441-(batch-manifest|batch-summary|target-summary|closeout-summary)\.json$' } |
        Sort-Object FullName

    $summary = [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $BatchId
        Mode = 'Closeout'
        RunRoot = $RunRoot
        OutputPath = $OutputPath
        CloseoutStatus = if ($artifacts.Count -gt 0) { 'Collected' } else { 'Empty' }
        ArtifactCount = $artifacts.Count
        EvidenceArtifacts = @($artifacts.FullName)
        SafetyGatePassed = $true
    }

    $summaryPath = Join-Path $OutputPath 'rev441-closeout-summary.json'
    $summary | Add-Member -NotePropertyName CloseoutSummaryPath -NotePropertyValue $summaryPath -Force
    $null = Write-NhiJsonArtifact -Path $summaryPath -InputObject $summary
    return $summary
}

function Start-NhiBatchLifecyclePlanning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [ValidateSet('Readiness', 'WhatIf', 'Verify', 'Closeout')]
        [string]$Mode,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$TargetObjectIds,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$MaxObjectsPerWave = 10,

        [Parameter()]
        [bool]$StopOnFirstFailure = $false,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$BatchId = ('REV441B-' + [guid]::NewGuid().ToString('N')),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputRoot
    )

    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        throw 'TenantId is required.'
    }

    $uniqueTargetIds = @($TargetObjectIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($uniqueTargetIds.Count -eq 0) {
        throw 'At least one TargetObjectId is required.'
    }

    if ($uniqueTargetIds.Count -ne @($TargetObjectIds).Count) {
        throw 'TargetObjectIds must be unique and non-empty.'
    }

    $createIfMissing = $Mode -ne 'Closeout'
    $runRoot = Get-NhiBatchRunRoot -OutputRoot $OutputRoot -CreateIfMissing:$createIfMissing
    $outputPath = Get-NhiBatchModeOutputPath -RunRoot $runRoot -Mode $Mode -CreateIfMissing:$createIfMissing

    if (-not $createIfMissing) {
        if (-not (Test-Path -LiteralPath $runRoot -PathType Container)) {
            throw "STOP: Closeout requires an existing run root. Create or reuse the prior batch output root before running Closeout."
        }

        if (-not (Test-Path -LiteralPath $outputPath -PathType Container)) {
            throw "STOP: Closeout requires an existing output path. Aggregate only from pre-existing batch artifacts."
        }
    }

    if ($Mode -eq 'Closeout') {
        return Invoke-NhiBatchCloseoutSummary -RunRoot $runRoot -OutputPath $outputPath -BatchId $BatchId
    }

    return Invoke-NhiBatchReadOnlyGraphVerification -TenantId $TenantId -BatchId $BatchId -MaxObjectsPerWave $MaxObjectsPerWave -StopOnFirstFailure $StopOnFirstFailure -TargetObjectIds $uniqueTargetIds -Mode $Mode -RunRoot $runRoot -OutputPath $outputPath
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-NhiBatchLifecyclePlanning @PSBoundParameters
}
