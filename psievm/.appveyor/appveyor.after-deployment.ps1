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

		Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\PackageManagement\1.0.0.0\PackageManagement.psd1" -Verbose -Force;
		Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\PowerShellGet\PowerShellGet.psd1" -Verbose -Force;

		if( (Get-Command -Name "Publish-Module" -ParameterName Name,NuGetApiKey,Path).Source -eq "PowerShellGet" ) {
			"Found the loaded PowerShellGet Module" | Write-Host;
			$artifact = "$env:APPVEYOR_BUILD_FOLDER\bin\$($env:CI_BUILD_VERSION)\";
			Publish-Module -Name "psievm" -Path $artifact -NuGetApiKey $env:POWERSHELLGALLERY_API_TOKEN;

		}
	} catch [Exception] {
		throw;
	}
}
