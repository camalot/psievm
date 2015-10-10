Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\AppVeyor-Helper.psm1" -Verbose -Force;


if($env:PUSHBULLET_API_TOKEN -and $env:CI_DEPLOY_PUSHBULLET -eq $true) {
	$timestamp = (Get-Date).ToUniversalTime().ToString("MM/dd/yyyy hh:mm:ss");
	# this allows for multiple tokens, just separate with a comma.
	$env:PUSHBULLET_API_TOKEN.Split(",") | foreach {
		$pbtoken = $_;
		try {
			# Send a pushbullet message if there is an api token available
			Send-PushbulletMessage -apiKey $pbtoken -Type Message -Title "[Build] PSIEVM v$env:APPVEYOR_BUILD_VERSION Build Finished" -msg ("Build completed at $timestamp UTC");
		} catch [Exeption] {
			Write-Host -BackgroundColor Red -ForegroundColor White $_.ToString();
		}
	}
}


# NOT WORKING! It is closer than I was before, but still broken.
# PackageManagement\Get-PackageSource : Unable to find module providers (PSModule).
# I think I am missing something that is required to be loaded.
if( $env:POWERSHELLGALLERY_API_TOKEN -and $env:CI_DEPLOY_PSGALLERY -eq $true -and $env:PSGetZipUrl ) {
	try {
		$url = $env:PSGetZipUrl;
		$dest = "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\";
		$temp = "$env:APPVEYOR_BUILD_FOLDER\Temp";
		if(!(Test-Path -Path $temp)) {
			New-Item -Path $temp -Force -ItemType Directory | Out-Null;
		}
		$tempZip = Join-Path -Path $temp -ChildPath "PowerShellGet.zip";
		Invoke-DownloadFile -Url $url -File $tempZip;

		Expand-ZipArchive -File $tempZip -Destination $dest;

		# create junction
		$jsource = "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\ProviderAssemblies";

		if(!(Test-Path -Path "$env:LOCALAPPDATA\PackageManagement")) {
			New-Item -Path "$env:LOCALAPPDATA\PackageManagement" -ItemType Directory;
		}

		$NuGetBinaryLocalAppDataPath = "$env:LOCALAPPDATA\PackageManagement\ProviderAssemblies\";
		if(!(Test-Path -Path $NuGetBinaryLocalAppDataPath)) {
			cmd /c mklink /j "$NuGetBinaryLocalAppDataPath" "$jsource";
		}

		if(!(Test-Path -Path "$env:PROGRAMFILES\PackageManagement")) {
			New-Item -Path "$env:PROGRAMFILES\PackageManagement" -ItemType Directory;
		}

		$NuGetBinaryProgramDataPath = "$env:PROGRAMFILES\PackageManagement\ProviderAssemblies\";
		if(!(Test-Path -Path $NuGetBinaryProgramDataPath)) {
			cmd /c mklink /j "$NuGetBinaryProgramDataPath" "$jsource";
		}

		# we need to import the psievm module before it can be published.

		Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\bin\$($env:CI_BUILD_VERSION)\psievm\psievm.psd1" -Verbose -Force;

		Import-Module  "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\PackageManagement\1.0.0.0\PackageManagement.psd1" -Verbose -Force;
		Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\PowerShellGet\PowerShellGet.psd1" -Verbose -Force;

		if( (Get-Command -Name "Publish-Module" -ParameterName Name,NuGetApiKey,Path) ) {
			"Found the loaded PowerShellGet Module" | Write-Host;
			$artifact = "$env:APPVEYOR_BUILD_FOLDER\psievm\bin\$($env:CI_BUILD_VERSION)\psievm";
			Publish-Module -NuGetApiKey $env:POWERSHELLGALLERY_API_TOKEN -Path $artifact;

		}
	} catch [Exception] {
		throw;
	}
}
