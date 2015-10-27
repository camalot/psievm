choco install powershell -y -version 4.0.20141001;

$msiPath = "$($env:USERPROFILE)\PackageManagement_x64.msi";
Write-Host "Downloading PackageManagement_x64.msi -> $msiPath";
(New-Object Net.WebClient).DownloadFile('https://download.microsoft.com/download/4/1/A/41A369FA-AA36-4EE9-845B-20BCC1691FC5/PackageManagement_x64.msi', $msiPath);
Write-Host "Installing $msiPath";
(& cmd /c start /wait msiexec /i "$msiPath" /quiet *>&1) | Write-Host;
Write-Host "PackageManagement_x64.msi Installed";

## if this fails, then the install above failed.

Get-PackageProvider -Name NuGet -ForceBootstrap;
Install-Module -Name PSScriptAnalyzer -Force;
