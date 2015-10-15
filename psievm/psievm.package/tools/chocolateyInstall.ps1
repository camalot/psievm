#requires -version 3

$name   = 'psievm'


function Invoke-DownloadFile {
	Param (
		[string]$Url,
		[string]$File
	);
	process {
		"Downloading $Url to $File" | Write-Host;
		$downloader = new-object System.Net.WebClient;
		$downloader.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;
		$downloader.DownloadFile($Url, $File);
	}
}

function Install-PSIEVM {
	param (
		[Parameter(Mandatory=$true)]
		[string] $ModulesPath
	)
	begin {
		"Installing PSIEVM PowerShell module" | Write-Host;
		"Copyright (c) 2015 Ryan Conrad" | Write-Host;
		"License: https://github.com/camalot/psievm/blob/master/LICENSE.md" | Write-Host;
		$url = (Get-LatestGithubRelease -Owner camalot -Repo psievm);

		$tempDir = (Join-Path $env:TEMP "psievm");
		if(!(Test-Path -Path $tempDir)) {
			New-Item -Path $tempDir -ItemType Directory | Out-Null;
		}

		$file = (Join-Path $tempDir "psievm.zip");
		$psievmModulePath = (Join-Path $ModulesPath "psievm");

		if(!(Test-Path -Path $psievmModulePath)) {
			New-Item -Path $psievmModulePath -ItemType Directory | Out-Null;
		}
	}
	process {
		# download the package
		Invoke-DownloadFile -url $url -file $file;

		# download 7zip
		"Download 7Zip commandline tool" | Write-Host;
		$7zaExe = (Join-Path $tempDir '7za.exe');
		Invoke-DownloadFile -url 'https://raw.githubusercontent.com/camalot/psievm/master/psievm/.tools/7za.exe' -file "$7zaExe";

		# unzip the package
		"Extracting $file to $ModulesPath" | Write-Host;
		Start-Process "$7zaExe" -ArgumentList "x -o`"$ModulesPath`" -y `"$file`"" -Wait -NoNewWindow;
		"Unblock module files on the system" | Write-Host;
		Get-ChildItem -Path "$psievmModulePath" -File -Recurse | Unblock-File | Out-Null;
	}
	end {
		if(Test-Path -Path $tempDir) {
			"Clean up temp directory [$tempDir]" | Write-Host;
			Remove-Item -Path $tempDir -Force -Recurse | Out-Null;
		}
	}
}

function Get-LatestGithubRelease {
	<#
	.SYNOPSIS
	This gets the download URL for what ever is the latest release.
	#>
	Param(
		[string] $Owner,
		[string] $Repo
	);
	begin {
		$netAssembly = [Reflection.Assembly]::GetAssembly([System.Net.Configuration.SettingsSection])
		if($netAssembly) {
				$bindingFlags = [Reflection.BindingFlags] "Static,GetProperty,NonPublic";
				$settingsType = $netAssembly.GetType("System.Net.Configuration.SettingsSectionInternal");
				$instance = $settingsType.InvokeMember("Section", $bindingFlags, $null, $null, @());

				if($instance) {
						$bindingFlags = "NonPublic","Instance";
						$useUnsafeHeaderParsingField = $settingsType.GetField("useUnsafeHeaderParsing", $bindingFlags);
						if($useUnsafeHeaderParsingField) {
							$useUnsafeHeaderParsingField.SetValue($instance, $true);
						}
				}
		}
	}
	process {
		$webclient = New-Object net.webclient;
		"Getting latest release information from GitHub Repository $Owner/$Repo" | Write-Host;
		$webclient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.52 Safari/537.36");
		$webclient.Headers.Add("Accept","text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8");
		$latest = ($webclient.DownloadString("https://api.github.com/repos/$Owner/$Repo/releases") | ConvertFrom-Json) | select -First 1;
		"Using release '$($latest.name)'" | Write-Host;
		$url = $latest.assets | select -ExpandProperty browser_download_url -First 1;
		return $url;
	}
}


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
	& cmd /c ($CommandArgs -join " ") *>&1 | Write-Host;
}

function Invoke-Setup {

	$params = ConvertFrom-StringData ($env:chocolateyPackageParameters -replace ';', "`n");
	$ModulesRoot = $params.PSModuleDirectory;

	if(-not $ModulesRoot) {
		$ModulesRoot = Get-DocumentsModulePath;
	}

	if($env:chocolateyPackageFolder) {
		$ModuleTarget = (Join-Path $env:chocolateyPackageFolder "Modules");
		$PSIEVMModuleTarget = (Join-Path $ModuleTarget "psievm");
		$PSIEVMModuleRootPath = (Join-Path $ModulesRoot "psievm");

		Install-PSIEVM -ModulesPath $ModuleTarget;

		if(Test-Path($PSIEVMModuleRootPath)) {
			"Delete $PSIEVMModuleRootPath" | Write-Host;
			# cmd is used because Remove-Item wont delete a junction
			Remove-Item -Path $PSIEVMModuleRootPath -Recurse -Force;
			Invoke-ShellCommand -CommandArgs "rmdir", "/S", "/Q", "`"$PSIEVMModuleRootPath`"";
			#cmd /c rmdir "$PSIEVMModuleRootPath";
		}

		"Creating junction: $PSIEVMModuleRootPath -> $PSIEVMModuleTarget" | Write-Host;
		Invoke-ShellCommand -CommandArgs "mklink", "/j", "`"$PSIEVMModuleRootPath`"", "`"$PSIEVMModuleTarget`"";
		#cmd /c mklink /j "$PSIEVMModuleRootPath" "$PSIEVMModuleTarget";
	} else {
		Install-PSIEVM -ModulesPath $ModulesRoot;
	}
}

if( ($DoSetup -eq $null) -or ($DoSetup -eq $true) ) {
	Invoke-Setup;
}
