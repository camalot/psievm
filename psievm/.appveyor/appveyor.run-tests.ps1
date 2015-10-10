
if(-not (Get-Module -ListAvailable -Name "pester")) {
	choco install pester -y | Write-Host;
}
Import-Module "pester" -Verbose -Force;
$currentDirectory = $PWD;
$workingDir = (Join-Path -Path "$env:APPVEYOR_BUILD_FOLDER" -ChildPath "psievm\psievm.tests\");
"Moving to '$workingDir'" | Write-Host;
Set-Location -Path $workingDir | Out-Null;
$coverageFiles = "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm\psievm.ps*1";

Copy-Item -Path "$coverageFiles" -Destination "$PWD" -Force | Write-Host;
$tests = (Get-ChildItem -Path "$workingDir\*.Tests.ps1" | % { $_.FullName });
Invoke-Pester -Script $tests -CodeCoverage $coverageFiles;

"Moving back to '$currentDirectory'" | Write-Host;
Set-Location $currentDirectory | Out-Null;