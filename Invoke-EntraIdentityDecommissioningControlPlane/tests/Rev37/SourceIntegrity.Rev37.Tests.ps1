#Requires -Modules Pester

Describe 'SourceIntegrity.Rev37 - Unicode and Mojibake Detection' {

    Context 'CLASS 2 corruption detection' {

        It 'detects mojibake byte sequences' {
            $repoRoot = Join-Path $PSScriptRoot '../../'
            $sourceFiles = @(
                Get-ChildItem -Path $repoRoot -Filter '*.ps1' -Recurse
                Get-ChildItem -Path $repoRoot -Filter '*.psm1' -Recurse
                Get-ChildItem -Path $repoRoot -Filter '*.psd1' -Recurse
            ) | Where-Object { $_.FullName -notmatch '\\\.git\\' }

            $violations = @()

            # Specific mojibake byte sequences (CLASS 2: always forbidden)
            $mojibakePatterns = @(
                @([byte]0xC3, [byte]0xA2, [byte]0xC2, [byte]0x80, [byte]0xC2, [byte]0x94),  # em dash
                @([byte]0xC3, [byte]0xA2, [byte]0xC2, [byte]0x80, [byte]0xC2, [byte]0x93)   # en dash
            )

            foreach ($file in $sourceFiles) {
                try {
                    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)

                    foreach ($pattern in $mojibakePatterns) {
                        for ($i = 0; $i -le $bytes.Count - $pattern.Count; $i++) {
                            $match = $true
                            for ($j = 0; $j -lt $pattern.Count; $j++) {
                                if ($bytes[$i + $j] -ne $pattern[$j]) {
                                    $match = $false
                                    break
                                }
                            }

                            if ($match) {
                                $crlfCount = 0
                                for ($k = 0; $k -lt $i - 1; $k++) {
                                    if ($k -lt $bytes.Count - 1 -and $bytes[$k] -eq [byte]0x0D -and $bytes[$k + 1] -eq [byte]0x0A) {
                                        $crlfCount++
                                    }
                                }
                                $lineNum = $crlfCount + 1
                                $patternHex = $pattern | ForEach-Object { '0x{0:X2}' -f $_ } | Join-String -Separator ' '
                                $violations += "$($file.FullName):$lineNum - Mojibake: $patternHex"
                            }
                        }
                    }
                } catch {
                    Write-Warning "Could not scan file $($file.FullName): $_"
                }
            }

            if ($violations.Count -gt 0) {
                throw "CLASS 2 Mojibake corruption detected:`n$($violations -join "`n")"
            }
        }

        It 'detects U+FFFD replacement character in code (not comments)' {
            $repoRoot = Join-Path $PSScriptRoot '../../'
            $sourceFiles = @(
                Get-ChildItem -Path $repoRoot -Filter '*.ps1' -Recurse
                Get-ChildItem -Path $repoRoot -Filter '*.psm1' -Recurse
                Get-ChildItem -Path $repoRoot -Filter '*.psd1' -Recurse
            ) | Where-Object { $_.FullName -notmatch '\\\.git\\' }

            $violations = @()

            foreach ($file in $sourceFiles) {
                try {
                    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
                    $lines = $content -split "`r`n", [System.StringSplitOptions]::None

                    for ($lineNum = 0; $lineNum -lt $lines.Count; $lineNum++) {
                        $line = $lines[$lineNum]
                        if ([char]0xFFFD -in $line.ToCharArray()) {
                            $commentPos = $line.IndexOf('#')
                            if ($commentPos -eq -1 -or $line.Substring(0, $commentPos).Contains([char]0xFFFD)) {
                                $violations += "$($file.FullName):$($lineNum + 1) - U+FFFD replacement character"
                            }
                        }
                    }
                } catch {
                    Write-Warning "Could not scan file $($file.FullName): $_"
                }
            }

            if ($violations.Count -gt 0) {
                throw "CLASS 2 Replacement character detected:`n$($violations -join "`n")"
            }
        }

        It 'detects non-breaking space (U+00A0) in code' {
            $repoRoot = Join-Path $PSScriptRoot '../../'
            $sourceFiles = @(
                Get-ChildItem -Path $repoRoot -Filter '*.ps1' -Recurse
                Get-ChildItem -Path $repoRoot -Filter '*.psm1' -Recurse
                Get-ChildItem -Path $repoRoot -Filter '*.psd1' -Recurse
            ) | Where-Object { $_.FullName -notmatch '\\\.git\\' }

            $violations = @()

            foreach ($file in $sourceFiles) {
                try {
                    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
                    $lines = $content -split "`r`n", [System.StringSplitOptions]::None

                    for ($lineNum = 0; $lineNum -lt $lines.Count; $lineNum++) {
                        $line = $lines[$lineNum]
                        if ([char]0x00A0 -in $line.ToCharArray()) {
                            $commentPos = $line.IndexOf('#')
                            if ($commentPos -eq -1 -or $line.Substring(0, $commentPos).Contains([char]0x00A0)) {
                                $violations += "$($file.FullName):$($lineNum + 1) - U+00A0 non-breaking space"
                            }
                        }
                    }
                } catch {
                    Write-Warning "Could not scan file $($file.FullName): $_"
                }
            }

            if ($violations.Count -gt 0) {
                throw "CLASS 2 Non-breaking space detected:`n$($violations -join "`n")"
            }
        }

        It 'detects smart quotes inside string literals' {
            $repoRoot = Join-Path $PSScriptRoot '../../'
            $sourceFiles = @(
                Get-ChildItem -Path $repoRoot -Filter '*.ps1' -Recurse
                Get-ChildItem -Path $repoRoot -Filter '*.psm1' -Recurse
                Get-ChildItem -Path $repoRoot -Filter '*.psd1' -Recurse
            ) | Where-Object { $_.FullName -notmatch '\\\.git\\' }

            $violations = @()
            $smartQuotes = @([char]0x2018, [char]0x2019, [char]0x201C, [char]0x201D)

            foreach ($file in $sourceFiles) {
                try {
                    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
                    $lines = $content -split "`r`n", [System.StringSplitOptions]::None

                    for ($lineNum = 0; $lineNum -lt $lines.Count; $lineNum++) {
                        $line = $lines[$lineNum]
                        $chars = $line.ToCharArray()

                        # Simple heuristic: if line contains quotes and contains smart quotes
                        if (($line.Contains('"') -or $line.Contains("'")) -and $smartQuotes | Where-Object { $_ -in $chars }) {
                            $commentPos = $line.IndexOf('#')
                            $codeSection = if ($commentPos -gt 0) { $line.Substring(0, $commentPos) } else { $line }

                            foreach ($sq in $smartQuotes) {
                                if ($codeSection.Contains($sq)) {
                                    $violations += "$($file.FullName):$($lineNum + 1) - Smart quote U+$('{0:X4}' -f [int][char]$sq)"
                                    break
                                }
                            }
                        }
                    }
                } catch {
                    Write-Warning "Could not scan file $($file.FullName): $_"
                }
            }

            if ($violations.Count -gt 0) {
                throw "CLASS 2 Smart quotes in literals detected:`n$($violations -join "`n")"
            }
        }
    }
}
