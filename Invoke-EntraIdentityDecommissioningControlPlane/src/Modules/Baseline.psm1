function Import-DecomBaselineFindings {
    <#
    .SYNOPSIS
    Import baseline findings from previous JSON export or run folder.
    .DESCRIPTION
    Loads previous assessment findings for comparison with current run.
    Returns baseline data or indicates baseline unavailable.
    .PARAMETER BaselinePath
    Path to previous JSON findings export OR previous run folder.
    .OUTPUTS
    [PSCustomObject] with BaselineAvailable, SourcePath, Findings, ErrorDetail
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BaselinePath
    )

    $result = [PSCustomObject]@{
        BaselineAvailable = $false
        SourcePath        = ''
        Findings          = @()
        ErrorDetail       = ''
    }

    if (-not $BaselinePath) {
        return $result
    }

    try {
        # Determine if path is file or folder
        if (Test-Path -Path $BaselinePath -PathType Leaf) {
            # Direct file path
            $jsonPath = $BaselinePath
            $result.SourcePath = $jsonPath
        } elseif (Test-Path -Path $BaselinePath -PathType Container) {
            # Folder path - find most recent findings*.json
            $jsonFiles = Get-ChildItem -Path $BaselinePath -Filter '*findings*.json' -File -ErrorAction SilentlyContinue |
                         Sort-Object LastWriteTime -Descending
            if ($jsonFiles.Count -eq 0) {
                $result.ErrorDetail = "No findings*.json files found in folder '$BaselinePath'"
                return $result
            }
            $jsonPath = $jsonFiles[0].FullName
            $result.SourcePath = $jsonPath
        } else {
            $result.ErrorDetail = "Path '$BaselinePath' does not exist"
            return $result
        }

        # Load and validate JSON
        $jsonContent = Get-Content -Path $jsonPath -Raw -ErrorAction Stop
        $baselineData = ConvertFrom-Json -InputObject $jsonContent -ErrorAction Stop

        # Validate schema version (accept 2.3 or 2.4 for backward compatibility)
        if ($baselineData.SchemaVersion -notin @('2.3', '2.4')) {
            $result.ErrorDetail = "Unsupported schema version '$($baselineData.SchemaVersion)'. Expected 2.3 or 2.4."
            return $result
        }

        # Extract findings array
        $findings = if ($baselineData.Findings) { $baselineData.Findings } else { @() }

        $result.BaselineAvailable = $true
        $result.Findings = $findings

    } catch {
        $result.ErrorDetail = "Failed to load baseline: $($_.Exception.Message)"
    }

    return $result
}

function Get-DecomFindingStableKey {
    <#
    .SYNOPSIS
    Generate stable key for finding comparison across runs.
    .DESCRIPTION
    Creates a consistent identifier for findings based on immutable properties.
    .PARAMETER Finding
    The finding object to generate key for.
    .OUTPUTS
    String representing stable key.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Finding
    )

    $findingId  = if ($Finding.FindingId)  { [string]$Finding.FindingId }  else { '' }
    $objectType = if ($Finding.ObjectType) { [string]$Finding.ObjectType } else { '' }
    $objectId   = if ($Finding.ObjectId)   { [string]$Finding.ObjectId }   else { '' }
    $targetId = ''
    if ($Finding.TargetObjectId) {
        $targetId = [string]$Finding.TargetObjectId
    } elseif ($Finding.TargetObjectIds -and @($Finding.TargetObjectIds).Count -eq 1) {
        $targetId = [string]@($Finding.TargetObjectIds)[0]
    }
    if ($objectId) {
        return "$findingId|$objectType|$objectId|$targetId"
    }
    $displayName = if ($Finding.DisplayName) { [string]$Finding.DisplayName } else { '' }
    return "$findingId|$objectType|$displayName|$targetId"
}

function Compare-DecomFindingBaseline {
    <#
    .SYNOPSIS
    Compare current findings against baseline to identify changes.
    .DESCRIPTION
    Analyzes current findings relative to baseline to detect New, Persisting, Resolved,
    ChangedSeverity, ChangedRiskScore, ChangedEvidence, and Unchanged items.
    .PARAMETER CurrentFindings
    Array of current assessment findings.
    .PARAMETER BaselineFindings
    Array of baseline findings from previous run.
    .OUTPUTS
    Array of comparison results with status and delta information.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$CurrentFindings,

        [Parameter(Mandatory = $true)]
        [object[]]$BaselineFindings
    )

    # Create lookup dictionaries for efficient comparison
    $baselineLookup = @{}
    foreach ($bf in $BaselineFindings) {
        $key = Get-DecomFindingStableKey -Finding $bf
        $baselineLookup[$key] = $bf
    }

    $results = @()

    # Process current findings
    foreach ($cf in $CurrentFindings) {
        $key = Get-DecomFindingStableKey -Finding $cf

        if ($baselineLookup.ContainsKey($key)) {
            # Finding existed in baseline - check for changes
            $bf = $baselineLookup[$key]

            $status = 'Unchanged'
            $priorSeverity = $bf.Severity
            $currentSeverity = $cf.Severity
            $priorRiskScore = if ($bf.RiskScore) { [int]$bf.RiskScore } else { 0 }
            $currentRiskScore = if ($cf.RiskScore) { [int]$cf.RiskScore } else { 0 }
            $deltaRiskScore = $currentRiskScore - $priorRiskScore
            $priorEvidence = $bf.Evidence
            $currentEvidence = $cf.Evidence

            # Determine change type
            if ($priorSeverity -ne $currentSeverity) {
                $status = 'ChangedSeverity'
            } elseif ($deltaRiskScore -ne 0) {
                $status = 'ChangedRiskScore'
            } elseif ($priorEvidence -ne $currentEvidence) {
                $status = 'ChangedEvidence'
            }

            $resultObj = [PSCustomObject]@{
                StableKey           = $key
                FindingId           = $cf.FindingId
                ObjectType          = $cf.ObjectType
                ObjectId            = $cf.ObjectId
                DisplayName         = $cf.DisplayName
                PriorSeverity       = $priorSeverity
                CurrentSeverity     = $currentSeverity
                PriorRiskScore      = $priorRiskScore
                CurrentRiskScore    = $currentRiskScore
                DeltaRiskScore      = $deltaRiskScore
                Status              = $status
                PriorEvidence       = $priorEvidence
                CurrentEvidence     = $currentEvidence
                PriorRunId          = $bf.RunId
                CurrentRunId        = $cf.RunId
                IsPersisting        = $true
            }

            $results += $resultObj

            # Remove from baseline lookup to track resolved items later
            $baselineLookup.Remove($key) | Out-Null
        } else {
            # New finding - not in baseline
            $resultObj = [PSCustomObject]@{
                StableKey           = Get-DecomFindingStableKey -Finding $cf
                FindingId           = $cf.FindingId
                ObjectType          = $cf.ObjectType
                ObjectId            = $cf.ObjectId
                DisplayName         = $cf.DisplayName
                PriorSeverity       = $null
                CurrentSeverity     = $cf.Severity
                PriorRiskScore      = $null
                CurrentRiskScore    = if ($cf.RiskScore) { [int]$cf.RiskScore } else { 0 }
                DeltaRiskScore      = if ($cf.RiskScore) { [int]$cf.RiskScore } else { 0 }
                Status              = 'New'
                PriorEvidence       = $null
                CurrentEvidence     = $cf.Evidence
                PriorRunId          = $null
                CurrentRunId        = $cf.RunId
                IsPersisting        = $false
            }

            $results += $resultObj
        }
    }

    # Remaining items in baseline lookup are resolved findings
    foreach ($key in $baselineLookup.Keys) {
        $bf = $baselineLookup[$key]

        $resultObj = [PSCustomObject]@{
            StableKey           = $key
            FindingId           = $bf.FindingId
            ObjectType          = $bf.ObjectType
            ObjectId            = $bf.ObjectId
            DisplayName         = $bf.DisplayName
            PriorSeverity       = $bf.Severity
            CurrentSeverity     = $null
            PriorRiskScore      = if ($bf.RiskScore) { [int]$bf.RiskScore } else { 0 }
            CurrentRiskScore    = $null
            DeltaRiskScore      = 0 - ($bf.RiskScore | ForEach-Object { [int]$_ })
            Status              = 'Resolved'
            PriorEvidence       = $bf.Evidence
            CurrentEvidence     = $null
            PriorRunId          = $bf.RunId
            CurrentRunId        = $null
            IsPersisting        = $false
        }

        $results += $resultObj
    }

    return $results
}

function Export-DecomBaselineComparisonJson {
    <#
    .SYNOPSIS
    Export baseline comparison results as JSON.
    .DESCRIPTION
    Creates JSON file with baseline comparison summary and detailed items.
    .PARAMETER ComparisonResults
    Array of comparison results from Compare-DecomFindingBaseline.
    .PARAMETER Context
    Assessment context object.
    .PARAMETER BaselineResult
    Result from Import-DecomBaselineFindings.
    .PARAMETER Path
    Output file path for JSON.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$ComparisonResults,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$BaselineResult,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Calculate summary statistics
    $summary = @{
        New                   = ($ComparisonResults | Where-Object { $_.Status -eq 'New' }).Count
        Persisting            = ($ComparisonResults | Where-Object { $_.IsPersisting -eq $true }).Count
        Resolved              = ($ComparisonResults | Where-Object { $_.Status -eq 'Resolved' }).Count
        ChangedSeverity       = ($ComparisonResults | Where-Object { $_.Status -eq 'ChangedSeverity' }).Count
        ChangedRiskScore      = ($ComparisonResults | Where-Object { $_.Status -eq 'ChangedRiskScore' }).Count
        ChangedEvidence       = ($ComparisonResults | Where-Object { $_.Status -eq 'ChangedEvidence' }).Count
        Unchanged             = ($ComparisonResults | Where-Object { $_.Status -eq 'Unchanged' }).Count
        NetRiskDelta          = ($ComparisonResults | Measure-Object -Property DeltaRiskScore -Sum).Sum
    }

    # Build payload
    $payload = [ordered]@{
        SchemaVersion       = '2.4'
        ToolVersion         = $Context.ToolVersion
        GeneratedUtc        = (Get-Date).ToUniversalTime().ToString('o')
        ClientName          = $Context.ClientName
        EngagementId        = $Context.EngagementId
        CurrentRunId        = [guid]::NewGuid().Guid
        BaselineAvailable   = $BaselineResult.BaselineAvailable
        BaselineSourcePath  = $BaselineResult.SourcePath
        Summary             = $summary
        Items               = $ComparisonResults
    }

    $json = $payload | ConvertTo-Json -Depth 10
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

function Export-DecomBaselineComparisonCsv {
    <#
    .SYNOPSIS
    Export baseline comparison results as CSV.
    .DESCRIPTION
    Creates CSV file with baseline comparison data for spreadsheet analysis.
    .PARAMETER ComparisonResults
    Array of comparison results from Compare-DecomFindingBaseline.
    .PARAMETER Path
    Output file path for CSV.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$ComparisonResults,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not $ComparisonResults -or $ComparisonResults.Count -eq 0) {
        'StableKey,Status,FindingId,ObjectType,ObjectId,DisplayName,PriorSeverity,CurrentSeverity,PriorRiskScore,CurrentRiskScore,DeltaRiskScore,PriorEvidence,CurrentEvidence,PriorRunId,CurrentRunId' |
            Set-Content -Path $Path -Encoding UTF8
        return
    }

    $ComparisonResults | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

function Get-DecomRiskMovementSummary {
    <#
    .SYNOPSIS
    Calculate risk movement summary from baseline comparison.
    .DESCRIPTION
    Aggregates baseline comparison results into risk movement KPIs.
    .PARAMETER ComparisonResults
    Array of comparison results from Compare-DecomFindingBaseline.
    .OUTPUTS
    Hashtable with risk movement summary statistics.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$ComparisonResults
    )

    $newCritical = ($ComparisonResults | Where-Object { $_.Status -eq 'New' -and $_.CurrentSeverity -eq 'Critical' }).Count
    $newHigh = ($ComparisonResults | Where-Object { $_.Status -eq 'New' -and $_.CurrentSeverity -eq 'High' }).Count
    $resolvedCritical = ($ComparisonResults | Where-Object { $_.Status -eq 'Resolved' -and $_.PriorSeverity -eq 'Critical' }).Count
    $resolvedHigh = ($ComparisonResults | Where-Object { $_.Status -eq 'Resolved' -and $_.PriorSeverity -eq 'High' }).Count
    $persistingCritical = ($ComparisonResults | Where-Object { $_.Status -eq 'Persisting' -and $_.CurrentSeverity -eq 'Critical' }).Count
    $persistingHigh = ($ComparisonResults | Where-Object { $_.Status -eq 'Persisting' -and $_.CurrentSeverity -eq 'High' }).Count
    $riskScoreIncreased = ($ComparisonResults | Where-Object { $_.DeltaRiskScore -gt 0 }).Count
    $riskScoreDecreased = ($ComparisonResults | Where-Object { $_.DeltaRiskScore -lt 0 }).Count
    $netRiskDelta = ($ComparisonResults | Measure-Object -Property DeltaRiskScore -Sum).Sum
    $totalCurrentFindings = ($ComparisonResults | Where-Object { $_.Status -in @('New','Persisting','ChangedSeverity','ChangedRiskScore','ChangedEvidence','Unchanged') }).Count
    $totalPriorFindings = ($ComparisonResults | Where-Object { $_.Status -in @('Resolved','Persisting','ChangedSeverity','ChangedRiskScore','ChangedEvidence','Unchanged') }).Count

    return @{
        NewCritical           = $newCritical
        NewHigh               = $newHigh
        ResolvedCritical      = $resolvedCritical
        ResolvedHigh          = $resolvedHigh
        PersistingCritical    = $persistingCritical
        PersistingHigh        = $persistingHigh
        RiskScoreIncreased    = $riskScoreIncreased
        RiskScoreDecreased    = $riskScoreDecreased
        NetRiskDelta          = $netRiskDelta
        TotalCurrentFindings  = $totalCurrentFindings
        TotalPriorFindings    = $totalPriorFindings
    }
}