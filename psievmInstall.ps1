
function Download-File {
	Param (
		[string]$url,
		[string]$file
	);
	process {
		Write-Host "Downloading $url to $file"
		$downloader = new-object System.Net.WebClient;
		$downloader.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;
		$downloader.DownloadFile($url, $file);
	}
}

function Install-PSIEVM {
	begin {
		$url = (Get-LatestGithubRelease -Owner camalot -Repo psievm);
		if ($env:TEMP -eq $null) {
			$env:TEMP = (Join-Path $env:SystemDrive 'temp');
		}

		$tempDir = (Join-Path $env:TEMP "psievm");
		if(!(Test-Path -Path $tempDir)) {
			New-Item -Path $tempDir -ItemType Directory | Out-Null;
		}

		$file = (Join-Path $tempDir "psievm.zip");
		$userDocs = [Environment]::GetFolderPath("MyDocuments");
		$modulesPath = (Join-Path $userDocs "\WindowsPowerShell\Modules\");
		$psievmModulePath = (Join-Path $modulesPath "psievm");

		if(!(Test-Path -Path $psievmModulePath)) {
			New-Item -Path $psievmModulePath -ItemType Directory | Out-Null;
		}
	}
	process {
		# download the package
		Download-File -url $url -file $file;

		# download 7zip
		Write-Host "Download 7Zip commandline tool";
		$7zaExe = (Join-Path $tempDir '7za.exe');
		Download-File -url 'https://raw.githubusercontent.com/camalot/psievm/master/psievm/.tools/7za.exe' -file "$7zaExe";

		# unzip the package
		Write-Host "Extracting $file to $modulesPath";
		Start-Process "$7zaExe" -ArgumentList "x -o`"$modulesPath`" -y `"$file`"" -Wait -NoNewWindow;
	}
	end {
		if(Test-Path -Path $tempDir) {
			Write-Host "Clean up temp directory [$tempDir]";
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
		Write-Host "Getting latest release information from GitHub Repository $Owner/$Repo";
		$webclient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.52 Safari/537.36");
		$webclient.Headers.Add("Accept","text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8");
		$latest = ($webclient.DownloadString("https://api.github.com/repos/$Owner/$Repo/releases") | ConvertFrom-Json) | select -First 1;
		Write-Host "Using release '$($latest.name)'";
		$url = $latest.assets | select -ExpandProperty browser_download_url -First 1;
		return $url;
	}
}

Install-PSIEVM;