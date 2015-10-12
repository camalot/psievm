param (
	[Parameter(Mandatory=$true)]
	[Version] $Version
);

if($PSCommandPath -eq $null) {
	Write-Host "Using MyInvoction.MyCommand.Path";
	$CommandRootPath = (Split-Path -Parent $MyInvocation.MyCommand.Path);
} else {
	Write-Host "Using PSCommandPath";
	$CommandRootPath = (Split-Path -Parent $PSCommandPath);
}


if(-not (Get-Module -ListAvailable -Name "pester")) {
	choco install pester -y | Write-Host;
}

Import-Module "pester" -Verbose -Force;
$cdir = $PWD;


$testsDir = (Join-Path -Path "$CommandRootPath" -ChildPath "..\psievm.tests\" -Resolve);
$psievmDir = (Join-Path -Path "$CommandRootPath" -ChildPath "..\psievm\" -Resolve);
$packageDir = (Join-Path -Path "$CommandRootPath" -ChildPath "..\psievm.package\" -Resolve);

$outDir = (Join-Path -Path "$CommandRootPath" -ChildPath "..\bin\$Version\" -Resolve);

Set-Location -Path $testsDir | Out-Null;

$psModuleFiles = "$psievmDir\psievm.ps*1";
$psChocoFiles = "$packageDir\**\*.ps1";

Copy-Item -Path "$psModuleFiles" -Destination "$testsDir" -Force -Verbose;
Copy-Item -Path "$psChocoFiles" -Destination "$testsDir" -Force -Verbose;

$tests = (Get-ChildItem -Path "$testsDir\*.Tests.ps1" | % { $_.FullName });

$resultsOutput = (Join-Path -Path $outDir -ChildPath "psievm-tests.results.xml");

Invoke-Pester -Script $tests -OutputFormat NUnitXml -OutputFile $resultsOutput -EnableExit;

Set-Location -Path $cdir | Out-Null;
