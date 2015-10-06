#choco install powershell4 -y;
#choco install powershell -pre -y;
#Write-Host "Loading Choco Log";
#(Get-Content -Path "C:\ProgramData\chocolatey\logs\chocolatey.log" -Raw) | Write-Host;

$ps5path = (Join-Path $env:APPVEYOR_BUILD_FOLDER "ps5");
if(!(Test-Path -Path $ps5path)) {
	New-Item -Path $ps5path -ItemType Directory | Out-Null;
}
$ps5msu = (Join-Path $ps5path "ps5-msu");
$webclient = (New-Object system.net.webclient);
Write-Host "Downloading PowerShell 5 installer.";
$webclient.DownloadFile("http://download.microsoft.com/download/3/F/D/3FD04B49-26F9-4D9A-8C34-4533B9D5B020/Win7AndW2K8R2-KB3066439-x64.msu", $ps5msu);

if(Test-Path -Path $ps5msu) {
	Write-Host "Installing PowerShell 5..."
	& wusa $ps5msu /quiet /norestart | Write-Host;
}

if ( (Get-Module -Name "PowerShellGet") -eq $null ) {
	Write-Error "Unable to locate PowerShellGet module";
	$Host.SetShouldExit(404);
}

Get-PackageProvider -Name NuGet -ForceBootstrap;
# Install-Module -Name PSScriptAnalyzer -Force;
