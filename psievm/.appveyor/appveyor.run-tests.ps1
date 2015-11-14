if(-not (Get-Module -ListAvailable -Name "pester")) {
	choco install pester -y | Write-Host;
}

Import-Module "pester" -Verbose -Force;
#Import-Module "PSScriptAnalyzer" -Verbose -Force;

$cdir = $PWD;

if(-not $env:CI_BUILD_VERSION) {
	throw "Unable to find a value in CI_BUILD_VERSION";
}

$binDir = (Join-Path -Path "$env:APPVEYOR_BUILD_FOLDER" -ChildPath "psievm\bin\$env:CI_BUILD_VERSION\" -Resolve);
$workingDir = (Join-Path -Path "$env:APPVEYOR_BUILD_FOLDER" -ChildPath "psievm\psievm.tests\" -Resolve);
Set-Location -Path $workingDir | Out-Null;
$psModuleFiles = "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm\psievm.ps*1";
$psChocoFiles = "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm.package\tools\*.ps1";

Copy-Item -Path "$psModuleFiles" -Destination "$workingDir" -Force -Verbose;
Copy-Item -Path "$psChocoFiles" -Destination "$workingDir" -Force -Verbose;

$tests = (Get-ChildItem -Path "$workingDir\*.Tests.ps1" | % { $_.FullName });

New-Item -Path (Join-Path -Path $workingDir -ChildPath "results") -ItemType Directory -Force | Out-Null;
$resultsOutput = (Join-Path -Path $binDir -ChildPath "psievm-tests.results.xml");

$coverageFiles = (Get-ChildItem -Path "$workingDir\*.ps*1") | where { $_.Name -inotmatch "\.tests\.ps1$" -and $_.Name -inotmatch "\.psd1$" } | % { $_.FullName };

#Get-ChildItem -Path $workingDir | where { $_ -ilike "*.psm1" -or $_ -ilike "*.ps1" } | select -ExpandProperty FullName | foreach { 
#	Write-Host "Executing ScriptAnalyzer on $_";
#	Invoke-ScriptAnalyzer -Path $_ -Verbose;
#};

Invoke-Pester -Script $tests -OutputFormat NUnitXml -OutputFile $resultsOutput -EnableExit -CodeCoverage $coverageFiles -Strict;

if($env:APPVEYOR) {
	$wc = New-Object "System.Net.WebClient";
	$wc.UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", $resultsOutput);

	if($env:CODECOV_TOKEN -and $env:APPVEYOR_REPO_COMMIT) {
		$wcUploadFile("https://codecov.io/upload/v2?token=$($env:CODEVOC_TOKEN)&commit=$($env:APPVEYOR_REPO_COMMIT)&branch=$($env:APPVEYOR_REPO_BRANCH)&job=$($env:APPVEYOR_JOB_ID)", $resultsOutput);
	}
}

Set-Location -Path $cdir | Out-Null;
