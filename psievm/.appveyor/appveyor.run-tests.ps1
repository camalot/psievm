
$env:PesterBin = (Join-Path -Path $env:ChoclateyInstall -ChildPath "\lib\pester\tools\bin\pester.bat");

if(!(Test-Path -Path $env:PesterBin)) {
	choco install pester -y -force | Write-Host;
}


$currentDirectory = $PWD;

Set-Location -Path "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm.tests" | Out-Null;

Copy-Item -Path "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm\psievm.ps*1" -Destination "$PWD" -Force | Write-Host;

(& `"$env:PesterBin`" *>&1);

Set-Location $currentDirectory | Out-Null;