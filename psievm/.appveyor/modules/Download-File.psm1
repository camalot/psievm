function Download-File {
	Param (
		[string]$url,
		[string]$file
	);
	process {
		"Downloading $url to $file" | Write-Host;
		$downloader = new-object System.Net.WebClient;
		$downloader.DownloadFile($url, $file);
	}
}

Export-ModuleMember -Function Download-File;

function Extract-ZipArchive {
	Param (
		[string] $File,
		[string] $Destination
	);
	# download 7zip
	$7zaExe = "$env:APPVEYOR_BUILD_FOLDER\psievm\.tools\7za.exe";
	if(!(Test-Path -Path $7zaExe)) {
		throw "7za.exe not found";
	}

	# unzip the package
	"Extracting $file to $ModulesPath" | Write-Host;
	Start-Process "$7zaExe" -ArgumentList "x -o`"$Destination`" -y `"$File`"" -Wait -NoNewWindow;
}

Export-ModuleMember -Function Extract-ZipArchive;
