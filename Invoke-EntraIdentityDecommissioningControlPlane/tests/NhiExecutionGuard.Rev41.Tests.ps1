#Requires -Version 5.1
# ══════════════════════════════════════════════════════════════════════════════
# NhiExecutionGuard.Rev41.Tests.ps1 — Rev4.1 M1
# Tests for NhiExecutionGuard.psm1 exports:
#   Test-NhiExecutionModuleClean  — primary guard (raw-string scan)
#   Get-FileCommandNames           — AST scanner (migrated/extended from M36)
# ══════════════════════════════════════════════════════════════════════════════

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiExecutionGuard.psm1') -Force -DisableNameChecking

    $Script:NhiBlockedCmdlets = @(
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
        'HardDeleteServicePrincipal'
        'Remove-MgServicePrincipalByAppId'
    )

    $Script:SchemaModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiExecutionSchema.psm1'
    $Script:ExecModulePath   = Join-Path $PSScriptRoot '..\src\Modules\NhiExecution.psm1'
}

AfterAll {
    Remove-Module 'NhiExecutionGuard' -Force -ErrorAction SilentlyContinue
}

# ══════════════════════════════════════════════════════════════════════════════
# Test-NhiExecutionModuleClean — positive cases (must NOT throw)
# ══════════════════════════════════════════════════════════════════════════════

Describe 'Test-NhiExecutionModuleClean — positive cases ($null return)' -Tag 'Rev41', 'Safety' {

    It 'Update-MgServicePrincipal in a file does NOT trigger the guard' {
        $tmp = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            [System.IO.File]::WriteAllText($tmp, @'
Import-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
Update-MgServicePrincipal -ServicePrincipalId 'abc123' -DisplayName 'Test'
'@, [System.Text.UTF8Encoding]::new($false))
            $result = Test-NhiExecutionModuleClean -ModulePaths $tmp
            $result | Should -BeNullOrEmpty
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Two clean files — both pass, no throw' {
        $tmp1 = [System.IO.Path]::GetTempFileName() + '.ps1'
        $tmp2 = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            [System.IO.File]::WriteAllText($tmp1, 'Get-MgServicePrincipal', [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::WriteAllText($tmp2, 'Get-MgUser', [System.Text.UTF8Encoding]::new($false))
            { Test-NhiExecutionModuleClean -ModulePaths @($tmp1, $tmp2) } | Should -Not -Throw
        } finally {
            Remove-Item $tmp1, $tmp2 -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Missing file — skipped silently, no throw' {
        $tmp = [System.IO.Path]::GetTempPath() + [guid]::NewGuid().ToString() + '.ps1'
        # $tmp does NOT exist — guard should continue past it
        { Test-NhiExecutionModuleClean -ModulePaths $tmp } | Should -Not -Throw
    }

    It 'Pipeline input — single clean file passed via pipeline' {
        $tmp = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            [System.IO.File]::WriteAllText($tmp, 'Connect-MgGraph -SkipAccountSelector', [System.Text.UTF8Encoding]::new($false))
            $result = $tmp | Test-NhiExecutionModuleClean
            $result | Should -BeNullOrEmpty
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# Test-NhiExecutionModuleClean — blocked cmdlet detection
# ══════════════════════════════════════════════════════════════════════════════

Describe 'Test-NhiExecutionModuleClean — blocked cmdlet detection' -Tag 'Rev41', 'Safety' {
    # Parameterized sweep across all 12 blocked cmdlet names.
    # Each It injects the blocked cmdlet into a temp file and asserts the guard
    # throws with that cmdlet name in the error message.

    BeforeAll {
        $Script:testCases = $Script:NhiBlockedCmdlets | ForEach-Object { @{blocked = $_ } }
    }

    It 'Guard throws when file contains "<blocked>"' -TestCases $Script:testCases {
        param($blocked)
        $tmp = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            $content = "Import-Module Microsoft.Graph.Authentication`n$blocked -ServicePrincipalId 'fake'"
            [System.IO.File]::WriteAllText($tmp, $content, [System.Text.UTF8Encoding]::new($false))
            { Test-NhiExecutionModuleClean -ModulePaths $tmp } | Should -Throw
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Guard early-exits on first violation — error contains cmdlet name' {
        $tmp = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            [System.IO.File]::WriteAllText($tmp, 'Remove-MgServicePrincipal -ServicePrincipalId "fake"', [System.Text.UTF8Encoding]::new($false))
            { Test-NhiExecutionModuleClean -ModulePaths $tmp } | Should -Throw "*Remove-MgServicePrincipal*"
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Guard catches blocked cmdlet appearing twice in same file' {
        $tmp = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            $content = @'
Remove-MgApplication -ApplicationId 'a'
Remove-MgApplication -ApplicationId 'b'
'@
            [System.IO.File]::WriteAllText($tmp, $content, [System.Text.UTF8Encoding]::new($false))
            { Test-NhiExecutionModuleClean -ModulePaths $tmp } | Should -Throw
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Mixed array — one clean, one dirty — guard throws' {
        $tmp1 = [System.IO.Path]::GetTempFileName() + '.ps1'
        $tmp2 = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            [System.IO.File]::WriteAllText($tmp1, 'Get-MgServicePrincipal', [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::WriteAllText($tmp2, 'Remove-MgApplication -ApplicationId "fake"', [System.Text.UTF8Encoding]::new($false))
            { Test-NhiExecutionModuleClean -ModulePaths @($tmp1, $tmp2) } | Should -Throw
        } finally {
            Remove-Item $tmp1, $tmp2 -Force -ErrorAction SilentlyContinue
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# Get-FileCommandNames — AST scanner correctness
# ══════════════════════════════════════════════════════════════════════════════

Describe 'Get-FileCommandNames — AST scanner correctness' -Tag 'Rev41', 'Safety' {

    It 'Finds Update-MgServicePrincipal in real NhiExecution.psm1 source' {
        $cmds = Get-FileCommandNames -Path $Script:ExecModulePath
        $cmds.Contains('Update-MgServicePrincipal') | Should -Be $true
    }

    It 'Does NOT find blocked Remove-MgServicePrincipal in NhiExecution.psm1' {
        $cmds = Get-FileCommandNames -Path $Script:ExecModulePath
        $cmds.Contains('Remove-MgServicePrincipal') | Should -Be $false
    }

    It 'String literal — "Remove-MgApplication" in quotes is NOT reported as command' {
        $tmp = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            [System.IO.File]::WriteAllText($tmp, '$x = "Remove-MgApplication"', [System.Text.UTF8Encoding]::new($false))
            $cmds = Get-FileCommandNames -Path $tmp
            $cmds.Contains('Remove-MgApplication') | Should -Be $false
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Hashtable key — @{ Remove-MgApplication = $true } is NOT reported' {
        $tmp = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            [System.IO.File]::WriteAllText($tmp, '@{ Remove-MgApplication = $true }', [System.Text.UTF8Encoding]::new($false))
            $cmds = Get-FileCommandNames -Path $tmp
            $cmds.Contains('Remove-MgApplication') | Should -Be $false
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Malformed file — parse errors return empty set, do not throw' {
        $tmp = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            [System.IO.File]::WriteAllText($tmp, 'function { invalid syntax here', [System.Text.UTF8Encoding]::new($false))
            $cmds = Get-FileCommandNames -Path $tmp
            $cmds.ItemCount() | Should -Be 0
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Commented cmdlet — # Remove-MgApplication — is NOT reported (CommandAst skips comments)' {
        $tmp = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            [System.IO.File]::WriteAllText($tmp, '# Remove-MgApplication', [System.Text.UTF8Encoding]::new($false))
            $cmds = Get-FileCommandNames -Path $tmp
            $cmds.Contains('Remove-MgApplication') | Should -Be $false
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Recurse=$false — nested CommandAst NOT included' {
        $tmp = [System.IO.Path]::GetTempFileName() + '.ps1'
        try {
            # Write a file with a cmdlet inside a scriptblock which needs recurse
            [System.IO.File]::WriteAllText($tmp, @'
& {
    Get-MgServicePrincipal
}
'@, [System.Text.UTF8Encoding]::new($false))
            $withRecurse    = Get-FileCommandNames -Path $tmp -Recurse $true
            $withoutRecurse = Get-FileCommandNames -Path $tmp -Recurse $false
            $withRecurse.Contains('Get-MgServicePrincipal')    | Should -Be $true
            $withoutRecurse.Contains('Get-MgServicePrincipal') | Should -Be $false
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'NhiExecutionSchema.psm1 — zero blocked cmdlets detected via AST' {
        $cmds = Get-FileCommandNames -Path $Script:SchemaModulePath
        foreach ($blocked in $Script:NhiBlockedCmdlets) {
            $cmds.Contains($blocked) | Should -Be $false ("Schema should not contain $blocked")
        }
    }
}