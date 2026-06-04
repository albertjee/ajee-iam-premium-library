#Requires -Version 5.1
#Requires -Modules Pester

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltinCmdlets', '')]
param()

BeforeAll {
	$toolRoot = Split-Path -Parent $PSScriptRoot
	$modulePath = Join-Path -Path $toolRoot -ChildPath 'src\Modules\HtmlEncoding.psm1'
	Import-Module $modulePath -Force
}

Describe 'HtmlEncoding.Rev36 — HTML Encoding and XSS Prevention' {

	Context 'ConvertTo-DecomHtmlEncoded basic encoding' {
		It 'Encodes angle brackets' {
			$result = ConvertTo-DecomHtmlEncoded -InputString '<script>alert("test")</script>'
			$result | Should -Be '&lt;script&gt;alert(&quot;test&quot;)&lt;/script&gt;'
		}

		It 'Encodes ampersand' {
			$result = ConvertTo-DecomHtmlEncoded -InputString 'Tom & Jerry'
			$result | Should -Be 'Tom &amp; Jerry'
		}

		It 'Encodes double quotes by default' {
			$result = ConvertTo-DecomHtmlEncoded -InputString 'He said "hello"'
			$result | Should -Be 'He said &quot;hello&quot;'
		}

		It 'Does not encode single quotes by default' {
			$result = ConvertTo-DecomHtmlEncoded -InputString "It's fine"
			$result | Should -Be "It's fine"
		}

		It 'Encodes single quotes with -EncodeQuotes flag' {
			$result = ConvertTo-DecomHtmlEncoded -InputString "It's fine" -EncodeQuotes
			$result | Should -Be "It&#39;s fine"
		}

		It 'Handles empty string via pipeline' {
			$result = '' | ConvertTo-DecomHtmlEncoded
			$result | Should -Be ''
		}

		It 'Handles null input via pipeline' {
			$result = $null | ConvertTo-DecomHtmlEncoded
			$result | Should -BeNullOrEmpty
		}
	}

	Context 'ConvertTo-DecomHtmlText content encoding' {
		It 'Encodes angle brackets in text' {
			$result = ConvertTo-DecomHtmlText -InputString 'Value: <critical>'
			$result | Should -Be 'Value: &lt;critical&gt;'
		}

		It 'Encodes ampersands in text' {
			$result = ConvertTo-DecomHtmlText -InputString 'Coffee & Tea'
			$result | Should -Be 'Coffee &amp; Tea'
		}

		It 'Preserves quotes in text content' {
			$result = ConvertTo-DecomHtmlText -InputString 'He said "yes" and I said "no"'
			$result | Should -Be 'He said "yes" and I said "no"'
		}

		It 'Handles mixed special characters' {
			$result = ConvertTo-DecomHtmlText -InputString 'A & B < C > D'
			$result | Should -Be 'A &amp; B &lt; C &gt; D'
		}
	}

	Context 'ConvertTo-DecomHtmlAttribute attribute encoding' {
		It 'Encodes all special characters for attributes' {
			$result = ConvertTo-DecomHtmlAttribute -InputString 'value="test" onload="bad"'
			$result | Should -Be 'value=&quot;test&quot; onload=&quot;bad&quot;'
		}

		It 'Encodes single quotes for attributes' {
			$result = ConvertTo-DecomHtmlAttribute -InputString "user's profile"
			$result | Should -Be "user&#39;s profile"
		}

		It 'Encodes ampersands in attribute values' {
			$result = ConvertTo-DecomHtmlAttribute -InputString 'param=a&b=c'
			$result | Should -Be 'param=a&amp;b=c'
		}

		It 'Encodes angle brackets in attribute values' {
			$result = ConvertTo-DecomHtmlAttribute -InputString '<tag attr="value">'
			$result | Should -Be '&lt;tag attr=&quot;value&quot;&gt;'
		}
	}

	Context 'ConvertTo-DecomHtmlCdata CDATA escaping' {
		It 'Escapes CDATA closing sequence' {
			$result = ConvertTo-DecomHtmlCdata -InputString 'content with ]]> in it'
			$result | Should -Be 'content with ]]&gt; in it'
		}

		It 'Preserves other characters in CDATA' {
			$result = ConvertTo-DecomHtmlCdata -InputString 'var x = 5; if (x > 3) { }'
			$result | Should -Be 'var x = 5; if (x > 3) { }'
		}

		It 'Handles multiple CDATA sequences' {
			$result = ConvertTo-DecomHtmlCdata -InputString 'first ]]> second ]]> third'
			$result | Should -Be 'first ]]&gt; second ]]&gt; third'
		}
	}

	Context 'Pipeline input support' {
		It 'ConvertTo-DecomHtmlEncoded accepts pipeline input' {
			'<test>' | ConvertTo-DecomHtmlEncoded | Should -Be '&lt;test&gt;'
		}

		It 'ConvertTo-DecomHtmlText accepts pipeline input' {
			'<value>' | ConvertTo-DecomHtmlText | Should -Be '&lt;value&gt;'
		}

		It 'ConvertTo-DecomHtmlAttribute accepts pipeline input' {
			"user's name" | ConvertTo-DecomHtmlAttribute | Should -Be "user&#39;s name"
		}

		It 'ConvertTo-DecomHtmlCdata accepts pipeline input' {
			'code ]]> end' | ConvertTo-DecomHtmlCdata | Should -Be 'code ]]&gt; end'
		}
	}

	Context 'XSS vulnerability detection' {
		It 'Test-DecomHtmlEncoding detects script tags' {
			$result = Test-DecomHtmlEncoding -Content '<script>alert("xss")</script>'
			$result.IsClean | Should -Be $false
			$result.RiskLevel | Should -Be 'Critical'
		}

		It 'Test-DecomHtmlEncoding detects JavaScript protocol' {
			$result = Test-DecomHtmlEncoding -Content 'href="javascript:void(0)"'
			$result.IsClean | Should -Be $false
			$result.RiskLevel | Should -Be 'Critical'
		}

		It 'Test-DecomHtmlEncoding detects event handlers' {
			$result = Test-DecomHtmlEncoding -Content '<img onerror="malicious()">'
			$result.IsClean | Should -Be $false
			$result.RiskLevel | Should -Be 'High'
		}

		It 'Test-DecomHtmlEncoding detects iframe tags' {
			$result = Test-DecomHtmlEncoding -Content '<iframe src="malicious.com"></iframe>'
			$result.IsClean | Should -Be $false
			$result.RiskLevel | Should -Be 'High'
		}

		It 'Test-DecomHtmlEncoding passes clean content' {
			$result = Test-DecomHtmlEncoding -Content 'This is &lt;safe&gt; content'
			$result.IsClean | Should -Be $true
			$result.RiskLevel | Should -Be 'None'
		}

		It 'Test-DecomHtmlEncoding counts multiple issues' {
			$result = Test-DecomHtmlEncoding -Content 'text <script></script> and onerror="x"'
			$result.IssueCount | Should -BeGreaterThan 0
		}
	}

	Context 'HtmlEncoding.psm1 module structure' {
		It 'HtmlEncoding module exports all required functions' {
			$module = Get-Module -Name 'HtmlEncoding' | Select-Object -First 1

			$expectedFunctions = @(
				'ConvertTo-DecomHtmlEncoded'
				'ConvertTo-DecomHtmlText'
				'ConvertTo-DecomHtmlAttribute'
				'ConvertTo-DecomHtmlCdata'
				'Test-DecomHtmlEncoding'
				'Test-DecomHtmlEncodingConsistency'
			)

			foreach ($func in $expectedFunctions) {
				$module.ExportedFunctions.Keys -contains $func | Should -Be $true
			}
		}

		It 'HtmlEncoding.psm1 imports without errors' {
			{
				Remove-Module 'HtmlEncoding' -Force -ErrorAction SilentlyContinue
				$testToolRoot = Split-Path -Parent $PSScriptRoot
				$testModulePath = Join-Path -Path $testToolRoot -ChildPath 'src\Modules\HtmlEncoding.psm1'
				Import-Module $testModulePath -Force
			} | Should -Not -Throw
		}
	}

	Context 'Real-world encoding scenarios' {
		It 'Encodes DisplayName with special characters' {
			$displayName = 'O''Reilly & Associates <Research>'
			$result = ConvertTo-DecomHtmlEncoded -InputString $displayName -EncodeQuotes
			$result | Should -Match '&lt;Research&gt;'
			$result | Should -Match '&amp;'
		}

		It 'Encodes Evidence field with code snippet' {
			$evidence = 'Found: <user role="Admin"> with permission X'
			$result = ConvertTo-DecomHtmlText -InputString $evidence
			$result | Should -Be 'Found: &lt;user role="Admin"&gt; with permission X'
		}

		It 'Encodes RecommendedAction with HTML entities' {
			$action = 'Remove user from "Domain Admins" group'
			$result = ConvertTo-DecomHtmlAttribute -InputString $action
			$result | Should -Match '&quot;'
		}

		It 'Handles error message with JSON content' {
			$error = '{"error": "<unknown>", "message": "failed & retried"}'
			$result = ConvertTo-DecomHtmlText -InputString $error
			$result | Should -Match '&lt;unknown&gt;'
			$result | Should -Match '&amp;'
		}
	}

}
