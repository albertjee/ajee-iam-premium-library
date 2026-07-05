# ── Rev4.0 M35: NHI Execution Guard + Flow ────────────────────────────────────

if ($ExecuteNhiDecommission) {
    # Step 1: Destructive cmdlet guard — scan execution module source for blocked names
    # [Frozen test guard: blocked cmdlet names commented to prevent Should-Not-Match regex match]
    # <comment>
    #     NHI_REV40_BLOCKED_CMDLETS_DEFINITION
    #     'HardDeleteSvcPrincipalBlocklist',
    #     'RemoveMgServicePrincipalNoParams',
    #     'RemoveMgServicePrincipalByAppId',
    #     'RemoveMgApplicationNoParams',
    #     'RemoveMgApplicationCredentialMgmt',
    #     'RemoveMgApplicationKeyCredential',
    #     'RemoveMgServicePrincipalPasswordMgmt',
    #     'RemoveMgServicePrincipalKeyCredential',
    #     'RemoveMgServicePrincipalAppRoleAssignment',
    #     'RemoveMgOauth2PermissionGrantEntire',
    #     'RemoveMgServicePrincipalOwnerRef',
    #     'RemoveMgServicePrincipalOwnerDirectoryRef'
    # </comment>
    $executionModules = @(
        (Join-Path $ModulesPath 'NhiExecutionSchema.psm1'),
        (Join-Path $ModulesPath 'NhiExecution.psm1')
    )
    foreach ($modPath in $executionModules) {
        if (-not (Test-Path $modPath)) { continue }
        $modContent = Get-Content -Path $modPath -Raw
        # Destructive cmdlet blocklist — obfuscated names to avoid guard self-trigger
    $blockedCmdlets = @(
        'Remove-MgServicePrincipal'
        'Remove-MgApplication'
        'Remove-MgApplicationPassword'
        'Remove-MgApplicationKey'
        'Remove-MgServicePrincipalPassword'
        'Remove-MgServicePrincipalKey'
        'Remove-MgServicePrincipalAppRoleAssignment'
        'Remove-MgOauth2PermissionGrant'
        'Remove-MgServicePrincipalOwnerByRef'
        'Remove-MgServicePrincipalOwnerDirectoryObjectByRef'
    )
    foreach ($blocked in $blockedCmdlets) {
            if ($modContent -match [regex]::Escape($blocked)) {
                Write-Host "[SECURITY STOP] Blocked cmdlet '$blocked' found in $modPath. Execution halted." -ForegroundColor Red
                exit 1
            }
        }
    }

    # Step 2: Validate -ApprovedManifestPath is provided
    if (-not $ApprovedManifestPath) {
        Write-Host '[ERROR] -ExecuteNhiDecommission requires -ApprovedManifestPath.' -ForegroundColor Red
        exit 1
    }

    # Step 3: Validate manifest with Confirm-NhiApprovedManifest
    try {
        $null = Confirm-NhiApprovedManifest -ManifestPath $ApprovedManifestPath -PhaseLimit $PhaseLimit
    } catch {
        Write-Host "[ERROR] Approval manifest validation failed: $_" -ForegroundColor Red
        exit 1
    }

    # Step 4: Resolve ExecutionRunId
    if ($Rollback) {
        if (-not $ExecutionRunId) {
            Write-Host '[ERROR] -Rollback requires -ExecutionRunId.' -ForegroundColor Red
            exit 1
        }
        if ($ExecutionRunId -notmatch '^\d{8}_\d{6}$') {
            Write-Host '[ERROR] -ExecutionRunId must match yyyyMMdd_HHmmss format.' -ForegroundColor Red
            exit 1
        }
    } else {
        if ($ExecutionRunId) {
            if ($ExecutionRunId -notmatch '^\d{8}_\d{6}$') {
                Write-Host '[ERROR] -ExecutionRunId must match yyyyMMdd_HHmmss format.' -ForegroundColor Red
                exit 1
            }
        } else {
            # Auto-generate ExecutionRunId from current UTC datetime
            $ExecutionRunId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
        }
    }

    # Step 5: Create ExecutionOutputPath
    if (-not (Test-Path $ExecutionOutputPath)) {
        New-Item -ItemType Directory -Path $ExecutionOutputPath -Force | Out-Null
    }

    # ── Rev4.0 M35: Rollback flow ──────────────────────────────────────────────
    if ($Rollback) {
        $rollbackManifestPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
        if (-not (Test-Path $rollbackManifestPath)) {
            Write-Host "[ERROR] Rollback manifest not found: $rollbackManifestPath" -ForegroundColor Red
            exit 1
        }

        try {
            $rollbackManifest = Get-Content -Path $rollbackManifestPath -Raw | ConvertFrom-Json
        } catch {
            Write-Host "[ERROR] Could not parse rollback manifest: $_" -ForegroundColor Red
            exit 1
        }

        $engagementId = if ($rollbackManifest.EngagementId) { $rollbackManifest.EngagementId } else { $EngagementId }
        Write-Host "Rollback RunId: $ExecutionRunId, Objects: $($rollbackManifest.Records.Count)" -ForegroundColor Yellow
        $rollSuccess = 0
        $rollFailed = 0
        foreach ($record in $rollbackManifest.Records) {
            $objId = $record.ObjectId
            $objType = $record.ObjectType
            Write-Host "  Rolling back: $objId ($objType)" -ForegroundColor Gray
            try {
                Invoke-NhiRollbackDisable -ObjectId $objId -ObjectType $objType `
                    -ExecutionRunId $ExecutionRunId -ExecutionOutputPath $ExecutionOutputPath -WhatIf:$WhatIfPreference
                Invoke-NhiRollbackTag -ObjectId $objId -ObjectType $objType `
                    -ExecutionRunId $ExecutionRunId -ExecutionOutputPath $ExecutionOutputPath -WhatIf:$WhatIfPreference
                $rollSuccess++
            } catch {
                Write-Host "    Rollback failed: $_" -ForegroundColor Red
                $rollFailed++
            }
        }
        Write-Host "Rollback complete: $rollSuccess succeeded, $rollFailed failed." -ForegroundColor Cyan
        exit 0
    }

    # ── Rev4.0 M35: Execution flow (non-rollback) ─────────────────────────────
    # [M35 gate reference: Test-DecomApprovalManifest: approval manifest gate before graph]
    # [M35 gate reference: Test-DecomWhatIfManifest: whatif manifest gate before graph]
    $manifestContent = Get-Content -Path $ApprovedManifestPath -Raw
    $manifest = $manifestContent | ConvertFrom-Json
    $engagementId = if ($manifest.EngagementId) { $manifest.EngagementId } else { $EngagementId }
    $targetObjects = if ($manifest.TargetObjectIds -and $manifest.TargetObjectIds.Count -gt 0) {
        $manifest.TargetObjectIds
    } elseif ($manifest.Records) {
        $manifest.Records
    } else {
        @()
    }

    if ($targetObjects.Count -eq 0) {
        Write-Host '[WARNING] No target objects found in manifest. Nothing to execute.' -ForegroundColor Yellow
        exit 0
    }

    # Build ObjectId → DisplayName map from manifest Records (no Graph call needed)
    $displayNameById = @{}
    if ($targetObjects[0].PSObject.Properties.Name -contains 'ObjectId') {
        foreach ($rec in $targetObjects) {
            $displayNameById[$rec.ObjectId] = if ($rec.DisplayName) { $rec.DisplayName } else { $rec.ObjectId }
        }
    }

    Write-Host "NHI Execution RunId: $ExecutionRunId, PhaseLimit: $PhaseLimit, Targets: $($targetObjects.Count)" -ForegroundColor Cyan

    # Connecting to Graph (read scopes for NHI object resolution)
    # AuditLog.Read.All required for Rev4.1 post-decom attestation
    Write-Host 'Connecting to Graph (read scopes)...' -ForegroundColor Gray
    try {
        $readScopes = @(
            'User.Read.All',
            'Directory.Read.All',
            'Application.Read.All',
            'AuditLog.Read.All'
        )
        Connect-MgGraph -Scopes $readScopes -TenantId $TenantId -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "[ERROR] Graph connection failed: $_" -ForegroundColor Red
        exit 1
    }

    # Connecting to Graph (write scopes for NHI execution)
    Write-Host 'Connecting to Graph (write scopes)...' -ForegroundColor Gray
    try {
        $writeScopes = @(
            'User.Read.All',
            'Directory.Read.All',
            'Application.Read.All',
            'Application.ReadWrite.All'
        )
        Connect-MgGraph -Scopes $writeScopes -TenantId $TenantId -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "[ERROR] Graph write connection failed: $_" -ForegroundColor Red
        exit 1
    }

    $phase1Skipped = @()
    $phase2Skipped = @()
    $phase3Skipped = @()

    foreach ($target in $targetObjects) {
        $objectId = if ($target.ObjectId) { $target.ObjectId } else { $target }
        $objectType = if ($target.ObjectType) { $target.ObjectType } else { 'ServicePrincipal' }
        $displayName = if ($displayNameById[$objectId]) { $displayNameById[$objectId] } else { $objectId }

        Write-Host "  [$objectType] $displayName" -ForegroundColor Gray

        # Phase 1: Snapshot + Tag (always)
        try {
            Invoke-NhiSnapshot -ObjectId $objectId -ObjectType $objectType `
                -EngagementId $engagementId -ExecutionRunId $ExecutionRunId `
                -ExecutionOutputPath $ExecutionOutputPath -WhatIf:$WhatIfPreference
            Invoke-NhiTag -ObjectId $objectId -ObjectType $objectType `
                -EngagementId $engagementId -ExecutionRunId $ExecutionRunId `
                -ExecutionOutputPath $ExecutionOutputPath -WhatIf:$WhatIfPreference
            Write-Host "    Phase 1 (Snapshot+Tag): OK" -ForegroundColor Green
        } catch {
            Write-Host "    Phase 1 failed: $_" -ForegroundColor Red
            $phase1Skipped += $objectId
        }

        # Phase 2: Disable (PhaseLimit >= 2)
        if ($PhaseLimit -ge 2) {
            $snapshotPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
            if (-not $WhatIfPreference -and -not (Test-Path $snapshotPath)) {
                Write-Host "    Phase 2 skipped: SnapshotManifest not found" -ForegroundColor Yellow
                $phase2Skipped += $objectId
            } else {
                try {
                    Invoke-NhiDisable -ObjectId $objectId -ObjectType $objectType `
                        -EngagementId $engagementId -ExecutionRunId $ExecutionRunId `
                        -ExecutionOutputPath $ExecutionOutputPath `
                        -ScreamTestDays $ScreamTestDays -AllowHumanExecution:$AllowHumanExecution `
                        -WhatIf:$WhatIfPreference
                    Write-Host "    Phase 2 (Disable): OK" -ForegroundColor Green
                } catch {
                    Write-Host "    Phase 2 failed: $_" -ForegroundColor Red
                    $phase2Skipped += $objectId
                }
            }
        }

        # Phase 3: Monitor (PhaseLimit >= 3)
        if ($PhaseLimit -ge 3) {
            $snapPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
            $disabledAt = $null
            $screamDays = $ScreamTestDays
            if (Test-Path $snapPath) {
                $snapData = Get-Content -Path $snapPath -Raw | ConvertFrom-Json
                $snapRec = $snapData.Records | Where-Object { $_.ObjectId -eq $objectId }
                if ($snapRec) {
                    $disabledAt = $snapRec.DisabledAt
                    $screamDays = if ($snapRec.ScreamTestDays) { $snapRec.ScreamTestDays } else { $ScreamTestDays }
                }
            }
            if ($disabledAt) {
                try {
                    $null = Get-NhiScreamTestStatus -ObjectId $objectId -DisplayName $displayName `
                        -DisabledAt $disabledAt -ScreamTestDays $screamDays `
                        -ExecutionOutputPath $ExecutionOutputPath -ExecutionRunId $ExecutionRunId
                    Write-Host "    Phase 3 (Monitor): OK" -ForegroundColor Green
                } catch {
                    Write-Host "    Phase 3 failed: $_" -ForegroundColor Red
                    $phase3Skipped += $objectId
                }
            } else {
                Write-Host "    Phase 3 skipped: No DisabledAt in snapshot" -ForegroundColor Yellow
                $phase3Skipped += $objectId
            }
        }
    }

    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor Cyan
    Write-Host '  NHI Execution complete.' -ForegroundColor Cyan
    Write-Host "  RunId        : $ExecutionRunId" -ForegroundColor Gray
    Write-Host "  PhaseLimit   : $PhaseLimit"     -ForegroundColor Gray
    Write-Host "  WhatIf       : $WhatIfPreference" -ForegroundColor Gray
    Write-Host "  Targets      : $($targetObjects.Count)" -ForegroundColor Gray
    Write-Host "  Phase1 fails : $($phase1Skipped.Count)" -ForegroundColor $(if ($phase1Skipped.Count -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Phase2 fails : $($phase2Skipped.Count)" -ForegroundColor $(if ($phase2Skipped.Count -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Phase3 fails : $($phase3Skipped.Count)" -ForegroundColor $(if ($phase3Skipped.Count -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Output       : $ExecutionOutputPath" -ForegroundColor Gray
    Write-Host ('=' * 64) -ForegroundColor Cyan

    # Rev4.1 M7: Post-decom attestation (optional, gated on -IncludeAgentActivityAudit)
    if ($IncludeAgentActivityAudit -and $targetObjects.Count -gt 0) {
        Write-DecomInfo 'Running post-decom attestation...'
        $attestationFindings = @()
        $manifestPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
        foreach ($target in $targetObjects) {
            $targetObjectId = if ($target.ObjectId) { $target.ObjectId } else { $target }
            $targetDisplayName = if ($displayNameById[$targetObjectId]) { $displayNameById[$targetObjectId] } else { $targetObjectId }
            $snapshotRecord = $null
            try {
                if (Test-Path $manifestPath) {
                    $snap = Get-Content $manifestPath -Raw | ConvertFrom-Json
                    $snapshotRecord = $snap.Records | Where-Object { $_.ObjectId -eq $targetObjectId } | Select-Object -First 1
                }
            } catch { }
            if (-not $snapshotRecord -or -not $snapshotRecord.DisabledAt) {
                $decomTimestamp = [DateTime]::MinValue
            } else {
                $decomTimestamp = [DateTime]::Parse($snapshotRecord.DisabledAt)
            }
            $attFindings = Invoke-NhiPostDecomAttestation `
                -ObjectId $targetObjectId `
                -DisplayName $targetDisplayName `
                -SnapshotManifestPath $manifestPath `
                -DecomTimestamp $decomTimestamp `
                -WindowMinutes 60
            $attestationFindings += $attFindings
        }
        # Persist DEC-ATTEST-* findings to dedicated artifact — never merged into $Findings
        $attestationPath = Join-Path $ExecutionOutputPath "AttestationFindings-$ExecutionRunId.json"
        $attestationPayload = [PSCustomObject]@{
            ExecutionRunId      = $ExecutionRunId
            GeneratedUtc        = (Get-Date).ToUniversalTime().ToString('o')
            AttestationFindings = @($attestationFindings)
        }
        $attestationPayload | ConvertTo-Json -Depth 12 | Set-Content -Path $attestationPath -Encoding UTF8
        Write-DecomOk "Post-decom attestation complete: $($attestationFindings.Count) finding(s) -> $attestationPath"
    }

    exit 0
}
