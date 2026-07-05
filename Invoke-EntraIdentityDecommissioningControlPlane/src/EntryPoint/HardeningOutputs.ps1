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
