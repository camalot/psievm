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


$currentDirectory = $PWD;

Set-Location -Path (Join-Path -Path "$env:APPVEYOR_BUILD_FOLDER" -ChildPath "psievm\psievm.tests\") | Out-Null;

Copy-Item -Path "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm\psievm.ps*1" -Destination "$PWD" -Force | Write-Host;

(& `"$pesterBin`" *>&1);

Set-Location $currentDirectory | Out-Null;