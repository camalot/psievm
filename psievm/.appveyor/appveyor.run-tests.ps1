
if(-not (Get-Module -ListAvailable -Name "pester")) {
	choco install pester -y | Write-Host;
}

Import-Module "pester" -Verbose -Force;
$workingDir = (Join-Path -Path "$env:APPVEYOR_BUILD_FOLDER" -ChildPath "psievm\psievm.tests\");

$psModuleFiles = "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm\psievm.ps*1";
$psChocoFiles = "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm.package\tools\*.ps1";
Copy-Item -Path "$psModuleFiles" -Destination "$workingDir" -Force -Verbose;
Copy-Item -Path "$psChocoFiles" -Destination "$workingDir" -Force -Verbose;
$tests = (Get-ChildItem -Path "$workingDir\*.Tests.ps1" | % { $_.FullName });
Invoke-Pester -Script $tests;

