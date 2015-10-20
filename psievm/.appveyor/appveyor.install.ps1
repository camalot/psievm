choco install powershell -y -version 4.0.20141001;

$oneget = (Join-Path -Path $env:APPVEYOR_BUILD_FOLDER -ChildPath "oneget");
if(!(Test-Path -Path $oneget)) {
	New-Item -Path $oneget -ItemType Directory | Out-Null;
}
$pmn = (Join-Path -Path $oneget -ChildPath "PackageManagement.0.1.0.29315.nupkg");
$webclient = (New-Object system.net.webclient);
$webclient.DownloadFile($env:PackageManagementPackageUrl, $pmn);

choco install PackageManagement -y -source $oneget

# if this fails, then the install above failed.

Get-PackageProvider -Name NuGet -ForceBootstrap;
Install-Module -Name PSScriptAnalyzer -Force;
