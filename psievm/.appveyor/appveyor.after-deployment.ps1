Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\Send-PushbulletMessage.psm1";
Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\Download-File.psm1";

if($env:CI_DEPLOY_PSGALLERY -eq $true) {
	if( $env:PSModulePath -inotcontains "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm\" ) {
		$env:PSModulePath = "$env:APPVEYOR_BUILD_FOLDER\psievm\psievm\;$env:PSModulePath";
	}
	Publish-Module -NuGetApiKey $env:POWERSHELLGALLERY_API_TOKEN -Name $env:APPVEYOR_PROJECT_SLUG
}

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


if( $env:POWERSHELLGALLERY_API_TOKEN -and $env:CI_DEPLOY_PSGALLERY -eq $true -and $env:PSGetZipUrl ) {
	$url = $env:PSGetZipUrl;
	$dest = "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\";
	$temp = "$env:APPVEYOR_BUILD_FOLDER\Temp";
	if(!(Test-Path -Path $temp)) {
		New-Item -Path $temp -Force | Out-Null;
	}
	$tempZip = Join-Path -Path $temp -ChildPath "PowerShellGet.zip";
	Download-File -Url $url -File $tempZip;

	Extract-ZipArchive -File $tempZip -Destination $dest;

	Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\PackageManagement\1.0.0.0\PackageManagement.psd1";
	Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\PowerShellGet\PowerShellGet.psd1";

	if(Get-Command -Name "Publish-Module" -ParameterName Name,NuGetApiKey ) {
		"Found the loaded PowerShellGet Module" | Write-Host;
		$artifact = "$env:APPVEYOR_BUILD_FOLDER\bin\$($env:CI_BUILD_VERSION)\";
		Publish-Module -Name "psievm" -Path $artifact -NuGetApiKey $env:POWERSHELLGALLERY_API_TOKEN;

	}
}
