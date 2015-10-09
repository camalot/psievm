

$params = ConvertFrom-StringData ($env:chocolateyPackageParameters -replace ';', "`n");
$ModulesRoot = $params.PSModuleDirectory;

if(-not $ModulesRoot) {
	$userDocsPath = [Environment]::GetFolderPath("MyDocuments");
	$ModulesRoot = (Join-Path $userDocsPath "\WindowsPowerShell\Modules\");
}

$PSIEVMModuleRootPath = (Join-Path $ModulesRoot "psievm");

if($env:chocolateyPackageFolder) {
	$ModuleTarget = (Join-Path $env:chocolateyPackageFolder "Modules");
	if(Test-Path($ModuleTarget)) {
		"Delete $ModuleTarget" | Write-Host;
		Remove-Item -Path $ModuleTarget -Recurse -Force | Out-Null;
	}
}

if(Test-Path($PSIEVMModuleRootPath)) {
	"Delete $PSIEVMModuleRootPath" | Write-Host;
	cmd /c rmdir "$PSIEVMModuleRootPath";
}



