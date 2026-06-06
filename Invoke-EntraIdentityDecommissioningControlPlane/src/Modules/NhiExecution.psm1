#Requires -Version 5.1
<#
.SYNOPSIS
    NHI decommission execution functions — Rev4.0.

.DESCRIPTION
    Phase 1 execution: Snapshot and Tag.

    Writes to Entra ID (ServicePrincipal only). ManagedIdentity and User are
    scaffold — No Entra write, local artifact only in Rev4.0.

    IMPORTANT: New-DecomFinding is NEVER called from this module.

    Frozen identity hooks:
    - ManagedIdentity: No Entra write. Log skip reason to manifest. No exception.
    - User: No Entra write. Throw from Invoke-NhiDisable without -AllowHumanExecution.
      Log scaffold intent when -AllowHumanExecution IS passed. No Entra write.
#>

# ── INTERNAL HELPERS ──────────────────────────────────────────────────────────

function _PsObjectToHashtable {
    # Converts a PSCustomObject to a hashtable for cross-version compatibility.
    # .ToHashtable() does not exist on PSObject in PowerShell 5.1/7.
    param(
        [Parameter(ValueFromPipeline)]
        [PSCustomObject]$InputObject
    )
    process {
        if ($null -eq $InputObject) { return $null }
        $hash = @{ }
        foreach ($prop in $InputObject.PSObject.Properties) {
            $hash[$prop.Name] = $prop.Value
        }
        $hash
    }
}

function _WriteSnapshotManifest {
    param(
        [Parameter(Mandatory)]
        [string]$ExecutionOutputPath,

        [Parameter(Mandatory)]
        [string]$ExecutionRunId,

        [Parameter(Mandatory)]
        [hashtable]$Record
    )

    $manifestPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"

    if (-not (Test-Path -Path $ExecutionOutputPath -PathType Container)) {
        throw "Invoke-NhiSnapshot: ExecutionOutputPath '$ExecutionOutputPath' does not exist or is not a directory."
    }

    [hashtable]$manifest = @{}
    [bool]$fileExisted = $false

    if (Test-Path -Path $manifestPath -PathType Leaf) {
        $fileExisted = $true
        try {
            $jsonContent = Get-Content -Path $manifestPath -Raw -Encoding UTF8
            $manifest = $jsonContent | ConvertFrom-Json | _PsObjectToHashtable
        } catch {
            throw "Invoke-NhiSnapshot: Could not parse existing SnapshotManifest at '$manifestPath'. Error: $($_.Exception.Message)"
        }
    }

    if (-not $fileExisted) {
        # First Record for this RunId: create outer structure
        $manifest['ExecutionRunId'] = $ExecutionRunId
        $manifest['EngagementId'] = $Record.EngagementId
        $manifest['CreatedAt'] = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        $manifest['Records'] = @()
    }

    # Update or append Record
    [bool]$appended = $false
    [object[]]$records = $manifest['Records']
    for ($i = 0; $i -lt $records.Count; $i++) {
        if ($records[$i].ObjectId -eq $Record.ObjectId) {
            $records[$i] = [PSCustomObject]$Record
            $appended = $true
            break
        }
    }
    if (-not $appended) {
        $records += [PSCustomObject]$Record
    }
    $manifest['Records'] = $records

    $jsonOut = $manifest | ConvertTo-Json -Depth 10 -Compress
    [System.IO.File]::WriteAllText($manifestPath, $jsonOut, [System.Text.UTF8Encoding]::new($false))
}

function _WriteWhatIfEntry {
    param(
        [Parameter(Mandatory)]
        [string]$ExecutionOutputPath,

        [Parameter(Mandatory)]
        [hashtable]$ActionIntent
    )

    $whatIfPath = Join-Path $ExecutionOutputPath 'NhiExecutionWhatIf.json'

    [object[]]$entries = @()
    if (Test-Path -Path $whatIfPath -PathType Leaf) {
        try {
            $existingJson = Get-Content -Path $whatIfPath -Raw -Encoding UTF8
            $entries = @($existingJson | ConvertFrom-Json)
        } catch {
            # If malformed, start fresh
            $entries = @()
        }
    }

    $entries += [PSCustomObject]@{
        Timestamp      = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        ObjectId       = $ActionIntent.ObjectId
        ObjectType     = $ActionIntent.ObjectType
        Action         = $ActionIntent.Action
        EngagementId   = $ActionIntent.EngagementId
        ExecutionRunId = $ActionIntent.ExecutionRunId
    }

    $jsonOut = $entries | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($whatIfPath, $jsonOut, [System.Text.UTF8Encoding]::new($false))
}

function _SnapshotServicePrincipal {
    param(
        [Parameter(Mandatory)]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [string]$EngagementId,

        [Parameter(Mandatory)]
        [string]$ExecutionRunId,

        [Parameter(Mandatory)]
        [string]$ExecutionOutputPath,

        [Parameter()]
        [switch]$WhatIf
    )

    $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

    # ── Read current SP state from Graph (read-only) ──────────────────────────
    $sp = Get-MgServicePrincipal -ServicePrincipalId $ObjectId `
        -Property 'DisplayName,AppId,AccountEnabled,Notes,AppRoles,OAuth2PermissionGrants,KeyCredentials,PasswordCredentials' `
        -ErrorAction Stop

    $owners = @()
    try {
        $owners = @(Get-MgServicePrincipalOwner -ServicePrincipalId $ObjectId -All `
            -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    } catch { $owners = @() }

    [string]$priorNotes = $null
    if ($null -ne $sp.Notes) { $priorNotes = $sp.Notes }

    $appRolesCount     = $sp.AppRoles.Count
    $oauth2Count       = $sp.OAuth2PermissionGrants.Count
    $keyCredCount      = $sp.KeyCredentials.Count
    $pwdCredCount      = $sp.PasswordCredentials.Count

    # ── Build Record ──────────────────────────────────────────────────────────
    [hashtable]$record = @{
        ObjectId       = $ObjectId
        ObjectType     = 'ServicePrincipal'
        DisplayName    = $sp.DisplayName
        AppId          = $sp.AppId
        PriorAccountEnabled = $sp.AccountEnabled
        PriorNotes     = $priorNotes
        SnapshotTimestamp = $timestamp
        DisabledAt     = $null
        ScreamTestDays = 0
        SkipReason     = $null
        AdditionalFields = @{
            AppRolesCount          = $appRolesCount
            OAuth2PermissionGrantsCount = $oauth2Count
            KeyCredentialsCount    = $keyCredCount
            PasswordCredentialsCount   = $pwdCredCount
            Owners                 = $owners
        }
        EngagementId   = $EngagementId
    }

    _WriteSnapshotManifest -ExecutionOutputPath $ExecutionOutputPath `
        -ExecutionRunId $ExecutionRunId -Record $record

    # ── Tag the SP in Entra ────────────────────────────────────────────────────
    $tagValue = "DecomSnapshot:$timestamp`:$EngagementId"
    Update-MgServicePrincipal -ServicePrincipalId $ObjectId -Notes $tagValue -ErrorAction Stop
}

function _SnapshotManagedIdentity {
    param(
        [Parameter(Mandatory)]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [string]$EngagementId,

        [Parameter(Mandatory)]
        [string]$ExecutionRunId,

        [Parameter(Mandatory)]
        [string]$ExecutionOutputPath,

        [Parameter()]
        [switch]$WhatIf
    )

    $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

    # Read current MI state via Graph (read-only)
    $mi = $null
    try {
        $mi = Get-MgServicePrincipal -ServicePrincipalId $ObjectId `
            -Property 'DisplayName,AppId,AccountEnabled,AppRoles,KeyCredentials,PasswordCredentials' `
            -ErrorAction Stop
    } catch {
        throw "Invoke-NhiSnapshot ManagedIdentity: Failed to read MI state from Graph. ObjectId: $ObjectId. Error: $($_.Exception.Message)"
    }

    $appRolesCount  = if ($mi.AppRoles) { $mi.AppRoles.Count } else { 0 }
    $keyCredCount   = if ($mi.KeyCredentials) { $mi.KeyCredentials.Count } else { 0 }
    $pwdCredCount   = if ($mi.PasswordCredentials) { $mi.PasswordCredentials.Count } else { 0 }

    [hashtable]$record = @{
        ObjectId           = $ObjectId
        ObjectType         = 'ManagedIdentity'
        DisplayName        = $mi.DisplayName
        AppId              = $mi.AppId
        PriorAccountEnabled = if ($null -ne $mi.AccountEnabled) { $mi.AccountEnabled } else { $false }
        PriorNotes         = $null
        SnapshotTimestamp  = $timestamp
        DisabledAt         = $null
        ScreamTestDays     = 0
        SkipReason         = "SnapshotTagWrite skipped for ManagedIdentity in Rev4.0"
        AdditionalFields   = @{
            AppRolesCount            = $appRolesCount
            KeyCredentialsCount      = $keyCredCount
            PasswordCredentialsCount = $pwdCredCount
        }
        EngagementId       = $EngagementId
    }

    _WriteSnapshotManifest -ExecutionOutputPath $ExecutionOutputPath `
        -ExecutionRunId $ExecutionRunId -Record $record
    # No Entra write for MI in Rev4.0
}

function _SnapshotUser {
    param(
        [Parameter(Mandatory)]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [string]$EngagementId,

        [Parameter(Mandatory)]
        [string]$ExecutionRunId,

        [Parameter(Mandatory)]
        [string]$ExecutionOutputPath,

        [Parameter()]
        [switch]$WhatIf
    )

    $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

    $user = $null
    try {
        $user = Get-MgUser -UserId $ObjectId `
            -Property 'DisplayName,AccountEnabled,UserPrincipalName' `
            -ErrorAction Stop
    } catch {
        throw "Invoke-NhiSnapshot User: Failed to read User state from Graph. ObjectId: $ObjectId. Error: $($_.Exception.Message)"
    }

    $assignedLicenseCount = 0
    try { $assignedLicenseCount = @((Get-MgUserLicenseDetail -UserId $ObjectId -All -ErrorAction SilentlyContinue)).Count } catch { }

    $groupCount = 0
    try {
        $groupCount = @((Get-MgUserMemberOf -UserId $ObjectId -All -ErrorAction SilentlyContinue)).Count
    } catch { }

    $appRoleCount = 0
    try {
        $appRoleCount = @((Get-MgUserAppRoleAssignment -UserId $ObjectId -All -ErrorAction SilentlyContinue)).Count
    } catch { }

    [hashtable]$record = @{
        ObjectId           = $ObjectId
        ObjectType         = 'User'
        DisplayName        = $user.DisplayName
        AppId              = $null
        PriorAccountEnabled = if ($null -ne $user.AccountEnabled) { $user.AccountEnabled } else { $true }
        PriorNotes         = $null
        SnapshotTimestamp  = $timestamp
        DisabledAt         = $null
        ScreamTestDays     = 0
        SkipReason         = "SnapshotTagWrite skipped for User in Rev4.0"
        AdditionalFields   = @{
            AssignedLicensesCount  = $assignedLicenseCount
            GroupMembershipsCount   = $groupCount
            AppRoleAssignmentsCount = $appRoleCount
            UserPrincipalName       = $user.UserPrincipalName
        }
        EngagementId       = $EngagementId
    }

    _WriteSnapshotManifest -ExecutionOutputPath $ExecutionOutputPath `
        -ExecutionRunId $ExecutionRunId -Record $record
    # No Entra write for User in Rev4.0
}

# ── INTERNAL: UPDATE-SNAPSHOT-RECORD ─────────────────────────────────────────
# Reads SnapshotManifest, finds/mutates Record by ObjectId index, writes back.
# Converts to hashtable so indexer set works (PSObject indexer set throws).
# Records field always becomes an array after @($records) wrap.

function _UpdateSnapshotRecord {
    param(
        [Parameter(Mandatory)]
        [string]$ExecutionOutputPath,

        [Parameter(Mandatory)]
        [string]$ExecutionRunId,

        [Parameter(Mandatory)]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [scriptblock]$Updater  # param($rec) { $rec['DisabledAt'] = ... }
    )

    $manifestPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
    if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
        throw "SnapshotManifest-$ExecutionRunId.json not found at '$manifestPath'."
    }

    $jsonContent = $null
    try {
        $jsonContent = Get-Content -Path $manifestPath -Raw -Encoding UTF8
    } catch {
        throw "Could not read SnapshotManifest at '$manifestPath'. Error: $($_.Exception.Message)"
    }

    [hashtable]$manifest = $null
    try {
        $manifest = $jsonContent | ConvertFrom-Json | _PsObjectToHashtable
    } catch {
        throw "Could not parse SnapshotManifest at '$manifestPath'. Error: $($_.Exception.Message)"
    }

    # Convert each PSCustomObject record to hashtable so indexer access works.
    # _PsObjectToHashtable does NOT recursively convert nested objects, so each
    # record must be explicitly converted here — this is the core fix for M33.
    [object[]]$records = @($manifest['Records'])
    $matches = 0
    for ($i = 0; $i -lt $records.Count; $i++) {
        $records[$i] = _PsObjectToHashtable $records[$i]
        if ($records[$i]['ObjectId'] -eq $ObjectId) {
            if (++$matches -ge 2) {
                throw "Multiple snapshot Records found for ObjectId '$ObjectId' in SnapshotManifest-$ExecutionRunId.json. Abort to prevent ambiguity."
            }
        }
    }

    if ($matches -eq 0) {
        throw "No snapshot Record found for ObjectId '$ObjectId' in SnapshotManifest-$ExecutionRunId.json."
    }

    # Second pass: find the index and invoke updater via hashtable reference.
    # Modifications to $rec hashtable persist because hashtables are reference types.
    [int]$matchIndex = -1
    for ($i = 0; $i -lt $records.Count; $i++) {
        if ($records[$i]['ObjectId'] -eq $ObjectId) {
            $matchIndex = $i
            break
        }
    }

    # Invoke the updater scriptblock on the matched record (now a hashtable).
    # hashtables are reference types — modifications to $rec inside the scriptblock
    # persist in the parent's $records array without needing [ref].
    $rec = $records[$matchIndex]
    & $Updater $rec

    # Reassemble and write back
    $manifest['Records'] = $records
    $jsonOut = $manifest | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($manifestPath, $jsonOut, [System.Text.UTF8Encoding]::new($false))
}

# ── PUBLIC FUNCTIONS ───────────────────────────────────────────────────────────

function Invoke-NhiSnapshot {
    <#
    .SYNOPSIS
        Captures the current state of a ServicePrincipal, ManagedIdentity, or User
        into a local SnapshotManifest and (for SP only) tags the object in Entra ID.

    .PARAMETER ObjectId
        The Entra ObjectId of the target.

    .PARAMETER ObjectType
        One of: ServicePrincipal, ManagedIdentity, User.

    .PARAMETER EngagementId
        Engagement identifier for tagging and manifest correlation.

    .PARAMETER ExecutionRunId
        Execution run identifier (yyyyMMdd_HHmmss format).

    .PARAMETER ExecutionOutputPath
        Directory where SnapshotManifest-{RunId}.json and NhiExecutionWhatIf.json
        are written.

    .PARAMETER WhatIf
        If set: writes action intent to NhiExecutionWhatIf.json without calling any
        Graph cmdlet (read or write).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [ValidateSet('ServicePrincipal', 'ManagedIdentity', 'User')]
        [string]$ObjectType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EngagementId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExecutionRunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExecutionOutputPath,

        [Parameter()]
        [switch]$WhatIf
    )

    # WhatIf: write intent only, no Graph call
    if ($WhatIf) {
        _WriteWhatIfEntry -ExecutionOutputPath $ExecutionOutputPath -ActionIntent @{
            ObjectId       = $ObjectId
            ObjectType     = $ObjectType
            Action         = 'Snapshot'
            EngagementId   = $EngagementId
            ExecutionRunId = $ExecutionRunId
        }
        return
    }

    # Non-WhatIf: validate ExecutionOutputPath exists first
    if (-not (Test-Path -Path $ExecutionOutputPath -PathType Container)) {
        throw "Invoke-NhiSnapshot: ExecutionOutputPath '$ExecutionOutputPath' does not exist or is not a directory."
    }

    switch ($ObjectType) {
        'ServicePrincipal' { _SnapshotServicePrincipal -ObjectId $ObjectId -EngagementId $EngagementId -ExecutionRunId $ExecutionRunId -ExecutionOutputPath $ExecutionOutputPath }
        'ManagedIdentity'  { _SnapshotManagedIdentity  -ObjectId $ObjectId -EngagementId $EngagementId -ExecutionRunId $ExecutionRunId -ExecutionOutputPath $ExecutionOutputPath }
        'User'             { _SnapshotUser             -ObjectId $ObjectId -EngagementId $EngagementId -ExecutionRunId $ExecutionRunId -ExecutionOutputPath $ExecutionOutputPath }
    }
}

function Invoke-NhiTag {
    <#
    .SYNOPSIS
        Writes a DecomTagged marker to the Notes field of a ServicePrincipal.
        For ManagedIdentity and User: scaffolds without Entra write.

    .PARAMETER ObjectId
    .PARAMETER ObjectType
    .PARAMETER EngagementId
    .PARAMETER ExecutionRunId
    .PARAMETER ExecutionOutputPath
    .PARAMETER WhatIf
        If set: writes action intent to NhiExecutionWhatIf.json without calling
        any Graph cmdlet.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [ValidateSet('ServicePrincipal', 'ManagedIdentity', 'User')]
        [string]$ObjectType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EngagementId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExecutionRunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExecutionOutputPath,

        [Parameter()]
        [switch]$WhatIf
    )

    # WhatIf: intent only, no manifest read, no Graph call
    if ($WhatIf) {
        _WriteWhatIfEntry -ExecutionOutputPath $ExecutionOutputPath -ActionIntent @{
            ObjectId       = $ObjectId
            ObjectType     = $ObjectType
            Action         = 'Tag'
            EngagementId   = $EngagementId
            ExecutionRunId = $ExecutionRunId
        }
        return
    }

    # Verify SnapshotManifest exists (tag requires snapshot first)
    $manifestPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
    if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
        throw "Invoke-NhiTag: SnapshotManifest-$ExecutionRunId.json not found at '$manifestPath'. Snapshot must precede Tag."
    }

    # Read manifest and find Record for this ObjectId
    try {
        $jsonContent = Get-Content -Path $manifestPath -Raw -Encoding UTF8
        $manifest = $jsonContent | ConvertFrom-Json
    } catch {
        throw "Invoke-NhiTag: Could not parse SnapshotManifest at '$manifestPath'. Error: $($_.Exception.Message)"
    }

    [object]$matchedRecord = $null
    [int]$matchCount = 0
    foreach ($rec in $manifest.Records) {
        if ($rec.ObjectId -eq $ObjectId) {
            $matchedRecord = $rec
            $matchCount++
        }
    }

    if ($matchCount -eq 0) {
        throw "Invoke-NhiTag: No snapshot Record found for ObjectId '$ObjectId' in SnapshotManifest-$ExecutionRunId.json."
    }
    if ($matchCount -gt 1) {
        throw "Invoke-NhiTag: Multiple snapshot Records found for ObjectId '$ObjectId' in SnapshotManifest-$ExecutionRunId.json. Abort to prevent ambiguity."
    }

    switch ($ObjectType) {
        'ServicePrincipal' {
            $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
            $tagValue = "DecomTagged:$timestamp`:$EngagementId"
            Update-MgServicePrincipal -ServicePrincipalId $ObjectId -Notes $tagValue -ErrorAction Stop
        }
        'ManagedIdentity' {
            Write-Verbose "Invoke-NhiTag: TagWrite skipped for ManagedIdentity in Rev4.0 (no Entra write)."
        }
        'User' {
            Write-Verbose "Invoke-NhiTag: TagWrite skipped for User in Rev4.0 (no Entra write)."
        }
    }
}

function Invoke-NhiDisable {
    <#
    .SYNOPSIS
        Disables a ServicePrincipal (Entra write) or scaffolds a local manifest
        entry for ManagedIdentity/User.

    .PARAMETER ObjectId
    .PARAMETER ObjectType
    .PARAMETER EngagementId
    .PARAMETER ExecutionRunId
    .PARAMETER ExecutionOutputPath
    .PARAMETER ScreamTestDays
        Number of days before the scream-test period is considered complete.
        Always 0 for User objects (no Entra write).
    .PARAMETER AllowHumanExecution
        Required for User objects. Allows scaffolding without Entra write.
    .PARAMETER WhatIf
        If set: writes action intent to NhiExecutionWhatIf.json without calling
        any Graph cmdlet or reading the manifest.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [ValidateSet('ServicePrincipal', 'ManagedIdentity', 'User')]
        [string]$ObjectType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EngagementId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExecutionRunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExecutionOutputPath,

        [Parameter(Mandatory)]
        [ValidateRange(0, 3650)]
        [int]$ScreamTestDays,

        [Parameter()]
        [switch]$AllowHumanExecution,

        [Parameter()]
        [switch]$WhatIf
    )

    # WhatIf: intent only, no Graph call, no manifest read
    if ($WhatIf) {
        _WriteWhatIfEntry -ExecutionOutputPath $ExecutionOutputPath -ActionIntent @{
            ObjectId       = $ObjectId
            ObjectType     = $ObjectType
            Action         = 'Disable'
            EngagementId   = $EngagementId
            ExecutionRunId = $ExecutionRunId
        }
        return
    }

    switch ($ObjectType) {
        'ServicePrincipal' {
            $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

            # Update manifest Record, then Entra write
            _UpdateSnapshotRecord -ExecutionOutputPath $ExecutionOutputPath `
                -ExecutionRunId $ExecutionRunId -ObjectId $ObjectId -Updater {
                param($rec)
                $rec['DisabledAt']     = $timestamp
                $rec['ScreamTestDays'] = $ScreamTestDays
            }

            # Entra write: set AccountEnabled = $false
            Update-MgServicePrincipal -ServicePrincipalId $ObjectId `
                -AccountEnabled:$false -ErrorAction Stop
        }

        'ManagedIdentity' {
            # No Entra write for MI in Rev4.0.
            # Update manifest Record for monitoring purposes.
            try {
                _UpdateSnapshotRecord -ExecutionOutputPath $ExecutionOutputPath `
                    -ExecutionRunId $ExecutionRunId -ObjectId $ObjectId -Updater {
                    param($rec)
                    $rec['DisabledAt']     = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $rec['ScreamTestDays'] = $ScreamTestDays
                    $rec['SkipReason']     = 'Disable skipped for ManagedIdentity in Rev4.0'
                }
            } catch {
                # If snapshot was never taken, manifest update is skipped silently for MI.
                # This mirrors the BUILD-PROMPT: no exception, proceed.
            }
        }

        'User' {
            if (-not $AllowHumanExecution) {
                throw 'Invoke-NhiDisable: Human identity disable blocked. Pass -AllowHumanExecution to acknowledge scaffold-only intent (no Entra write).'
            }
            # AllowHumanExecution: no Entra write. No manifest update (scaffold only,
            # ScreamTestDays = 0 always per BUILD-PROMPT).
        }
    }
}

function Invoke-NhiRollbackDisable {
    <#
    .SYNOPSIS
        Restores AccountEnabled to the PriorAccountEnabled value stored in the
        SnapshotManifest Record for a ServicePrincipal. No-op for ManagedIdentity
        and User (no Entra write in Rev4.0).

    .PARAMETER ObjectId
    .PARAMETER ObjectType
    .PARAMETER ExecutionRunId
    .PARAMETER ExecutionOutputPath
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [ValidateSet('ServicePrincipal', 'ManagedIdentity', 'User')]
        [string]$ObjectType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExecutionRunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExecutionOutputPath
    )

    switch ($ObjectType) {
        'ServicePrincipal' {
            $manifestPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
            if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
                throw "Invoke-NhiRollbackDisable: SnapshotManifest-$ExecutionRunId.json not found at '$manifestPath'."
            }

            $jsonContent = $null
            try {
                $jsonContent = Get-Content -Path $manifestPath -Raw -Encoding UTF8
            } catch {
                throw "Invoke-NhiRollbackDisable: Could not read SnapshotManifest at '$manifestPath'. Error: $($_.Exception.Message)"
            }

            $records = @($null)
            try {
                [hashtable]$manifest = $jsonContent | ConvertFrom-Json | _PsObjectToHashtable
                # Convert each PSCustomObject record to hashtable so indexer access works
                [object[]]$rawRecords = @($manifest['Records'])
                $records = @()
                for ($ri = 0; $ri -lt $rawRecords.Count; $ri++) {
                    $records += _PsObjectToHashtable $rawRecords[$ri]
                }
            } catch {
                throw "Invoke-NhiRollbackDisable: Could not parse SnapshotManifest at '$manifestPath'. Error: $($_.Exception.Message)"
            }

            [int]$matchIndex = -1
            for ($i = 0; $i -lt $records.Count; $i++) {
                if ($records[$i]['ObjectId'] -eq $ObjectId) {
                    if ($matchIndex -ge 0) {
                        throw "Invoke-NhiRollbackDisable: Multiple snapshot Records found for ObjectId '$ObjectId' in SnapshotManifest-$ExecutionRunId.json. Abort to prevent ambiguity."
                    }
                    $matchIndex = $i
                }
            }

            if ($matchIndex -lt 0) {
                throw "Invoke-NhiRollbackDisable: No snapshot Record found for ObjectId '$ObjectId' in SnapshotManifest-$ExecutionRunId.json."
            }

            # Restore EXACTLY the prior AccountEnabled — NOT unconditional $true
            [bool]$restoreEnabled = $records[$matchIndex]['PriorAccountEnabled']
            Update-MgServicePrincipal -ServicePrincipalId $ObjectId `
                -AccountEnabled:$restoreEnabled -ErrorAction Stop
        }

        'ManagedIdentity' {
            # No Entra write for MI in Rev4.0
        }

        'User' {
            # No Entra write for User in Rev4.0
        }
    }
}

function Invoke-NhiRollbackTag {
    <#
    .SYNOPSIS
        Restores the PriorNotes value stored in the SnapshotManifest Record to
        the Notes field of a ServicePrincipal. No-op for ManagedIdentity and
        User (no Entra write in Rev4.0).

    .PARAMETER ObjectId
    .PARAMETER ObjectType
    .PARAMETER ExecutionRunId
    .PARAMETER ExecutionOutputPath
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [ValidateSet('ServicePrincipal', 'ManagedIdentity', 'User')]
        [string]$ObjectType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExecutionRunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExecutionOutputPath
    )

    switch ($ObjectType) {
        'ServicePrincipal' {
            $manifestPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
            if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
                throw "Invoke-NhiRollbackTag: SnapshotManifest-$ExecutionRunId.json not found at '$manifestPath'."
            }

            $jsonContent = $null
            try {
                $jsonContent = Get-Content -Path $manifestPath -Raw -Encoding UTF8
            } catch {
                throw "Invoke-NhiRollbackTag: Could not read SnapshotManifest at '$manifestPath'. Error: $($_.Exception.Message)"
            }

            $records = @($null)
            try {
                [hashtable]$manifest = $jsonContent | ConvertFrom-Json | _PsObjectToHashtable
                # Convert each PSCustomObject record to hashtable so indexer access works
                [object[]]$rawRecords = @($manifest['Records'])
                $records = @()
                for ($ri = 0; $ri -lt $rawRecords.Count; $ri++) {
                    $records += _PsObjectToHashtable $rawRecords[$ri]
                }
            } catch {
                throw "Invoke-NhiRollbackTag: Could not parse SnapshotManifest at '$manifestPath'. Error: $($_.Exception.Message)"
            }

            [int]$matchIndex = -1
            for ($i = 0; $i -lt $records.Count; $i++) {
                if ($records[$i]['ObjectId'] -eq $ObjectId) {
                    if ($matchIndex -ge 0) {
                        throw "Invoke-NhiRollbackTag: Multiple snapshot Records found for ObjectId '$ObjectId' in SnapshotManifest-$ExecutionRunId.json. Abort to prevent ambiguity."
                    }
                    $matchIndex = $i
                }
            }

            if ($matchIndex -lt 0) {
                throw "Invoke-NhiRollbackTag: No snapshot Record found for ObjectId '$ObjectId' in SnapshotManifest-$ExecutionRunId.json."
            }

            # Restore Priornotes exactly — null is a valid value (clears DecomTag)
            [string]$restoreNotes = $records[$matchIndex]['PriorNotes']
            Update-MgServicePrincipal -ServicePrincipalId $ObjectId -Notes $restoreNotes -ErrorAction Stop
        }

        'ManagedIdentity' {
            # No Entra write for MI in Rev4.0
        }

        'User' {
            # No Entra write for User in Rev4.0
        }
    }
}

# ── EXPORTS ─────────────────────────────────────────────────────────────────---

Export-ModuleMember -Function @(
    'Invoke-NhiSnapshot'
    'Invoke-NhiTag'
    'Invoke-NhiDisable'
    'Invoke-NhiRollbackDisable'
    'Invoke-NhiRollbackTag'
)
