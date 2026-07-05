#Requires -Modules Pester

# M8: closed-set safety test for the entry-point decomposition (Phases M2-M7).
# Mitigates the audit-surface trade-off signed off at Gate 1 of
# docs/entrypoint-decomposition-plan.md: before decomposition, safety properties
# (no mutation cmdlets, ordering, scope containment) were provable by scanning
# ONE file. After decomposition they span N files. This test makes the set of
# files that make up "the entry point" closed and machine-checked, so a future
# change cannot silently add an uninventoried companion or an extra dot-source
# line without failing CI.

BeforeAll {
    $script:Root           = Split-Path -Parent $PSScriptRoot
    $script:EntryPoint      = Join-Path $script:Root 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
    $script:EntryPointDir   = Join-Path $script:Root 'src\EntryPoint'
    $script:EntrySource     = Get-Content -LiteralPath $script:EntryPoint -Raw

    # The expected companion set, in dot-source order == original region order (D-I).
    # This list is the single source of truth for "what is the entry point" post-decomposition.
    $script:ExpectedCompanions = @(
        'ControlledNhiDecommission.ps1',
        'NhiExecutionFlow.ps1',
        'AssessmentFlow.ps1',
        'NhiGovernancePack.ps1',
        'HardeningOutputs.ps1',
        'Rev35GovernancePack.ps1'
    )

    # Extract every dot-source line of the form: . "$PSScriptRoot\src\EntryPoint\<File>.ps1" ...
    $script:DotSourceLines = @(
        [regex]::Matches($script:EntrySource, '(?m)^\.\s+"\$PSScriptRoot\\src\\EntryPoint\\([A-Za-z0-9_.]+\.ps1)"')
    )
    $script:DotSourcedFileNames = @($script:DotSourceLines | ForEach-Object { $_.Groups[1].Value })
}

Describe 'M8 EntryPointClosedSet — companion set is closed and machine-checked' {

    It 'main dot-sources exactly the 6 expected companions, in the expected order' {
        $script:DotSourcedFileNames.Count | Should -Be $script:ExpectedCompanions.Count
        for ($i = 0; $i -lt $script:ExpectedCompanions.Count; $i++) {
            $script:DotSourcedFileNames[$i] | Should -Be $script:ExpectedCompanions[$i] -Because "companion at position $i must match the region D-I order"
        }
    }

    It 'main contains no dot-source line outside src/EntryPoint/' {
        # Any ". <path>" line not matching the src\EntryPoint\ pattern would be an
        # uninventoried execution source and must not exist.
        $allDotSourceLines = @([regex]::Matches($script:EntrySource, '(?m)^\.\s+"[^"]+"'))
        $allDotSourceLines.Count | Should -Be $script:DotSourceLines.Count -Because 'every dot-source line in main must target src/EntryPoint/'
    }

    It 'src/EntryPoint/ contains exactly the 6 expected companion files and nothing else' {
        $actualFiles = @(Get-ChildItem -Path $script:EntryPointDir -File | Select-Object -ExpandProperty Name | Sort-Object)
        $expectedSorted = @($script:ExpectedCompanions | Sort-Object)
        $actualFiles.Count | Should -Be $expectedSorted.Count
        Compare-Object -ReferenceObject $expectedSorted -DifferenceObject $actualFiles | Should -BeNullOrEmpty -Because 'src/EntryPoint/ must contain no unlisted executable code'
    }

    It 'every expected companion file exists and parses without errors' {
        foreach ($companion in $script:ExpectedCompanions) {
            $path = Join-Path $script:EntryPointDir $companion
            $path | Should -Exist

            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0 -Because "$companion must parse cleanly"
        }
    }

    It 'main entry point parses without errors' {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($script:EntryPoint, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }
}
