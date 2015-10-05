Import-Module "$env:APPVEYOR_BUILD_FOLDER\psievm\.appveyor\modules\Set-BuildVersion.psm1";

$env:CI_BUILD_DATE = ((Get-Date).ToUniversalTime().ToString("MM-dd-yyyy"));
$env:CI_BUILD_TIME = ((Get-Date).ToUniversalTime().ToString("hh:mm:ss"));

Set-BuildVersion;