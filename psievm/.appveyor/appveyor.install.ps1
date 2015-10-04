choco install powershell -pre -y;
Write-Host "Loading Choco Log";
(Get-Content -Path "C:\ProgramData\chocolatey\logs\chocolatey.log" -Raw) | Write-Host;
Get-PackageProvider -Name NuGet -ForceBootstrap;
# Install-Module -Name PSScriptAnalyzer -Force;
