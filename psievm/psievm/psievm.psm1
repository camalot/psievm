<#
Copyright 2015 Ryan Conrad

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

-----
this is loosely based on https://github.com/xdissent/ievms/blob/master/ievms.sh

#>


$PSIEVM = "psievm";
#$PSIEVMManifest = iex (Get-Content -Path "$PSScriptRoot\psievm.psd1" -Raw);
#$PSIEVMVersion = $PSIEVMManifest.ModuleVersion;

#region Exported Functions

function Get-IEVM {
	<#

	.SYNOPSIS

	Gets an IE VM from modern.ie and imports it to the supported VM Host.


	.DESCRIPTION


	.PARAMETER OS

	The OS version. Supported values:

	- XP
	- Vista
	- 7
	- 8
	- 8.1
	- 10

	.PARAMETER IEVersion

	Based on the OS the following version are supported:

	- XP: 6, 7
	- Vista:  8
	- Win7: 8, 9, 10, 11
	- Win8: 10
	- Win8.1: 11
	- Win10: Edge

	.PARAMETER Shares

	A list of shares to mount in the VM (when supported by the host)

	.PARAMETER AlternateVMLocation

	Use an alternate location to find the VM image zips. The zips MUST follow the following name format:

	IE: IE<Version>.<OS>.For.Windows.<VMHost>.zip
	Edge: Microsoft%20Edge.<OS>.For.Windows.<VMHost>.zip

	.PARAMETER VMHost

	Defines the VM host to use. Supported VM hosts: VirtualBox, VMWare, VPC, HyperV, Vagrant

	.PARAMETER IgnoreInvalidMD5

	If $true, it will ignore the zip file MD5 hash check.

	.EXAMPLE

	Get the IE6 on Windows XP VM for VirtualBox

	Get-IEVM -OS XP -IEVersion 6 -VMHost VirtualBox


	.EXAMPLE

	Get the IE9 on Windows 7 VM for VirtualBox from your company network share

	Get-IEVM -OS Win7 -IEVersion 9 -VMHost VirtualBox -AlternateVMLocation "\\vmhost-machine\VirtualBox\"


	.NOTES

	Fork on Github: https://github.com/camalot/psievm

	#>
	[CmdletBinding()]
	Param (
		[ValidateSet("XP", "Vista", "7", "8", "8.1", "10", "WinXP","WinVista", "Win7", "Win8", "Win8.1",
			"Win10", "WindowsXP","WindowsVista", "Windows7", "Windows8", "Windows8.1", "Windows10",
			"Windows XP","Windows Vista", "Windows 7", "Windows 8", "Windows 8.1", "Windows 10")]
		[Parameter(Mandatory=$true, Position=0)]
		[string] $OS,
		[Parameter(Mandatory=$false, Position=2)]
		[string[]] $Shares,
		[Parameter(Mandatory=$false,Position=3)]
		[string] $AlternateVMLocation = "",
		[Parameter(Mandatory=$false, Position=4)]
		[ValidateSet("VirtualBox" <#, "VMWare", "VPC", "HyperV", "Vagrant"#>)]
		[string] $VMHost = "VirtualBox",
		[Parameter(Mandatory=$false, Position=5)]
		[switch] $IgnoreInvalidMD5,
		[Parameter(Mandatory=$false, Position=6)]
		[string] $VMRootPath = $pwd
	);

	DynamicParam {
		# Set the dynamic parameters' name
		$ievParam = "IEVersion";
		$ievAlias = "IE";

		# Create the dictionary
		$RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary;
		# Create the collection of attributes
		$AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute];
		# Create and set the parameters' attributes
		$ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute;
		$ParameterAttribute.Mandatory = $true;
		$ParameterAttribute.Position = 1;

		# Add the attributes to the attributes collection
		$AttributeCollection.Add($ParameterAttribute);
		$arrSet = @();
		# We need to set the version that each OS supports, plus, we need to make sure the OS is in the correct format.
		switch -Regex ($OS) {
			"^(win(dows)?)?\s?xp$" {
				$OS = "XP";
				$arrSet = @("6", "8");
				# this happens early... I don't think this will work
				# because VMHost is not yet set so it will go with all VMHosts.
				#if($VMHost -eq "VirtualBox" -or $VMHost -eq $null) {
				#	# we can upgrade xp to ie7
				#	$arrSet = @("6", "7", "8");
				#}
			}
			"^(win(dows)?)?\s?vista$" {
				$OS = "Vista";
				$arrSet = @("7");
				#if($VMHost -eq "VirtualBox" -or $VMHost -eq $null) {
				#	# we can upgrade xp to ie7
				#	$arrSet = @("7", "8", "9");
				#}
			}
			"^(win(dows)?)?\s?7$" {
				$OS = "7";
				$arrSet = @("8","9","10","11");
			}
			"^(win(dows)?)?\s?8$" {
				$OS = "8";
				$arrSet = @("10");
			}
			"^(win(dows)?)?\s?8.1$" {
				$OS = "8.1";
				$arrSet = @("11");
			}
			"^(win(dows)?)?\s?10$" {
				$OS = "10";
				$arrSet = @("Edge");
			}
		}
		$ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet);
		# Add the ValidateSet to the attributes collection
		$AttributeCollection.Add($ValidateSetAttribute);
		# Create the alias attribute
		$AliasAttribute = New-Object System.Management.Automation.AliasAttribute($ievAlias);
		$AttributeCollection.Add($AliasAttribute);
		# Create and return the dynamic parameter
		$RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ievParam, [string], $AttributeCollection);
		$RuntimeParameterDictionary.Add($ievParam, $RuntimeParameter);
		return $RuntimeParameterDictionary;
	}

	begin {
		$VMUser = "IEUser";
		$VMPassword = "Passw0rd!";
		$IEVersion = $PsBoundParameters[$ievParam];
		$IEUpgrade = $null;
		Write-Host "Initializing for VMHost '$VMHost'" -BackgroundColor Gray -ForegroundColor Black;

		$vmName = ("IE{0} - Win{1}" -f $IEVersion, $OS);
		$vmPath = (Join-Path -Path $VMRootPath -ChildPath $vmName);

		switch ($VMHost) {
			"HyperV" {
				$VMHost = "HyperV_2012";
				$vmext = "vhd";
				throw "Currently unsupported VMHost : $VMHost";
				return;
			}
			"VirtualBox" {
				$vmext = "ova";
				# support upgrading the OS to other versions using upgrade packages.
				switch -Regex ( "$OS$IEVersion" ) {
					"xp7" {
						$IEUpgrade = $IEVersion;
						$IEVersion = "6";
						Write-Host "Setting XP upgrade on boot from IE $IEVersion to IE $IEUpgrade" -BackgroundColor DarkYellow -ForegroundColor Black;
					}
					"vista(8|9)$" {
						$IEUpgrade = $IEVersion;
						$IEVersion = "7";
						Write-Host "Setting Vista upgrade on boot from IE $IEVersion to IE $IEUpgrade" -BackgroundColor DarkYellow -ForegroundColor Black;
					}
				}
			}
			"Vagrant" {
				$vmext = "box";
				throw "Currently unsupported VMHost : $VMHost";
				return;
			}
			"VMWare" {
				throw "Currently unsupported VMHost : $VMHost";
				return;
			}
			"VPC" {
				throw "Currently unsupported VMHost : $VMHost";
				return;
			}
			default {
				throw "Unknown VMHost : $VMHost";
				return;
			}
		}

		switch($OS) {
			"10" {
				$baseFile = "Microsoft%20{0}.{2}{1}.For.Windows.{3}.zip";
			}
			default {
				$baseFile = "IE{0}.{2}{1}.For.Windows.{3}.zip";
			}
		}
		$baseFile = ($baseFile -f $IEVersion, $OS,  @{$true="";$false="Win"}[$OS -imatch "^(xp|vista)$"], $VMHost);
		# No alternate VM Location is specified, download from ms
		if($AlternateVMLocation -eq "" -or $AlternateVMLocation -eq $null) {
			$buildNumber = "20141027";
			$baseURL = "https://az412801.vo.msecnd.net/vhd/VMBuild_{0}/{2}/IE{1}/Windows/{3}";
			switch -Regex ($IEVersion) {
				"^edge$" {
					$buildNumber = "20150801";
					$baseURL = "https://az792536.vo.msecnd.net/vms/VMBuild_{0}/{2}/MS{1}/Windows/{3}";
				}
			}
			$url = $baseURL -f $buildNumber, $IEVersion, $VMHost, $baseFile;
		} else {
			# use alternate path for the images (like a share)
			# combine the paths, validate and add missing slashes if needed
			$baseUrl = "{0}$AlternateVMLocation{2}{1}" -f (@{$true="";$false="\\"}[$AlternateVMLocation -imatch "^(\\\\|https?:\/\/|[a-z]:\\)"]), $baseFile,
				@{$true="";$false="/"}[$AlternateVMLocation -match "(\\|\/)$"];
			$url = $baseURL;
		}

		$baseVMName = ("IE$(@{$true="11";$false="$IEVersion"}[$IEVersion -ieq "edge"]) - Win$OS");
		$vmImportFile = (Join-Path -Path $vmPath -ChildPath "${baseVMName}.${vmext}" );
		$zip = (Join-Path -Path $vmPath -ChildPath "${vmName}.zip");
	}

	process {

		#Write-Host "$PSIEVM v$PSIEVMVersion" -ForegroundColor Yellow;

		# if the VM does not exist
		if( !(Test-VMHost -VMHost $VMHost -VMName $vmName) ) {

			# if the vmPath doesnt exist, create it.
			if(!(Test-Path -Path $vmPath)) {
				Write-Host ("Creating path `"$vmPath`"") -BackgroundColor Gray -ForegroundColor Black;
				New-Item -Path $vmPath -ItemType Directory | Out-Null;
			}

			if(!(Test-Path -Path $zip) -and !(Test-Path -Path $vmImportFile)) {
				Write-Host ("Transfer from: `"$url`" -> `"$zip`"") -BackgroundColor Gray -ForegroundColor Black;
				Start-BitsTransfer -Source $url -Destination $zip;
			}

			if((Test-Path -Path $zip) -and !(Test-Path -Path $vmImportFile)) {
				Write-Host ("Validating MD5 File Hash `"$zip`"") -BackgroundColor Gray -ForegroundColor Black;
				if(!(Test-MD5Hash -Path $zip -VMName $vmName -VMHost $VMHost)) {
					$shouldIgnoreMD5Validation = $PSBoundParameters.ContainsKey('IgnoreInvalidMD5')
					Write-Host "MD5 hash validation of zip '$zip' failed." -BackgroundColor @{$true="Yellow";$false="Red"}[$shouldIgnoreMD5Validation] -ForegroundColor @{$true="Black";$false="White"}[$shouldIgnoreMD5Validation];
					if(!$shouldIgnoreMD5Validation) {
						return;
					}
				}
				Write-Host ("Extracting `"$zip`" -> `"$vmPath`"") -BackgroundColor Gray -ForegroundColor Black;
				Expand-7ipArchive -Path $zip -DestinationPath (Split-Path $zip);
				Write-Host ("Deleting `"$zip`"") -BackgroundColor Gray -ForegroundColor Black;
				Remove-Item -Path $zip -Force | Out-Null;
			}

			if( !(Test-Path -Path $vmImportFile) ) {
				Write-Host "VM import file '$vmImportFile' not found." -BackgroundColor Red -ForegroundColor White;
				return;
			}
			# Add the VMRootPath to the shares.
			#$Shares.Add($VMRootPath) | Out-Null;
			$importSuccess = Import-VMImage -VMHost $VMHost -VMName $vmName -ImportFile $vmImportFile -IEVersion $IEVersion -OS $OS -Shares $Shares;
			if(!$importSuccess) {
				Write-Host "VM import failed." -BackgroundColor Red -ForegroundColor White;
				return;
			}
		}

		Start-VMHost -VMHost $VMHost -VMName $vmName -IEUpgrade $IEUpgrade -VMRootPath $VMRootPath;
	}
}

Set-Alias -Name psievm -Value Get-IEVM;

#endregion

function Import-VMImage {
	Param (
		[string] $IEVersion,
		[string] $OS,
		[string] $VMHost,
		[string] $VMName,
		[string] $ImportFile,
		[string[]] $Shares
	);

	switch($VMHost) {
		"VirtualBox" {
			return Import-VBoxImage -IEVersion $IEVersion -OS $OS -VMName $VMName -ImportFile $ImportFile -Shares $Shares;
		}
		default {
			return $false;
		}
	}
}

function Test-VMHost {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $VMHost,
		[Parameter(Mandatory=$true, Position=1)]
		[string] $VMName
	);
	switch($VMHost) {
		"VirtualBox" {
			return Test-VBoxVM -VMName $VMName;
		}
		default {
			return $false;
		}
	}
}

function Start-VMHost {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $VMHost,
		[Parameter(Mandatory=$true, Position=1)]
		[string] $VMName,
		[Parameter(Mandatory=$false, Position=2)]
		[string] $IEUpgrade,
		[Parameter(Mandatory=$false, Position=3)]
		[string] $VMRootPath
	);
	switch($VMHost) {
		"VirtualBox" {
			return Start-VBoxVM -VMName $VMName -IEUpgrade $IEUpgrade -VMRootPath $VMRootPath;
		}
		default {
			return $false;
		}
	};
}

#region VirtualBox
function Import-VBoxImage {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $IEVersion,
		[Parameter(Mandatory=$true, Position=1)]
		[string] $OS,
		[Parameter(Mandatory=$true, Position=2)]
		[string] $VMName,
		[Parameter(Mandatory=$true, Position=3)]
		[string] $ImportFile,
		[Parameter(Mandatory=$false, Position=4)]
		[string[]] $Shares = @()
	);
	try {
		$vbunit = "11";
		switch -Regex ($IEVersion) {
			"^edge$" {
				$vbunit = "8";
			}
			"^(6|7|8)$" {
				$vbunit = "10";
			}
		};

		$vbm = Get-VBoxManageExe;
		$vbox = (Join-Path -Path $vmPath -ChildPath "${vmName}.vbox");
		$disk = (Join-Path -Path $vmPath -ChildPath ("$VMName-disk1.vmdk"));
		Write-Host ("Importing $ImportFile to VM `"$VMName`"") -BackgroundColor Gray -ForegroundColor Black;

		(& $vbm import `"$ImportFile`" --vsys 0 --vmname `"$VMName`" --unit $vbunit --disk `"$disk`" 2>&1 | Out-String) | Out-Null;
		$Shares | where { $_ -ne "" -and $_ -ne $null; } | foreach {
			$shareName = (Split-Path -Path $_ -Leaf);
			Write-Host ("Adding share `"$shareName`" on VM `"$VMName`"") -BackgroundColor Gray -ForegroundColor Black;
			(& $vbm sharedfolder add `"$VMName`" --name `"$shareName`" --automount --hostpath `"$_`" 2>&1 | Out-String) | Out-Null;
		}

		#$dt = (Get-Date -Format 'MM-dd-yyyy hh:mm');
		#(& $vbm setextradata `"$VMName`" `"psievm`" `"{\`"created\`" : \`"$dt\`", \`"version\`" : \`"$PSIEVMVERSION`"}\`" 2>&1 | Out-String) | Out-Null;

		Write-Host ("Taking initial snapshot of `"$VMName`"") -BackgroundColor Gray -ForegroundColor Black;

		(& $vbm snapshot `"$VMName`" take clean --description `"The initial VM state.`" 2>&1 | Out-String) | Out-Null;

		return $true;
	} catch [System.Exception] {
		return $false;
	}
}

function Start-VBoxVM {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $VMName,
		[Parameter(Mandatory=$false, Position=1)]
		[string] $IEUpgrade,
		[Parameter(Mandatory=$false, Position=2)]
		[string] $VMRootPath
	);
	$vbm = Get-VBoxManageExe;
	Write-Host "Starting VM `"$VMName`"" -BackgroundColor Gray -ForegroundColor Black;
	& $vbm startvm `"$VMName`";


	#if($IEUpgrade -ne $null -and $IEUpgrade -ne "") {
	#	Invoke-VBoxUpgrade -OS $OS -IEUpgradeVersion $IEUpgrade -VMName $VMName -VMRootPath $VMRootPath;
	#}

}

function Test-VBoxVM {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $VMName
	);
	try {
		$vbm = Get-VBoxManageExe;
		Write-Host "Testing if VM `"$VMName`" already exists in VirtualBox" -BackgroundColor Gray -ForegroundColor Black;
		$r = & "$vbm" showvminfo `"$VMName`" 2>&1 | Out-String;
		$vmnEscaped = [Regex]::Escape($VMName);
		if($r -match "Could\snot\sfind\sa\sregistered\smachine\snamed\s'$vmnEscaped'") {
			Write-Host ("VM Image not found in VirtualBox.") -BackgroundColor Gray -ForegroundColor Black;
			# vm does not exist.
			return $false;
		}
		Write-Host ("VM Image found in VirtualBox.") -BackgroundColor Gray -ForegroundColor Black;
		return $true;
	} catch {
		return $false;
	}
}

function Invoke-RemoteVBoxCommand {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $VMName,
		[Parameter(Mandatory=$true, Position=1)]
		[string] $Command,
		[Parameter(Mandatory=$false, Position=2)]
		[string] $Arguments
	);
	$vbm = Get-VBoxManageExe;
	Write-Host "Executing `"$Command $Arguments`" on `"$VMName`"" -BackgroundColor Gray -ForegroundColor Black;
	(& $vbm guestcontrol `"$VMName`" run --username `"$VMUser`" --password `"$VMPassword`" --exe `"$Command`" -- `"$Arguments`" *>&1) | Out-String | Write-Host;
}

#function Invoke-VBoxCopy {
#	Param (
#		[string] $VMName,
#		[string] $Source,
#		[string] $Destination
#	);

#	Invoke-RemoteVBoxCommand -VMName $VMName -Command "cmd.exe" -Arguments "/c copy `"E:\\$Source`" `"$Destination`"";
#}

function Get-VBoxManageExe {
	$vbm = @("${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe","${env:ProgramFiles}\Oracle\VirtualBox\VBoxManage.exe") | where { Test-Path -Path $_ } | Select-Object -First 1;
	if($vbm -eq $null) {
		Write-Host "Unable to locate VirtualBox tools. Installing via Chocolatey.";
		$choc = Get-ChocolateyExe;
		& $choc install virtualbox vboxguestadditions.install -y | Write-Host;
	}
	return $vbm;
}

function Invoke-VBoxUpgrade {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $OS,
		[Parameter(Mandatory=$true, Position=1)]
		[string] $IEUpgradeVersion,
		[Parameter(Mandatory=$true, Position=2)]
		[string] $VMName,
		[Parameter(Mandatory=$true, Position=3)]
		[string] $VMRootPath
	);
	$urls = @{
		"WinXPIE7" = "http://download.microsoft.com/download/3/8/8/38889dc1-848c-4bf2-8335-86c573ad86d9/IE7-WindowsXP-x86-enu.exe";
		"WinVistaIE8" = "http://download.microsoft.com/download/F/8/8/F88F09A2-A315-44C0-848E-48476A9E1577/IE8-WindowsVista-x86-ENU.exe";
		"WinVistaIE9" = "http://download.microsoft.com/download/0/8/7/08768091-35BC-48E0-9F7F-B9802A0EE2D6/IE9-WindowsVista-x86-enu.exe";
	}

	$key = "Win${OS}IE${IEUpgradeVersion}";
	if(!($urls.ContainsKey($key))) {
		throw [ArgumentException] "Unsupported upgrade Win${OS} -> IE $IEUpgradeVersion";
	}

	$upgrade = "$key-upgrade.exe";
	$upgradePath = (Join-Path $VMRootPath -ChildPath $upgrade);
	Start-BitsTransfer -Source $urls[$key] -Destination $upgradePath;
	Invoke-VBoxCopy -VMName $VMName -Source $upgrade -Destination "c:\users\IEUser\downloads\$upgrade";

}
function Wait-VBoxGuestControl {
	try {
		$vbm = Get-VBoxManageExe;
		Write-Host "Waiting for Guest Additions Control Process (Max 3 minutes wait)." -BackgroundColor Gray -ForegroundColor Black -NoNewline;
		$timeout = new-timespan -Minutes 3
		$sw = [diagnostics.stopwatch]::StartNew()
		while ($sw.elapsed -lt $timeout){
			$r = & "$vbm" showvminfo `"$VMName`" 2>&1 | Out-String;
			if($r -match "Additions\srun\slevel\:\s+3") {
				# vm does not exist.
				Write-Host "Guest Additions Ready." -BackgroundColor Gray -ForegroundColor Black;
				return $true;
			}
			Write-Host "." -NoNewline -BackgroundColor Gray -ForegroundColor Black;
			Start-Sleep -Seconds 1;
		}
		Write-Host "Guest Additions wait timed out." -BackgroundColor Gray -ForegroundColor Black;
		return $false;
	} catch {
		return $false;
	}
}
#endregion

#region Chocolatey
function Get-ChocolateyExe {
	$cho = "$env:ProgramData\chocolatey\choco.exe";
	if(!(Test-Path -Path $cho) ) {
		Write-Host -BackgroundColor Red -ForegroundColor White "Unable to locate chocolatey. Installing chocolatey...";
		Invoke-InstallChocolatey;
		if(!(Test-Path -Path $cho) ) {
			throw [System.IO.FileNotFoundException] "Still unable to locate chocolatey, even after install attempt."
		}
	}
	return $cho;
}

function Invoke-InstallChocolatey {
	Invoke-Expression -Command ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) | Write-Host;
}

#endregion

function Get-FileMD5Hash {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $Path
	)
	$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider;
	$stream = [System.IO.File]::Open("$Path",[System.IO.Filemode]::Open, [System.IO.FileAccess]::Read);
	$hash = [System.BitConverter]::ToString($md5.ComputeHash($stream)) -replace "-", "";
	$stream.Close();
	return $hash;
}


function Test-MD5Hash {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $VMName,
		[Parameter(Mandatory=$true, Position=1)]
		[string] $VMHost,
		[Parameter(Mandatory=$true, Position=2)]
		[string] $Path
	)
	begin {
		$hashes = @{
			"VirtualBox" = @{
				"IE6 - WinXP" = "1FE27A06C0A8E0CB3EE6D27DFE3C634A";
				"IE7 - WinXP" = "1FE27A06C0A8E0CB3EE6D27DFE3C634A";
				"IE8 - WinXP" = "EFBF507C4A3CE533C7AE539E59FB8A17";
				"IE7 - WinVista" = "C144A18EA40848F2611036448D598002";
				"IE8 - WinVista" = "C144A18EA40848F2611036448D598002";
				"IE9 - WinVista" = "C144A18EA40848F2611036448D598002";
				"IE8 - Win7" = "86D481F517CA18D50F298FC9FB1C5A18";
				"IE9 - Win7" = "61A2B69A5712ABD6566FCBD1F44F7A2B";
				"IE10 - Win7" = "755F05AF1507CD8940354BF564A08D50";
				"IE11 - Win7" = "7AA66EC15A51EE8B0A4AB39353472F07";
				"IE10 - Win8" = "CAF9FCEF0A4EE13A236BDC7BDB9FF1D3";
				"IE11 - Win8.1" = "080C652C69359B6742DE547BA594AB2A";
				"IE11 - Win10" = "8A441819E97F8766E25FAA810BD1FF4F";
			}
		};
	}
	process {
		if((Get-Command -Name "Get-FileHash") -eq $null) {
			$hash = (Get-FileMD5Hash -Path $Path);
		} else {
			$hash = (Get-FileHash -Path $Path -Algorithm MD5).Hash;
		}
		$chash = $hashes[$VMHost][$VMName];
		Write-Host "MD5 Compare: '$hash' -> '$chash'" -BackgroundColor Gray -ForegroundColor Black;
		return $hash -ieq $chash;
	}
}

function Download-File {
  Param (
    [string] $Url,
    [string] $File
  );
  $downloader = (new-object System.Net.WebClient);
  $downloader.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;
  $downloader.DownloadFile($Url, $File);
}

function Expand-7ipArchive {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $Path,
		[Parameter(Mandatory=$true, Position=1)]
		[string] $DestinationPath
	);

	if((Get-Command -Name "Expand-Archive") -eq $null) {
		$toolsDir = (Join-Path $PSScriptRoot "tools");
		if(!(Test-Path -Path $toolsDir)) {
			New-Item -Path $toolsDir -ItemType Directory | Out-Null;
		}
		$7zaExe = (Join-Path $toolsDir '7za.exe');
		if(!(Test-Path -Path $7zaExe)) {
			# download 7zip
			Write-Host "Download 7Zip commandline tool";
			Download-File -Url 'https://raw.githubusercontent.com/camalot/psievm/master/psievm/.tools/7za.exe' -File "$7zaExe";
		}
		Start-Process "$7zaExe" -ArgumentList "x -o`"$DestinationPath`" -y `"$Path`"" -Wait -NoNewWindow | Write-Host;
	} else {
		Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force;
	}
}
