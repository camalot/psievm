
# I hate that these are duplicated in both the install and uninstall
# but because the install is also used to invoke a non-chocolatey install
# via the iex web download, it cannot import an external file easily.
# So they will remain duplicated for now.
function Get-DocumentsModulePath {
	$docsPath = (Get-EnvironmentFolderPath -Name MyDocuments);
	if(-not $docsPath) {
		# if MyDocuments doesn't give anything, use the user profile
		return (Join-Path -Path $env:USERPROFILE -ChildPath "Documents\WindowsPowerShell\Modules\");
	} else {
		return (Join-Path -Path $docsPath -ChildPath "WindowsPowerShell\Modules\");
	}
}

function Get-EnvironmentFolderPath {
	Param (
		[Parameter(Mandatory=$true)]
		[string] $Name
	);

	return [Environment]::GetFolderPath($Name);
}

function Invoke-ShellCommand {
	param (
		[string[]] $CommandArgs
	)
	& cmd /c ($CommandArgs -join " ") *>&1 | Write-Output;
}

function Invoke-Uninstall {

	$params = ConvertFrom-StringData ($env:chocolateyPackageParameters -replace ';', "`n");
	$ModulesRoot = $params.PSModuleDirectory;

	if(-not $ModulesRoot) {
		$ModulesRoot = Get-DocumentsModulePath;
	}

	$PSIEVMModuleRootPath = (Join-Path $ModulesRoot "psievm");

	if($env:chocolateyPackageFolder) {
		$ModuleTarget = (Join-Path $env:chocolateyPackageFolder "Modules");
		if(Test-Path($ModuleTarget)) {
			"Delete $ModuleTarget" | Write-Output;
			Remove-Item -Path $ModuleTarget -Recurse -Force | Out-Null;
		}
	}

	if(Test-Path($PSIEVMModuleRootPath)) {
		"Delete $PSIEVMModuleRootPath" | Write-Output;
		# cmd is used because Remove-Item wont delete a junction
		Invoke-ShellCommand -CommandArgs "rmdir", "/S", "/Q", "`"$PSIEVMModuleRootPath`"";
	}

}


if( ($DoUninstall -eq $null) -or ($DoUninstall -eq $true) ) {
	Invoke-Uninstall;
}

