#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Assessment','WhatIfRemediation','ExportPlan','ExecuteRemediation')]
    [string]$Mode = 'Assessment',

    [string]$TenantId,
    [string]$ClientId,
    [string]$EngagementId,
    [string]$ClientName,
    [string]$Assessor,
    [string]$OutputPath = '.\out',
    [string]$WhatIfManifestPath,
    [string]$ApprovalManifestPath,
    [switch]$NonInteractive,
    [switch]$GenerateApprovalTemplate,

    [int]$MaxActions     = 25,
    [string[]]$ActionId,
    [switch]$RequirePreflightConfirm,

    [switch]$DemoMode,
    [switch]$NoLogo,
    [string]$BaselinePath,
    [switch]$GenerateExecutivePack,
    [switch]$SelfTest,
    [switch]$GenerateReleasePackage,
    [string]$ReleasePackagePath = '.\release\Rev3.4',

    # Rev3.4 hardening output flags (all default off - backward compatible)
    [switch]$GenerateEvidenceBundle,
    [switch]$GenerateRedactedPackage,
    [ValidateSet('ClientSafe','PublicDemo','Strict','Internal')]
    [string]$RedactionProfile = 'ClientSafe',
    [switch]$GenerateReplayValidation,
    [switch]$GenerateApprovalDiff,
    [switch]$GenerateTraceabilityReport,
    [switch]$GenerateClientHandoff,
    [switch]$GenerateRev35Readiness,

    # Rev3.5 NHI / Agentic Identity output flags
    [switch]$GenerateNhiGovernancePack,

    # Rev4.0 NHI Execution parameters
    [switch]$ExecuteNhiDecommission,
    [ValidateRange(1,3)][int]$PhaseLimit = 1,
    [string]$ApprovedManifestPath,
    [int]$ScreamTestDays = 30,
    [string]$ExecutionOutputPath = '.\out\execution',
    [switch]$Rollback,
    [string]$ExecutionRunId,
    [switch]$AllowHumanExecution,

    # Rev4.1 optional read-only NHI activity audit
    [switch]$IncludeAgentActivityAudit,

    # Rev4.2-S1 controlled NHI decommission planner/evidence parameters
    [switch]$ExecuteNhiControlledDecommission,
    [switch]$ExecuteNhiControlledMetadataCleanup,
    [switch]$ExecuteNhiControlledGrantCleanup,
    [string]$ExecutionStage = 'ValidateOnly',
    [string]$DecommissionPlanPath,
    [ValidateRange(1,8760)][int]$ScreamTestWindowHours = 24,
    [switch]$RequireSecondConfirmation,
    [switch]$AllowFinalDelete,
    [switch]$WhatIfExecution
)

# Tool version - update this single constant each release
$script:ToolVersion = 'Rev4.10'

if ($Mode -eq 'ExecuteRemediation' -and $DemoMode) {
    Write-Host "[ERROR] ExecuteRemediation cannot run in DemoMode." -ForegroundColor Red
    exit 1
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ControlledExecutionStages = @(
    'ValidateOnly'
    'SnapshotOnly'
    'TagOnly'
    'DisableOnly'
    'ScreamTestOnly'
    'DeleteReadinessOnly'
    'MetadataCleanupReadiness'
    'GrantCleanupReadiness'
    'ManagedIdentityReadiness'
    'E2EEvidencePack'
    'ProductionReadiness'
    'FinalDelete'
)

if ($ExecutionStage -notin $script:ControlledExecutionStages) {
    Write-Host "[ERROR] Unsupported -ExecutionStage '$ExecutionStage'." -ForegroundColor Red
    exit 1
}

# Block unsafe parameter combinations
if ($SelfTest -and $Mode -eq 'ExecuteRemediation') {
    Write-Host "[ERROR] -SelfTest cannot be used with -Mode ExecuteRemediation." -ForegroundColor Red
    exit 1
}

if ($GenerateReleasePackage -and $Mode -eq 'ExecuteRemediation') {
    Write-Host "[ERROR] -GenerateReleasePackage should not be used with -Mode ExecuteRemediation for Rev3.0." -ForegroundColor Red
    exit 1
}

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path $ScriptRoot 'src\Modules'

$modulesToLoad = @(
    'Utilities'
    'Discovery'
    'Analysis'
    'Reporting'
    'RemediationPlan'
    'ApprovalManifest'
    'ExecutionLog'
    'Remediation'
    'Baseline'
    'ExecutivePack'
    'ReleaseValidation'
    'CatalogValidation'
    'SchemaContracts'
    'WriteReadiness'
    'ApplicationGovernance'
    'CredentialHygiene'
    'ConditionalAccessGovernance'
    'EmergencyAccessGovernance'
    'ReleasePackaging'
    'GuestGovernance'
    'Rev3CapabilityMatrix'
    'NhiDiscovery'
    'NhiAnalysis'
    'NhiGovernance'
    'NhiReporting'
    'NhiCredential'
    'NhiPermission'
    'NhiSignIn'
    'NhiOwner'
    'NhiPublisher'
    'NhiAgent'
    'NhiExecutionSchema'
    'NhiExecution'
    'NhiActivityLog'
    'NhiGraphApiAudit'
    'NhiComplianceAudit'
    'NhiTokenForensics'
    'NhiConditionalAccessResponse'
    'NhiPostDecomAudit'
    'NhiControlledDecommission'
)

foreach ($mod in $modulesToLoad) {
    $modPath = Join-Path $ModulesPath "$mod.psm1"
    Remove-Module $mod -Force -ErrorAction SilentlyContinue
    Import-Module $modPath -Force -DisableNameChecking
}

# SelfTest early exit - no Graph connection, discovery, or remediation
if ($SelfTest) {
    $selfTestTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $selfTestRunFolder = Join-Path $OutputPath $selfTestTimestamp
    New-Item -ItemType Directory -Path $selfTestRunFolder -Force | Out-Null
    $selfTestContext = [PSCustomObject]@{
        TenantId     = $TenantId
        ClientId     = $ClientId
        Mode         = $Mode
        DemoMode     = $false
        EngagementId = $EngagementId
        ClientName   = $ClientName
        Assessor     = $Assessor
        Coverage     = $null
        ToolVersion  = $script:ToolVersion
        OutputPath   = $selfTestRunFolder
    }
    Write-DecomInfo "Running SelfTest / ReleaseValidation mode..."
    $selfTestResult = Invoke-DecomReleaseValidation -Context $selfTestContext
    if ($selfTestResult.Passed) {
        Write-DecomOk "SelfTest PASSED"
        if ($GenerateReleasePackage) {
            Write-DecomInfo "Generating release package..."
            New-DecomReleasePackage -Context $selfTestContext -OutputPath $ReleasePackagePath
            Write-DecomOk "Release package generated at $ReleasePackagePath"
        }
        exit 0
    }
    Write-DecomError "SelfTest FAILED:"
    $selfTestResult.Errors | ForEach-Object { Write-DecomError "  $_" }
    exit 1
}

. "$PSScriptRoot\src\EntryPoint\ControlledNhiDecommission.ps1" -ErrorAction Stop
. "$PSScriptRoot\src\EntryPoint\NhiExecutionFlow.ps1" -ErrorAction Stop

. "$PSScriptRoot\src\EntryPoint\AssessmentFlow.ps1" -ErrorAction Stop

. "$PSScriptRoot\src\EntryPoint\NhiGovernancePack.ps1" -ErrorAction Stop

# ── Rev3.4 Hardening Outputs ──────────────────────────────────────────────────

$hardeningTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runManifestForHardening = if (Test-Path $ManifestPath) { Get-Content $ManifestPath -Raw | ConvertFrom-Json } else { $null }
$hardeningRunId = if ($runManifestForHardening -and $runManifestForHardening.RunId) { $runManifestForHardening.RunId } else { [guid]::NewGuid().ToString() }

if ($GenerateRev35Readiness) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'Rev35Readiness.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $rr = New-DecomRev35ReadinessReport
        $rrPath = Join-Path $RunFolder "rev35-readiness-report-$hardeningTimestamp.json"
        Export-DecomRev35ReadinessJson -Report $rr -Path $rrPath
        Write-DecomOk "Rev3.5 readiness report: $rrPath"
    } catch { Write-DecomWarn "Rev3.5 readiness report skipped: $_" }
}

if ($GenerateClientHandoff) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'ClientHandoff.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $redactedArtifactFiles = @(
            Get-ChildItem -Path (Join-Path $RunFolder 'redacted') -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in @('.json','.csv','.html','.md') } |
                Select-Object -ExpandProperty FullName
        )
        $chPkg = New-DecomClientHandoffPackage -Context $Context -RunId $hardeningRunId -PackagePath $RunFolder -RedactedFiles $redactedArtifactFiles
        $chManifestPath = Join-Path $RunFolder "client-handoff-manifest-$hardeningTimestamp.json"
        Export-DecomClientHandoffManifestJson -Package $chPkg -Path $chManifestPath
        $chIndexPath = Join-Path $RunFolder "client-handoff-index-$hardeningTimestamp.md"
        Export-DecomClientHandoffIndexMarkdown -Package $chPkg -Path $chIndexPath
        Write-DecomOk "Client handoff manifest: $chManifestPath"
        Write-DecomOk "Client handoff index: $chIndexPath"
    } catch { Write-DecomWarn "Client handoff skipped: $_" }
}

if ($GenerateTraceabilityReport) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'Traceability.psm1') -Force -DisableNameChecking -ErrorAction Stop
        # Initialize variables for traceability inputs
        $traceWhatIf = @()
        $traceApproval = @()
        $traceExecution = @()

        if ($WhatIfManifestPath -and (Test-Path $WhatIfManifestPath)) {
            $wf = Get-Content $WhatIfManifestPath -Raw | ConvertFrom-Json
            if ($wf.ApprovedActions) {
                $traceWhatIf = @($wf.ApprovedActions)
            }
        }
        if ($ApprovalManifestPath -and (Test-Path $ApprovalManifestPath)) {
            $ap = Get-Content $ApprovalManifestPath -Raw | ConvertFrom-Json
            if ($ap.ApprovedActions) {
                $traceApproval = @($ap.ApprovedActions)
            }
        }
        if ($execEvidencePath) {
            $ev = Get-Content $execEvidencePath -Raw | ConvertFrom-Json
            if ($ev.Actions) {
                $traceExecution = @($ev.Actions)
            }
        }

        $trModel = New-DecomTraceabilityModel `
            -Findings $Findings `
            -WhatIfActions $traceWhatIf `
            -ApprovalActions $traceApproval `
            -ExecutionResults $traceExecution `
            -RunId $hardeningRunId
        $trJsonPath = Join-Path $RunFolder "traceability-report-$hardeningTimestamp.json"
        $trCsvPath  = Join-Path $RunFolder "traceability-report-$hardeningTimestamp.csv"
        Export-DecomTraceabilityReportJson     -Model $trModel -Path $trJsonPath
        Export-DecomTraceabilityReportCsv      -Model $trModel -Path $trCsvPath
        Write-DecomOk "Traceability report: $trJsonPath"
    } catch { Write-DecomWarn "Traceability report skipped: $_" }
}

if ($GenerateReplayValidation -and $runManifestForHardening) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'ReplayValidation.psm1') -Force -DisableNameChecking -ErrorAction Stop

        # Load actual artifacts before calling Invoke-DecomReplayValidation
        $rvWhatIf = $null
        $rvApproval = $null
        $rvExecution = $null

        if ($WhatIfManifestPath -and (Test-Path $WhatIfManifestPath)) {
            $rvWhatIf = Get-Content $WhatIfManifestPath -Raw | ConvertFrom-Json
        }
        if ($ApprovalManifestPath -and (Test-Path $ApprovalManifestPath)) {
            $rvApproval = Get-Content $ApprovalManifestPath -Raw | ConvertFrom-Json
        }
        $execEvidencePath = Get-ChildItem -Path $RunFolder -Filter 'execution-evidence-*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
        if ($execEvidencePath) {
            $rvExecution = Get-Content $execEvidencePath -Raw | ConvertFrom-Json
        }

        $rvResult = Invoke-DecomReplayValidation `
            -RunId $hardeningRunId `
            -WhatIfReport $rvWhatIf `
            -ApprovalManifest $rvApproval `
            -ExecutionEvidence $rvExecution
        $rvPath = Export-DecomReplayValidationReportJson -ValidationResult $rvResult -OutputPath $RunFolder
        Write-DecomOk "Replay validation report: $rvPath"
    } catch { Write-DecomWarn "Replay validation skipped: $_" }
}

if ($GenerateApprovalDiff -and $runManifestForHardening) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'ApprovalDiff.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $adWhatIf   = @()
        $adApproval = @()
        if ($WhatIfManifestPath -and (Test-Path $WhatIfManifestPath)) {
            $wfDoc = Get-Content $WhatIfManifestPath -Raw | ConvertFrom-Json
            if ($wfDoc.ApprovedActions) { $adWhatIf = @($wfDoc.ApprovedActions) }
        }
        if ($ApprovalManifestPath -and (Test-Path $ApprovalManifestPath)) {
            $apDoc = Get-Content $ApprovalManifestPath -Raw | ConvertFrom-Json
            if ($apDoc.ApprovedActions) { $adApproval = @($apDoc.ApprovedActions) }
        }
        $adDiff = Compare-DecomWhatIfToApproval -WhatIfActions $adWhatIf -ApprovalActions $adApproval -RunId $hardeningRunId
        $adPath = Join-Path $RunFolder "approval-diff-report-$hardeningTimestamp.json"
        Export-DecomApprovalDiffJson -Diff $adDiff -Path $adPath
        Write-DecomOk "Approval diff: $adPath"
    } catch { Write-DecomWarn "Approval diff skipped: $_" }
}

if ($GenerateRedactedPackage) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'Redaction.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $redactionProfileObj = New-DecomRedactionProfile -ProfileName $RedactionProfile

        # Create redacted subdirectory and apply redaction to output files
        $redactedDir = Join-Path $RunFolder 'redacted'
        New-Item -ItemType Directory -Path $redactedDir -Force | Out-Null
        $redactedCount = 0
        $redactionErrors = @()

        Get-ChildItem -Path $RunFolder -File | Where-Object {
            $_.Extension -in @('.json','.csv','.md','.html') -and
            $_.FullName -notmatch '\\redacted\\'
        } |
            ForEach-Object {
                try {
                    $raw = Get-Content $_.FullName -Raw -ErrorAction Stop
                    $redacted = Invoke-DecomRedaction -InputString $raw -Profile $redactionProfileObj
                    $target = Join-Path $redactedDir $_.Name
                    Set-Content -Path $target -Value $redacted -Encoding UTF8
                    $redactedCount++
                } catch {
                    Write-DecomWarn "Redaction failed for $($_.FullName): $($_.Exception.Message)"
                    $redactionErrors += @{ File = $_.FullName; Error = $_.Exception.Message }
                }
        }

        $rdPath = Join-Path $RunFolder "redaction-report-$hardeningTimestamp.json"
        Export-DecomRedactionReportJson -Profile $redactionProfileObj -Path $rdPath -RunId $hardeningRunId -ToolVersion $script:ToolVersion -RedactedFileCount $redactedCount
        Write-DecomOk "Redaction report: $rdPath"
        Write-DecomOk "$redactedCount file(s) redacted to $redactedDir"
    } catch { Write-DecomWarn "Redaction report skipped: $_" }
}

if ($GenerateEvidenceBundle) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'EvidenceBundle.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $eb = New-DecomEvidenceBundle -Context $Context -RunId $hardeningRunId -BundleId ([guid]::NewGuid().ToString()) -SourceOutputPath $RunFolder -BundleOutputPath (Join-Path $RunFolder 'evidence-bundle')
        New-Item -ItemType Directory -Path $eb.BundleOutputPath -Force | Out-Null
        Get-ChildItem -Path $RunFolder -File -Recurse | Where-Object { $_.FullName -notmatch '\\temp\\' } | ForEach-Object {
            $eb = Add-DecomEvidenceBundleFile -Bundle $eb -FilePath $_.FullName -Category 'Assessment'
        }
        $ebManifestPath = Join-Path $eb.BundleOutputPath "evidence-bundle-manifest-$hardeningTimestamp.json"
        Export-DecomEvidenceBundleManifestJson -Bundle $eb -Path $ebManifestPath
        $hashJsonPath = Join-Path $eb.BundleOutputPath "evidence-hashes-$hardeningTimestamp.json"
        $hashCsvPath  = Join-Path $eb.BundleOutputPath "evidence-hashes-$hardeningTimestamp.csv"
        Export-DecomEvidenceHashManifest -Bundle $eb -JsonPath $hashJsonPath -CsvPath $hashCsvPath
        Write-DecomOk "Evidence bundle: $ebManifestPath"
    } catch { Write-DecomWarn "Evidence bundle skipped: $_" }
}

if ($GenerateEvidenceBundle -or $GenerateRedactedPackage -or $GenerateTraceabilityReport -or $GenerateClientHandoff -or $GenerateRev35Readiness) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'OutputManifest.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $om = New-DecomOutputManifest -Context $Context -RunId $hardeningRunId -OutputRoot $RunFolder
        Get-ChildItem -Path $RunFolder -File -Recurse | Where-Object { $_.FullName -notmatch '\\temp\\' -and $_.Extension -in @('.json','.csv','.html','.md') } | ForEach-Object {
            $sensitivity = if ($_.FullName -match '\\redacted\\' -or $_.Name -match 'redact') { 'ClientSafe' } else { 'Confidential' }
            $category = switch -Regex ($_.Name) {
                'readiness'    { 'Rev35Readiness';    break }
                'handoff'      { 'ClientHandoff';     break }
                'traceability' { 'Report';            break }
                'evidence'     { 'ExecutionEvidence'; break }
                'manifest'     { 'Report';            break }
                default        { 'Assessment' }
            }
            $om = Add-DecomOutputManifestItem -Manifest $om -FilePath $_.FullName -Category $category -Sensitivity $sensitivity
        }
        $omPath = Join-Path $RunFolder "output-manifest-$hardeningTimestamp.json"
        Export-DecomOutputManifestJson -Manifest $om -Path $omPath
        Write-DecomOk "Output manifest: $omPath"
    } catch { Write-DecomWarn "Output manifest skipped: $_" }
}

if ($GenerateClientHandoff) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'ClientHandoff.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $redactedArtifactFiles = @(
            Get-ChildItem -Path (Join-Path $RunFolder 'redacted') -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in @('.json','.csv','.html','.md') } |
                Select-Object -ExpandProperty FullName
        )
        $chPkg = New-DecomClientHandoffPackage -Context $Context -RunId $hardeningRunId -PackagePath $RunFolder -RedactedFiles $redactedArtifactFiles
        $chManifestPath = Join-Path $RunFolder "client-handoff-manifest-$hardeningTimestamp.json"
        Export-DecomClientHandoffManifestJson -Package $chPkg -Path $chManifestPath
        $chIndexPath = Join-Path $RunFolder "client-handoff-index-$hardeningTimestamp.md"
        Export-DecomClientHandoffIndexMarkdown -Package $chPkg -Path $chIndexPath
        Write-DecomOk "Client handoff manifest refreshed: $chManifestPath"
        Write-DecomOk "Client handoff index refreshed: $chIndexPath"
    } catch { Write-DecomWarn "Client handoff refresh skipped: $_" }
}

# ── Rev3.5 NHI Governance Pack ────────────────────────────────────────────────

if ($GenerateNhiGovernancePack) {
    try {
        Write-DecomInfo "Generating NHI governance pack..."

        # Use cached NHI pipeline state if already ran, otherwise generate warning
        if (-not $NhiPipelineRan) {
            Write-DecomWarn "NHI reporting requested but NHI pipeline did not run; generating empty NHI pack with coverage warning."
            # Do not re-run discovery/analysis/governance; just exit
        } else {
            # Generate NHI reporting outputs using cached state (writes nhi-* files to $Context.OutputPath = $RunFolder)
            Invoke-DecomNhiReporting -NhiInventory $NhiAnalyzed -NhiGovernanceFindings $NhiGovernanceFindings -Context $Context
            Write-DecomOk "NHI governance pack generation complete"
        }

        if ($NhiPipelineRan) {

        # Register NHI outputs in OutputManifest and EvidenceBundle
        $nhiOutputFiles = Get-ChildItem -Path $RunFolder -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'nhi-*' -or $_.Name -like '*-nhi-*' }

        if ($nhiOutputFiles.Count -gt 0) {
            try {
                Import-Module (Join-Path $script:ModulesPath 'OutputManifest.psm1') -Force -DisableNameChecking -ErrorAction Stop
                $nhiOm = New-DecomOutputManifest -Context $Context -RunId $hardeningRunId -OutputRoot $RunFolder
                foreach ($f in $nhiOutputFiles) {
                    $nhiOm = Add-DecomOutputManifestItem -Manifest $nhiOm `
                        -FilePath $f.FullName -Category 'Assessment' -Sensitivity 'Confidential'
                }
                $nhiOmPath = Join-Path $RunFolder "nhi-output-manifest-$hardeningTimestamp.json"
                Export-DecomOutputManifestJson -Manifest $nhiOm -Path $nhiOmPath
                Write-DecomOk "NHI output manifest: $nhiOmPath"
            } catch { Write-DecomWarn "NHI output manifest skipped: $_" }

            try {
                Import-Module (Join-Path $script:ModulesPath 'EvidenceBundle.psm1') -Force -DisableNameChecking -ErrorAction Stop
                $nhiEb = New-DecomEvidenceBundle -Context $Context -RunId $hardeningRunId `
                    -BundleId ([guid]::NewGuid().ToString()) `
                    -SourceOutputPath $RunFolder `
                    -BundleOutputPath (Join-Path $RunFolder 'nhi-evidence-bundle')
                New-Item -ItemType Directory -Path $nhiEb.BundleOutputPath -Force | Out-Null
                foreach ($f in $nhiOutputFiles) {
                    $nhiEb = Add-DecomEvidenceBundleFile -Bundle $nhiEb `
                        -FilePath $f.FullName -Category 'NHI'
                }
                $nhiEbManifestPath = Join-Path $nhiEb.BundleOutputPath "nhi-evidence-bundle-manifest-$hardeningTimestamp.json"
                Export-DecomEvidenceBundleManifestJson -Bundle $nhiEb -Path $nhiEbManifestPath
                Write-DecomOk "NHI evidence bundle: $nhiEbManifestPath"
            } catch { Write-DecomWarn "NHI evidence bundle skipped: $_" }
        }
        }
    } catch { Write-DecomWarn "NHI governance pack skipped: $_" }
}

Write-Host ''
Write-Host ('=' * 64) -ForegroundColor DarkCyan
Write-Host '  Assessment complete.' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Findings:' -ForegroundColor DarkCyan
Write-Host "    CRITICAL : $($Summary.Critical)" -ForegroundColor Red
Write-Host "    HIGH     : $($Summary.High)"     -ForegroundColor DarkYellow
Write-Host "    MEDIUM   : $($Summary.Medium)"   -ForegroundColor Cyan
Write-Host "    LOW      : $($Summary.Low)"      -ForegroundColor Green
Write-Host "    INFO     : $($Summary.Informational)" -ForegroundColor Gray
Write-Host ''
Write-Host '  Exports:' -ForegroundColor DarkCyan
Write-Host "    [OK]  CSV              : $CsvPath" -ForegroundColor Green
Write-Host "    [OK]  JSON             : $JsonPath" -ForegroundColor Green
Write-Host "    [OK]  HTML Report      : $HtmlPath" -ForegroundColor Green
Write-Host "    [OK]  Remediation Plan : $PlanPath" -ForegroundColor Green
Write-Host "    [OK]  Run Manifest     : $ManifestPath" -ForegroundColor Green
Write-Host ''
Write-Host "  Output folder : $RunFolder" -ForegroundColor Gray
Write-Host ('=' * 64) -ForegroundColor DarkCyan

exit 0
