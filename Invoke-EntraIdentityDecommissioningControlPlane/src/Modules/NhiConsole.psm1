# Console output functions — self-contained (no Import-Module to avoid nesting cycle)
function Write-DecomInfo  { param([string]$Message) Write-Host "[INFO]  " -ForegroundColor DarkCyan -NoNewline; Write-Host $Message -ForegroundColor Gray }
function Write-DecomOk    { param([string]$Message) Write-Host "[OK]    " -ForegroundColor Green    -NoNewline; Write-Host $Message -ForegroundColor Gray }
function Write-DecomWarn  { param([string]$Message) Write-Host "[WARN]  " -ForegroundColor Yellow   -NoNewline; Write-Host $Message -ForegroundColor Gray }
function Write-DecomError { param([string]$Message) Write-Host "[ERROR] " -ForegroundColor Red      -NoNewline; Write-Host $Message -ForegroundColor Gray }

Export-ModuleMember -Function Write-DecomInfo,Write-DecomOk,Write-DecomWarn,Write-DecomError