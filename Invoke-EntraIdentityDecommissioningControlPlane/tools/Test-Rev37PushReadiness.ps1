#Requires -Version 7.0

param(
    [switch]$RunPester
)

$ErrorActionPreference = 'Continue'
$exitCode = 0

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Rev3.7 Push Readiness Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "STEP 1: Git Status and Diff" -ForegroundColor Green
Write-Host "---" -ForegroundColor Green
git status --short
Write-Host ""
Write-Host "Changed files (HEAD vs origin/main):" -ForegroundColor Green
git diff HEAD origin/main --name-only
Write-Host ""

Write-Host "STEP 2: Unicode/Mojibake Scan (Rev3.7 files only)" -ForegroundColor Green
Write-Host "---" -ForegroundColor Green
$unicodeViolations = @()

$rev37FilesToScan = @(
    '.\tests\Rev37\*.ps1',
    '.\src\Modules\Remediation.psm1',
    '.\tools\Test-Rev37PushReadiness.ps1'
)

$sourceFiles = @()
foreach ($pattern in $rev37FilesToScan) {
    $sourceFiles += @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue)
}

$forbiddenCodepoints = @(
    0xFFFD,
    0x2010, 0x2011, 0x2012, 0x2013, 0x2014, 0x2015,
    0x2212,
    0x00A0,
    0x2018, 0x2019, 0x201C, 0x201D
)

$forbiddenMojibake = @(
    [byte[]]@(0xC3, 0xA2, 0xC2, 0x80, 0xC2, 0x94),
    [byte[]]@(0xC3, 0xA2, 0xC2, 0x80, 0xC2, 0x93)
)

foreach ($file in $sourceFiles) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $content = [System.IO.File]::ReadAllText($file.FullName)

    foreach ($codepoint in $forbiddenCodepoints) {
        if ($content.Contains([char]$codepoint)) {
            $unicodeViolations += [pscustomobject]@{
                File       = $file.FullName
                Issue      = "Unicode codepoint U+$('{0:X4}' -f $codepoint)"
            }
        }
    }

    foreach ($mojibake in $forbiddenMojibake) {
        $found = $false
        for ($i = 0; $i -le $bytes.Count - $mojibake.Count; $i++) {
            $match = $true
            for ($j = 0; $j -lt $mojibake.Count; $j++) {
                if ($bytes[$i + $j] -ne $mojibake[$j]) {
                    $match = $false
                    break
                }
            }
            if ($match) {
                $found = $true
                break
            }
        }
        if ($found) {
            $unicodeViolations += [pscustomobject]@{
                File       = $file.FullName
                Issue      = "Mojibake byte sequence detected"
            }
        }
    }
}

if ($unicodeViolations.Count -eq 0) {
    Write-Host "PASS: No Unicode/mojibake violations detected" -ForegroundColor Green
} else {
    Write-Host "FAIL: Unicode/mojibake violations detected" -ForegroundColor Red
    $unicodeViolations | Format-Table -AutoSize
    $exitCode = 1
}
Write-Host ""

Write-Host "STEP 3: CRLF Line Ending Validation (Rev3.7 files only)" -ForegroundColor Green
Write-Host "---" -ForegroundColor Green
$crlfViolations = @()

$rev37FilesToCheck = @(
    '.\tests\Rev37\*.ps1',
    '.\tests\Rev37\*.psm1',
    '.\src\Modules\Remediation.psm1'
)

$rev37Files = @()
foreach ($pattern in $rev37FilesToCheck) {
    $rev37Files += @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue)
}

foreach ($file in $rev37Files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $badLineEndings = @()

    for ($i = 0; $i -lt $bytes.Count; $i++) {
        if ($bytes[$i] -eq 0x0A) {
            if ($i -eq 0 -or $bytes[$i - 1] -ne 0x0D) {
                $badLineEndings += $i
            }
        } elseif ($bytes[$i] -eq 0x0D) {
            if ($i -eq $bytes.Count - 1 -or $bytes[$i + 1] -ne 0x0A) {
                $badLineEndings += $i
            }
        }
    }

    if ($badLineEndings.Count -gt 0) {
        $crlfViolations += [pscustomobject]@{
            File       = $file.FullName
            Issues     = $badLineEndings.Count
        }
    }
}

if ($crlfViolations.Count -eq 0) {
    Write-Host "PASS: All files use CRLF line endings" -ForegroundColor Green
} else {
    Write-Host "FAIL: Files with non-CRLF line endings detected" -ForegroundColor Red
    $crlfViolations | Format-Table -AutoSize
    $exitCode = 1
}
Write-Host ""

Write-Host "STEP 4: PowerShell AST Parse Check" -ForegroundColor Green
Write-Host "---" -ForegroundColor Green
$parseFailures = @()

foreach ($file in $sourceFiles) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $parseFailures += [pscustomobject]@{
            File  = $file.FullName
            Error = ($errors | ForEach-Object { $_.Message }) -join '; '
        }
    }
}

if ($parseFailures.Count -eq 0) {
    Write-Host "PASS: All files parse cleanly" -ForegroundColor Green
} else {
    Write-Host "FAIL: Parse errors detected" -ForegroundColor Red
    $parseFailures | Format-Table -AutoSize
    $exitCode = 1
}
Write-Host ""

Write-Host "STEP 5: Module Import Smoke Test" -ForegroundColor Green
Write-Host "---" -ForegroundColor Green
$importFailures = @()

$modules = @(
    '.\src\Modules\Remediation.psm1'
)

foreach ($module in $modules) {
    if (Test-Path $module) {
        try {
            $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($module)
            Remove-Module $moduleName -Force -ErrorAction SilentlyContinue
            Import-Module $module -Force -DisableNameChecking -WarningAction SilentlyContinue
            Write-Host "  OK: $moduleName" -ForegroundColor Green
        } catch {
            $importFailures += [pscustomobject]@{
                Module = $module
                Error  = $_.Exception.Message
            }
        }
    }
}

if ($importFailures.Count -eq 0) {
    Write-Host "PASS: All touched modules import successfully" -ForegroundColor Green
} else {
    Write-Host "FAIL: Module import errors detected" -ForegroundColor Red
    $importFailures | Format-Table -AutoSize
    $exitCode = 1
}
Write-Host ""

Write-Host "STEP 6: Pester Test Readiness" -ForegroundColor Green
Write-Host "---" -ForegroundColor Green
if ($RunPester) {
    Write-Host "Running Pester test suite..." -ForegroundColor Green
    $result = Invoke-Pester -Path .\tests\ -PassThru -ErrorAction Continue
    Write-Host "Tests Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "Tests Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -eq 0) { 'Green' } else { 'Red' })
    if ($result.FailedCount -gt 0) {
        $exitCode = 1
    }
} else {
    Write-Host "To run full Pester test suite, use: -RunPester" -ForegroundColor Cyan
    Write-Host "Command: .\tools\Test-Rev37PushReadiness.ps1 -RunPester" -ForegroundColor Cyan
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
if ($exitCode -eq 0) {
    Write-Host "RESULT: ALL CHECKS PASSED" -ForegroundColor Green
} else {
    Write-Host "RESULT: FAILURES DETECTED" -ForegroundColor Red
}
Write-Host "========================================" -ForegroundColor Cyan

exit $exitCode
