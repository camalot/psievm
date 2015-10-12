
if(-not (Get-Module -ListAvailable -Name "pester")) {
	choco install pester -y | Write-Host;
}

Import-Module "pester" -Verbose -Force;
$cdir = $PWD;
$workingDir = (Join-Path -Path "$env:APPVEYOR_BUILD_FOLDER" -ChildPath "psievm\psievm.tests\" -Resolve);
Set-Location -Path $workingDir | Out-Null;
$psModuleFiles = "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm\psievm.ps*1";
$psChocoFiles = "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm.package\tools\*.ps1";
Copy-Item -Path "$psModuleFiles" -Destination "$workingDir" -Force -Verbose;
Copy-Item -Path "$psChocoFiles" -Destination "$workingDir" -Force -Verbose;
$tests = (Get-ChildItem -Path "$workingDir\*.Tests.ps1" | % { $_.FullName });

New-Item -Path (Join-Path -Path $workingDir -ChildPath "results") -ItemType Directory -Force | Out-Null;
$resultsOutput = (Join-Path -Path $workingDir -ChildPath "results\nunit-results.xml");


Invoke-Pester -Script $tests -OutputFormat NUnitXml -OutputFile $resultsOutput -EnableExit;

$wc = New-Object "System.Net.WebClient";
$wc.UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", $resultsOutput);

Set-Location -Path $cdir | Out-Null;
