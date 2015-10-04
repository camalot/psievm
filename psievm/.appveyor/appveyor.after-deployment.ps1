Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\Send-PushbulletMessage.psm1";

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
