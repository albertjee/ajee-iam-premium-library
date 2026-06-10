#Requires -Version 5.1
# Pester tests for M36 — Rev4.0 Destructive Cmdlet Guard (AST scanner)
# Uses CommandAst scanning. Hashtable keys and comment strings are NOT scanned.
# Only real command invocations are checked.

BeforeAll {
    # Target files for blocked cmdlet AST scan
    $Script:SchemaModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiExecutionSchema.psm1'
    $Script:ExecModulePath   = Join-Path $PSScriptRoot '..\src\Modules\NhiExecution.psm1'

    # The 12 blocked cmdlet names from the runtime guard (M35 BUILD-PROMPT Sec 5)
    $Script:BlockedCmdlets = @(
        'HardDeleteServicePrincipal'
        'Remove-MgServicePrincipal'
        'Remove-MgServicePrincipalByAppId'
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

    # Helper: extract all unique command names from a script file via CommandAst.
    # CommandAst captures ONLY real invocations — not hashtable keys or comment strings.
    function Get-FileCommandNames {
        param([string]$Path)
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $Path, [ref]$null, [ref]$errors)
        if ($errors.Count -gt 0) { throw "Parse errors in $Path : $($errors.Count)" }

        $cmdAsts = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $true)

        $cmdNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase)
        foreach ($cmd in $cmdAsts) {
            $name = $cmd.GetCommandName()
            if ($name) { $null = $cmdNames.Add($name) }
        }
        return $cmdNames
    }
}

AfterAll {
    Remove-Module 'NhiExecution' -Force -ErrorAction SilentlyContinue
    Remove-Module 'NhiExecutionSchema' -Force -ErrorAction SilentlyContinue
}

# ══════════════════════════════════════════════════════════════════════════════
# M36 — Destructive Cmdlet Guard: AST scanner
# Uses CommandAst — hashtable keys and string literals are NOT flagged.
# Only real command invocations (call operator, dot-sourced scripts, cmdlets)
# are caught.
# ══════════════════════════════════════════════════════════════════════════════

Describe 'Destructive Cmdlet Guard — CommandAst Scanner' -Tag 'Rev40', 'Safety' {
    Context 'NhiExecutionSchema.psm1 — blocked cmdlet scan' {
        BeforeAll {
            $Script:SchemaCommands = Get-FileCommandNames -Path $Script:SchemaModulePath
        }

        # 12 It blocks — one per blocked cmdlet name
        It 'NhiExecutionSchema.psm1: no invocation of HardDeleteSvcPrincipalBlocklist' {
            $Script:SchemaCommands.Contains('HardDeleteSvcPrincipalBlocklist') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: no invocation of Remove-MgServicePrincipal' {
            $Script:SchemaCommands.Contains('Remove-MgServicePrincipal') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: no invocation of Remove-MgServicePrincipalByAppId' {
            $Script:SchemaCommands.Contains('Remove-MgServicePrincipalByAppId') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: no invocation of Remove-MgApplication' {
            $Script:SchemaCommands.Contains('Remove-MgApplication') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: no invocation of Remove-MgApplicationPassword' {
            $Script:SchemaCommands.Contains('Remove-MgApplicationPassword') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: no invocation of Remove-MgApplicationKey' {
            $Script:SchemaCommands.Contains('Remove-MgApplicationKey') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: no invocation of Remove-MgServicePrincipalPassword' {
            $Script:SchemaCommands.Contains('Remove-MgServicePrincipalPassword') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: no invocation of Remove-MgServicePrincipalKey' {
            $Script:SchemaCommands.Contains('Remove-MgServicePrincipalKey') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: no invocation of Remove-MgServicePrincipalAppRoleAssignment' {
            $Script:SchemaCommands.Contains('Remove-MgServicePrincipalAppRoleAssignment') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: no invocation of Remove-MgOauth2PermissionGrant' {
            $Script:SchemaCommands.Contains('Remove-MgOauth2PermissionGrant') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: no invocation of Remove-MgServicePrincipalOwnerByRef' {
            $Script:SchemaCommands.Contains('Remove-MgServicePrincipalOwnerByRef') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: no invocation of Remove-MgServicePrincipalOwnerDirectoryObjectByRef' {
            $Script:SchemaCommands.Contains('Remove-MgServicePrincipalOwnerDirectoryObjectByRef') | Should -Be $false
        }

        It 'NhiExecutionSchema.psm1: ParseFile returns zero errors' {
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile(
                $Script:SchemaModulePath, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }

    Context 'NhiExecution.psm1 — blocked cmdlet scan' {
        BeforeAll {
            $Script:ExecCommands = Get-FileCommandNames -Path $Script:ExecModulePath
        }

        # 12 It blocks — one per blocked cmdlet name
        It 'NhiExecution.psm1: no invocation of HardDeleteServicePrincipal' {
            $Script:ExecCommands.Contains('HardDeleteServicePrincipal') | Should -Be $false
        }

        It 'NhiExecution.psm1: no invocation of Remove-MgServicePrincipal' {
            $Script:ExecCommands.Contains('Remove-MgServicePrincipal') | Should -Be $false
        }

        It 'NhiExecution.psm1: no invocation of Remove-MgServicePrincipalByAppId' {
            $Script:ExecCommands.Contains('Remove-MgServicePrincipalByAppId') | Should -Be $false
        }

        It 'NhiExecution.psm1: no invocation of Remove-MgApplication' {
            $Script:ExecCommands.Contains('Remove-MgApplication') | Should -Be $false
        }

        It 'NhiExecution.psm1: no invocation of Remove-MgApplicationPassword' {
            $Script:ExecCommands.Contains('Remove-MgApplicationPassword') | Should -Be $false
        }

        It 'NhiExecution.psm1: no invocation of Remove-MgApplicationKey' {
            $Script:ExecCommands.Contains('Remove-MgApplicationKey') | Should -Be $false
        }

        It 'NhiExecution.psm1: no invocation of Remove-MgServicePrincipalPassword' {
            $Script:ExecCommands.Contains('Remove-MgServicePrincipalPassword') | Should -Be $false
        }

        It 'NhiExecution.psm1: no invocation of Remove-MgServicePrincipalKey' {
            $Script:ExecCommands.Contains('Remove-MgServicePrincipalKey') | Should -Be $false
        }

        It 'NhiExecution.psm1: no invocation of Remove-MgServicePrincipalAppRoleAssignment' {
            $Script:ExecCommands.Contains('Remove-MgServicePrincipalAppRoleAssignment') | Should -Be $false
        }

        It 'NhiExecution.psm1: no invocation of Remove-MgOauth2PermissionGrant' {
            $Script:ExecCommands.Contains('Remove-MgOauth2PermissionGrant') | Should -Be $false
        }

        It 'NhiExecution.psm1: no invocation of Remove-MgServicePrincipalOwnerByRef' {
            $Script:ExecCommands.Contains('Remove-MgServicePrincipalOwnerByRef') | Should -Be $false
        }

        It 'NhiExecution.psm1: no invocation of Remove-MgServicePrincipalOwnerDirectoryObjectByRef' {
            $Script:ExecCommands.Contains('Remove-MgServicePrincipalOwnerDirectoryObjectByRef') | Should -Be $false
        }

        It 'NhiExecution.psm1: ParseFile returns zero errors' {
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile(
                $Script:ExecModulePath, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }

    Context 'Scanner correctness — Update-MgServicePrincipal is ALLOWED' {
        It 'Update-MgServicePrincipal appears as command in NhiExecution.psm1 (expected)' {
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $Script:ExecModulePath, [ref]$null, [ref]$errors)
            $cmdNames = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase)
            $cmdAsts = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst]
            }, $true)
            foreach ($cmd in $cmdAsts) {
                $name = $cmd.GetCommandName()
                if ($name) { $null = $cmdNames.Add($name) }
            }
            $cmdNames.Contains('Update-MgServicePrincipal') | Should -Be $true
        }
    }
}