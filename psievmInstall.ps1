$version = "0.1.18.27815";

$url = "https://github.com/camalot/psievm/releases/download/psievm-v${version}/psievm.${version}.zip"
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

function Download-File {
  Param (
    [string]$url,
    [string]$file
  );
  Write-Host "Downloading $url to $file"
  $downloader = new-object System.Net.WebClient;
  $downloader.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;
  $downloader.DownloadFile($url, $file);
}

# download the package
Download-File -url $url -file $file;

# download 7zip
Write-Host "Download 7Zip commandline tool";
$7zaExe = (Join-Path $tempDir '7za.exe');
# yep, download the one that chocolatey uses :D
Download-File -url 'https://chocolatey.org/7za.exe' -file "$7zaExe";

# unzip the package
Write-Host "Extracting $file to $modulesPath...";
Start-Process "$7zaExe" -ArgumentList "x -o`"$modulesPath`" -y `"$file`"" -Wait -NoNewWindow | Write-Host;
