#Requires -Version 5.1

# TestVersionContext — centralized version expectations for test assertions
# Prevents test brittleness and maintenance churn when tool version bumps occur

function Get-DecomExpectedToolVersion {
    <#
    .SYNOPSIS
    Returns the current expected tool version for test assertions.
    .DESCRIPTION
    Use this helper instead of hardcoding version strings in tests.
    When the tool version is bumped, update this single function.
    .RETURNS
    String representing current expected ToolVersion (e.g., 'Rev3.6')
    #>
    return 'Rev3.6'
}

function Get-DecomExpectedSchemaVersion {
    <#
    .SYNOPSIS
    Returns the current expected schema version for test assertions.
    .DESCRIPTION
    Use this helper instead of hardcoding version strings in tests.
    When the schema version is bumped, update this single function.
    .RETURNS
    String representing current expected SchemaVersion (e.g., '3.6')
    #>
    return '3.6'
}

function Get-DecomExpectedMajorMinor {
    <#
    .SYNOPSIS
    Returns the major.minor version for compatibility checks.
    .DESCRIPTION
    Useful for checks that care about 3.6 but not Rev3.6 vs Tool version.
    .RETURNS
    String representing major.minor version (e.g., '3.6')
    #>
    return '3.6'
}
