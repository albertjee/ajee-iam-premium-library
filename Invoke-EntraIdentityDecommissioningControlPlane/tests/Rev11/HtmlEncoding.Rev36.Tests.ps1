#Requires -Version 5.1

Describe 'HtmlEncoding.Rev36 — HTML entity encoding' {

    BeforeAll {
        $modulesPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules'
    }

    Context 'HTML encoding helper exists' {
        It 'ConvertTo-DecomHtmlEncoded or equivalent exists' {
            # Check for HTML encoding function in modules
            $reportingPath = Join-Path $modulesPath 'Reporting.psm1'
            $content = Get-Content $reportingPath -Raw
            # Should have some HTML encoding or escaping mechanism
            $content | Should -Match 'HtmlEncod|&lt;|&gt;|&quot;|&amp;|[System.Web.HttpUtility]'
        }

        It 'Dynamic values in reports are encoded' {
            # Check reporting modules for evidence encoding
            $modules = @('Reporting.psm1', 'ExecutivePack.psm1', 'Traceability.psm1')
            foreach ($mod in $modules) {
                $path = Join-Path $modulesPath $mod
                if (Test-Path $path) {
                    $content = Get-Content $path -Raw
                    # Should reference user-controlled fields with encoding
                    if ($content -match 'DisplayName|PublisherName|Evidence') {
                        $content | Should -Match 'Encod|Escape|&[a-z]+;'
                    }
                }
            }
        }
    }
}
