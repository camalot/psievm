if(-not $env:ChocolateyInstall) {
	throw "Unable to use chocolatey install path";
}

$pesterBin = (Join-Path -Path $env:ChocolateyInstall -ChildPath "\lib\pester\tools\bin\pester.bat");

if(!(Test-Path -Path $pesterBin)) {
	choco install pester -y -force | Write-Host;

	if(!(Test-Path -Path $pesterBin)) {
		throw "Pester not installed."
	}
}
Import-Module "pester" -Verbose -Force;


$currentDirectory = $PWD;
$workingDir = (Join-Path -Path "$env:APPVEYOR_BUILD_FOLDER" -ChildPath "psievm\psievm.tests\");
"Moving to '$workingDir'" | Write-Host;
Set-Location -Path $workingDir | Out-Null;

Copy-Item -Path "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm\psievm.ps*1" -Destination "$PWD" -Force | Write-Host;

#(& cmd /c `"$pesterBin`" *>&1);
$tests = (Get-ChildItem -Path "$workingDir\*.Tests.ps1" | select -ExpandProperty name) -join $workingDir;
Invoke-Pester -Script $tests -CodeCoverage $tests;

"Moving back to '$currentDirectory'" | Write-Host;
Set-Location $currentDirectory | Out-Null;