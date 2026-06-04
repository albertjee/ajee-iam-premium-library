#Requires -Version 5.1
#Requires -Modules Pester

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltinCmdlets', '')]
param()

BeforeAll {
	$toolRoot = Split-Path -Parent $PSScriptRoot
	$modulePath = Join-Path -Path $toolRoot -ChildPath 'src\Modules\WarningHygiene.psm1'
	Import-Module $modulePath -Force
}

Describe 'WarningHygiene.Rev36 — Warning Capture and Validation' {

	Context 'Warning collection initialization' {
		It 'New-DecomWarningCollection creates empty collection' {
			$collection = New-DecomWarningCollection
			$collection.Warnings.Count | Should -Be 0
			$collection.FailureCount | Should -Be 0
			$collection.StageCounts.Count | Should -Be 0
		}

		It 'New-DecomWarningCollection returns hashtable with required keys' {
			$collection = New-DecomWarningCollection
			$collection.ContainsKey('Warnings') | Should -Be $true
			$collection.ContainsKey('StageCounts') | Should -Be $true
			$collection.ContainsKey('FailureCount') | Should -Be $true
		}
	}

	Context 'Warning addition and retrieval' {
		It 'Add-DecomWarning appends warning to collection' {
			$collection = New-DecomWarningCollection
			Add-DecomWarning -WarningCollection $collection `
				-Stage 'TestStage' `
				-Error 'Test error message'

			$collection.Warnings.Count | Should -Be 1
			$collection.FailureCount | Should -Be 1
		}

		It 'Add-DecomWarning records Stage and Error fields' {
			$collection = New-DecomWarningCollection
			Add-DecomWarning -WarningCollection $collection `
				-Stage 'Redaction' `
				-Error 'File not found'

			$collection.Warnings[0].Stage | Should -Be 'Redaction'
			$collection.Warnings[0].Error | Should -Be 'File not found'
		}

		It 'Add-DecomWarning increments stage counter' {
			$collection = New-DecomWarningCollection
			Add-DecomWarning -WarningCollection $collection -Stage 'OutputManifest' -Error 'Error 1'
			Add-DecomWarning -WarningCollection $collection -Stage 'OutputManifest' -Error 'Error 2'
			Add-DecomWarning -WarningCollection $collection -Stage 'Redaction' -Error 'Error 3'

			$collection.StageCounts['OutputManifest'] | Should -Be 2
			$collection.StageCounts['Redaction'] | Should -Be 1
		}

		It 'Get-DecomWarnings retrieves all warnings' {
			$collection = New-DecomWarningCollection
			Add-DecomWarning -WarningCollection $collection -Stage 'Stage1' -Error 'Error1'
			Add-DecomWarning -WarningCollection $collection -Stage 'Stage2' -Error 'Error2'

			$all = Get-DecomWarnings -WarningCollection $collection
			$all.Count | Should -Be 2
		}

		It 'Get-DecomWarnings filters by stage' {
			$collection = New-DecomWarningCollection
			Add-DecomWarning -WarningCollection $collection -Stage 'Redaction' -Error 'Error1'
			Add-DecomWarning -WarningCollection $collection -Stage 'OutputManifest' -Error 'Error2'
			Add-DecomWarning -WarningCollection $collection -Stage 'Redaction' -Error 'Error3'

			$redactionWarnings = Get-DecomWarnings -WarningCollection $collection -Stage 'Redaction'
			$redactionWarnings.Count | Should -Be 2
		}
	}

	Context 'Warning collection validation' {
		It 'Test-DecomWarningCollection returns true for empty collection' {
			$collection = New-DecomWarningCollection
			Test-DecomWarningCollection -WarningCollection $collection | Should -Be $true
		}

		It 'Test-DecomWarningCollection returns false when warnings exist' {
			$collection = New-DecomWarningCollection
			Add-DecomWarning -WarningCollection $collection -Stage 'Test' -Error 'Test error'
			Test-DecomWarningCollection -WarningCollection $collection | Should -Be $false
		}
	}

	Context 'Warning manifest serialization' {
		It 'ConvertTo-DecomWarningManifest creates manifest object' {
			$collection = New-DecomWarningCollection
			Add-DecomWarning -WarningCollection $collection -Stage 'Redaction' -Error 'File locked'

			$manifest = ConvertTo-DecomWarningManifest -WarningCollection $collection
			$manifest.FailureCount | Should -Be 1
			$manifest.StageCounts['Redaction'] | Should -Be 1
		}

		It 'ConvertTo-DecomWarningManifest uses custom section name' {
			$collection = New-DecomWarningCollection
			Add-DecomWarning -WarningCollection $collection -Stage 'Test' -Error 'Error'

			$manifest = ConvertTo-DecomWarningManifest -WarningCollection $collection -SectionName 'CustomWarnings'
			$manifest.Section | Should -Be 'CustomWarnings'
		}

		It 'ConvertTo-DecomWarningManifest includes all warnings' {
			$collection = New-DecomWarningCollection
			Add-DecomWarning -WarningCollection $collection -Stage 'Stage1' -Error 'Error1'
			Add-DecomWarning -WarningCollection $collection -Stage 'Stage2' -Error 'Error2'

			$manifest = ConvertTo-DecomWarningManifest -WarningCollection $collection
			$manifest.Warnings.Count | Should -Be 2
		}

		It 'ConvertTo-DecomWarningManifest includes Timestamp' {
			$collection = New-DecomWarningCollection
			Add-DecomWarning -WarningCollection $collection -Stage 'Test' -Error 'Error'

			$manifest = ConvertTo-DecomWarningManifest -WarningCollection $collection
			$manifest.Warnings[0].Timestamp | Should -Not -BeNullOrEmpty
		}
	}

	Context 'Hardening operation wrapper' {
		It 'Invoke-DecomHardeningOperation succeeds on successful operation' {
			$collection = New-DecomWarningCollection
			$result = Invoke-DecomHardeningOperation `
				-Operation { return 'Success' } `
				-WarningCollection $collection `
				-OperationName 'TestOp'

			$result.Success | Should -Be $true
			$result.Result | Should -Be 'Success'
			$collection.FailureCount | Should -Be 0
		}

		It 'Invoke-DecomHardeningOperation captures failure without re-throwing' {
			$collection = New-DecomWarningCollection
			$result = Invoke-DecomHardeningOperation `
				-Operation { throw 'Intentional error' } `
				-WarningCollection $collection `
				-OperationName 'FailOp'

			$result.Success | Should -Be $false
			$result.Error | Should -Match 'Intentional error'
			$collection.FailureCount | Should -Be 1
		}

		It 'Invoke-DecomHardeningOperation records warning with correct stage' {
			$collection = New-DecomWarningCollection
			Invoke-DecomHardeningOperation `
				-Operation { throw 'Test failure' } `
				-WarningCollection $collection `
				-OperationName 'CustomStageName'

			$collection.Warnings[0].Stage | Should -Be 'CustomStageName'
		}

		It 'Invoke-DecomHardeningOperation accepts metadata' {
			$collection = New-DecomWarningCollection
			$metadata = @{ File = 'test.json'; Context = 'processing' }

			Invoke-DecomHardeningOperation `
				-Operation { throw 'Error' } `
				-WarningCollection $collection `
				-OperationName 'Op' `
				-Metadata $metadata

			$collection.Warnings[0].Metadata.File | Should -Be 'test.json'
		}
	}

	Context 'Silent catch block detection' {
		It 'Test-DecomSilentCatchBlocks detects silent catch blocks' {
			$tempModule = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.psm1'
			$content = @'
function Test-Function {
	try {
		Write-Host "Testing"
	}
	catch { }
}
'@
			Set-Content -Path $tempModule -Value $content -Encoding UTF8 -NoNewline

			try {
				$result = Test-DecomSilentCatchBlocks -ModulePath $tempModule
				$result.HasSilentCatches | Should -Be $true
				$result.SilentCatchCount | Should -Be 1
			}
			finally {
				Remove-Item $tempModule -Force -ErrorAction SilentlyContinue
			}
		}

		It 'Test-DecomSilentCatchBlocks returns false for non-silent catches' {
			$tempModule = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.psm1'
			$content = @'
function Test-Function {
	try {
		Write-Host "Testing"
	}
	catch {
		Write-DecomWarn "Error captured"
	}
}
'@
			Set-Content -Path $tempModule -Value $content -Encoding UTF8 -NoNewline

			try {
				$result = Test-DecomSilentCatchBlocks -ModulePath $tempModule
				$result.HasSilentCatches | Should -Be $false
			}
			finally {
				Remove-Item $tempModule -Force -ErrorAction SilentlyContinue
			}
		}

		It 'Test-DecomSilentCatchBlocks identifies nonexistent module' {
			$result = Test-DecomSilentCatchBlocks -ModulePath 'C:\Nonexistent\Module.psm1'
			$result.Exists | Should -Be $false
		}

		It 'Test-DecomSilentCatchBlocks parses multiple silent catches' {
			$tempModule = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.psm1'
			$content = @'
function Test-Function1 {
	try { Write-Host "Test" } catch { }
}

function Test-Function2 {
	try { Write-Host "Test" } catch { }
	try { Write-Host "Test2" } catch { }
}
'@
			Set-Content -Path $tempModule -Value $content -Encoding UTF8 -NoNewline

			try {
				$result = Test-DecomSilentCatchBlocks -ModulePath $tempModule
				$result.SilentCatchCount | Should -Be 3
			}
			finally {
				Remove-Item $tempModule -Force -ErrorAction SilentlyContinue
			}
		}
	}

	Context 'Warning hygiene validation across modules' {
		It 'Test-DecomWarningHygiene returns summary object' {
			$result = Test-DecomWarningHygiene
			$result.ModuleCount | Should -BeGreaterThan 0
			$result.ViolationCount | Should -Not -BeNull
			$result.Results | Should -Not -BeNull
		}

		It 'Test-DecomWarningHygiene can accept custom module paths' {
			$toolRoot = Split-Path -Parent $PSScriptRoot
			$modulePaths = @(Get-ChildItem "$toolRoot\src\Modules" -Filter '*.psm1' -ErrorAction SilentlyContinue | Select-Object -First 2 -ExpandProperty FullName)

			if ($modulePaths.Count -gt 0) {
				$result = Test-DecomWarningHygiene -ModulePaths $modulePaths
				$result.ModuleCount | Should -Be $modulePaths.Count
			}
		}

		It 'Test-DecomWarningHygiene HasViolations is boolean' {
			$result = Test-DecomWarningHygiene
			$result.HasViolations | Should -BeOfType [bool]
		}
	}

	Context 'WarningHygiene.psm1 module structure' {
		It 'WarningHygiene module exports all required functions' {
			$module = Get-Module -Name 'WarningHygiene' | Select-Object -First 1

			$expectedFunctions = @(
				'New-DecomWarningCollection'
				'Add-DecomWarning'
				'Get-DecomWarnings'
				'Test-DecomWarningCollection'
				'ConvertTo-DecomWarningManifest'
				'Invoke-DecomHardeningOperation'
				'Test-DecomSilentCatchBlocks'
				'Test-DecomWarningHygiene'
			)

			foreach ($func in $expectedFunctions) {
				$module.ExportedFunctions.Keys -contains $func | Should -Be $true
			}
		}

		It 'WarningHygiene.psm1 imports without errors' {
			{
				Remove-Module 'WarningHygiene' -Force -ErrorAction SilentlyContinue
				$testToolRoot = Split-Path -Parent $PSScriptRoot
				$testModulePath = Join-Path -Path $testToolRoot -ChildPath 'src\Modules\WarningHygiene.psm1'
				Import-Module $testModulePath -Force
			} | Should -Not -Throw
		}
	}

}
