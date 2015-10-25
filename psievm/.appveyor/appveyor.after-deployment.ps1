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

if($env:CI_DEPLOY_FTP -eq $true) {
	$files = Get-ChildItem -Path "$env:APPVEYOR_BUILD_FOLDER\psievm\bin\$($env:CI_BUILD_VERSION)" | where { $_ -imatch "^.*\.(zip|nupkg)$"; } | select -ExpandProperty FullName;
	$uploadPath = "$env:FTP_PATH$($env:CI_BUILD_VERSION)/";
	Invoke-FtpUpload -Server $env:FTP_SERVER -Path $uploadPath -Username $env:FTP_USER -Password $env:FTP_PASSWORD -Files $files;
}


if( $env:POWERSHELLGALLERY_API_TOKEN -and $env:CI_DEPLOY_PSGALLERY -eq $true ) {
	try {
		# we need to import the psievm module before it can be published.
		Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\bin\$($env:CI_BUILD_VERSION)\psievm\psievm.psd1" -Verbose -Force;

		Import-Module "PackageManagement" -Verbose -Force;
		Import-Module "PowerShellGet" -Verbose -Force;

		if( (Get-Command -Name "Publish-Module" -ParameterName Name,NuGetApiKey,Path) ) {
			"Found the loaded PowerShellGet Module" | Write-Host;
			$artifact = "$env:APPVEYOR_BUILD_FOLDER\psievm\bin\$($env:CI_BUILD_VERSION)\psievm";
			Publish-Module -NuGetApiKey $env:POWERSHELLGALLERY_API_TOKEN -Path $artifact;
		}
	} catch [Exception] {
		throw;
	}
}
