

$params = ConvertFrom-StringData ($env:chocolateyPackageParameters -replace ';', "`n");
$ModulesRoot = $params.PSModuleDirectory;

if(-not $ModulesRoot) {
	$docsPath = [Environment]::GetFolderPath("MyDocuments");
	if(-not $docsPath) {
		# if MyDocuments doesn't give anything, use the user profile
		$ModulesRoot = (Join-Path -Path $env:USERPROFILE -ChildPath "Documents\WindowsPowerShell\Modules\");
	} else {
		$ModulesRoot = (Join-Path -Path $docsPath -ChildPath "WindowsPowerShell\Modules\");
	}
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
	# cmd is used because Remove-Item wont delete a junction
	cmd /c rmdir "$PSIEVMModuleRootPath";
}



