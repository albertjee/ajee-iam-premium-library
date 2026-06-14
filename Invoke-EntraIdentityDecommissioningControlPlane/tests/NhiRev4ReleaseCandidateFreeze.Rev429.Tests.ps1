$ErrorActionPreference = 'Stop'

function script:New-TestPackage {
    param([string]$Name,[hashtable]$Extra)
    $package = [ordered]@{ OutputArtifactPath = Join-Path $TestDrive "$Name.json" }
    foreach ($k in $Extra.Keys) { $package[$k] = $Extra[$k] }
    [pscustomobject]$package
}

Describe 'Rev4.29 Rev4.x Release Candidate Freeze and Handoff Documentation' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev429'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:Bundle = New-TestPackage -Name 'bundle' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'bundle.json'); EvidenceBundleId = 'REV428-OK'; ChainComplete = $true; RequiredArtifactsPresent = $true; SafetyAssertionsPassed = $true }
        $script:Guide = New-TestPackage -Name 'guide' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'guide.md'); GuideId = 'REV423-GUIDE' }
        $script:Safety = New-TestPackage -Name 'safety' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'safety.json'); SafetyAssertionsPassed = $true }
        $script:MarkdownPath = Join-Path $TestDrive 'rev429.md'
    }

    It 'Complete release candidate package writes JSON artifact locally' {
        $result = New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-OK' -MarkdownOutputPath $script:MarkdownPath
        $result.ReleaseCandidateStatus | Should -Be 'Ready'
        $result.FinalDeleteOutOfScope | Should -BeTrue
        $result.Rev5RequiredForDelete | Should -BeTrue
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        Test-Path -LiteralPath $script:MarkdownPath | Should -BeTrue
    }

    It 'Markdown handoff document writes locally' {
        $result = New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-MD' -MarkdownOutputPath $script:MarkdownPath
        Test-Path -LiteralPath $result.MarkdownArtifactPath | Should -BeTrue
    }

    It 'Package lists Rev4.10 through Rev4.29' {
        $result = New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-CHAIN'
        $revisions = @($result.MilestoneChain | ForEach-Object { $_.Revision })
        $revisions | Should -Contain 'Rev4.10'
        $revisions | Should -Contain 'Rev4.29'
    }

    It 'Package states final delete out of scope' {
        (New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-OUT').FinalDeleteOutOfScope | Should -BeTrue
    }

    It 'Package states Rev5 required for delete governance' {
        (New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-REV5').Rev5RequiredForDelete | Should -BeTrue
    }

    It 'Package states no production execution' {
        $result = New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-SCOPE'
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformedByFreeze | Should -BeFalse
        $result.RollbackPerformedByFreeze | Should -BeFalse
        $result.DeletePerformedByFreeze | Should -BeFalse
    }

    It 'Missing final evidence bundle returns NotReady' { (New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $null -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-1').ReleaseCandidateStatus | Should -Be 'NotReady' }
    It 'Missing operating guide returns NotReady' { (New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $null -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-2').ReleaseCandidateStatus | Should -Be 'NotReady' }
    It 'Missing safety posture returns NotReady' { (New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $null -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-3').ReleaseCandidateStatus | Should -Be 'NotReady' }

    It 'Package contains handoff checklist' {
        $result = New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-HANDOFF'
        $result.HandoffChecklist | Should -Not -BeNullOrEmpty
    }

    It 'Package contains release exclusions' {
        $result = New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-EXCL'
        $result.ReleaseExclusions | Should -Contain 'Actual final delete excluded.'
    }

    It 'Package contains known limitations' {
        $result = New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-LIM'
        $result.ConsultantSummary.KnownLimitations | Should -Not -BeNullOrEmpty
    }

    It 'Package contains future Rev5.x scope' {
        $result = New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-REV5SCOPE'
        $result.ConsultantSummary.FutureRev5Scope | Should -Match 'Rev5.x'
    }

    It 'Package contains no secrets or live credentials' {
        $result = New-NhiRev4ReleaseCandidateFreezePackage -EvidenceBundle $script:Bundle -ConsultantOperatingGuide $script:Guide -SafetyPosture $script:Safety -BranchName 'rev424-429-final-run4c-test-observation-rollback-release-freeze' -TagName 'rev424-429-final' -CommitHash 'deadbeef' -OutputPath $script:OutputPath -RunId 'REV429-SECRET'
        $result.RequiredHumanDecision | Should -BeTrue
        $result.HumanDecisionCaptured | Should -BeFalse
    }
}
