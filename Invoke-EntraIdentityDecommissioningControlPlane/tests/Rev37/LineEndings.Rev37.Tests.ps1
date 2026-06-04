#Requires -Version 7.0

Describe 'M18b - CRLF Line Ending Validation' {
	Context 'Source files use CRLF line endings' {
		It 'Rev3.7 new/modified files use CRLF' {
			$sourceFiles = @()
			$violations = @()

			$filesToCheck = @(
				'tests/Rev37/*.ps1',
				'tests/Rev37/*.psm1',
				'src/Modules/Remediation.psm1'
			)

			foreach ($pattern in $filesToCheck) {
				$sourceFiles += @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue)
			}

			$sourceFiles | ForEach-Object {
				$filePath = $_.FullName
				try {
					$bytes = [System.IO.File]::ReadAllBytes($filePath)

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
						$violations += [pscustomobject]@{
							File           = $filePath
							Issue          = 'Invalid line endings (must be CRLF)'
							Positions      = ($badLineEndings[0..4] -join ', ') + $(if ($badLineEndings.Count -gt 5) { "... (+$($badLineEndings.Count - 5) more)" } else { '' })
						}
					}
				} catch {
					$violations += [pscustomobject]@{
						File           = $filePath
						Issue          = "Error reading file: $($_.Exception.Message)"
						Positions      = 'N/A'
					}
				}
			}

			if ($violations.Count -gt 0) {
				$violations | Format-Table -AutoSize
				throw "CRLF validation failed: $($violations.Count) file(s) with incorrect line endings"
			}

			$sourceFiles.Count | Should -BeGreaterThan 0 -Because 'source files should exist'
			$violations.Count | Should -Be 0 -Because 'all source files must use CRLF'
		}
	}
}
