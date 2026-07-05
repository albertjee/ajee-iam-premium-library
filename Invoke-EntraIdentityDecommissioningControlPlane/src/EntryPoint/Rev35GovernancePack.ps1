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
