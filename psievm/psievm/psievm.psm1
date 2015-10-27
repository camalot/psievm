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


$script:PSIEVM = "psievm";

#region Exported Functions

function Get-IEVM {
	<#

	.SYNOPSIS

	Gets an IE VM from modern.ie and imports it to the supported VM Host.


	.DESCRIPTION



	.PARAMETER OS

	The OS version. Supported values:

	- XP, WinXP, Windows XP
	- Vista, WinVista, Windows Vista
	- 7, Win7, Windows 7
	- 8, Win8, Windows 8
	- 8.1, Win8.1, Windows 8.1
	- 10, Win10, Windows 10

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

	Defines the VM host to use. Supported VM hosts: VirtualBox

	.PARAMETER IgnoreInvalidMD5

	If exists, it will ignore the zip file MD5 hash check.

	.PARAMETER VMRootPath

	The path to store the VM files.

	.EXAMPLE

	Get-IEVM -OS XP -IEVersion 6 -VMHost VirtualBox

	Get the IE6 on Windows XP VM for VirtualBox

	.EXAMPLE

	Get-IEVM -OS Win7 -IEVersion 9 -VMHost VirtualBox -AlternateVMLocation "\\vmhost-machine\VirtualBox\"

	Get the IE9 on Windows 7 VM for VirtualBox from your company network share

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
			}
			"^(win(dows)?)?\s?vista$" {
				$OS = "Vista";
				$arrSet = @("7");
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
		Write-Output "Initializing for VMHost '$VMHost'" -BackgroundColor Gray -ForegroundColor Black;
		$vmIE = @{$true="11";$false="$IEVersion"}[$IEVersion -ieq "edge"];
		$vmName = ("IE{0} - Win{1}" -f $vmIE, $OS);
		$vmPath = (Join-Path -Path $VMRootPath -ChildPath $vmName);

		switch ($VMHost) {
			"VirtualBox" {
				$vmext = "ova";
			}
			# There is no default, because if it isn't valid, it wont get this far.
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

		$baseVMName = ("IE$vmIE - Win$OS");
		$vmImportFile = (Join-Path -Path $vmPath -ChildPath "${baseVMName}.${vmext}" );
		$zip = (Join-Path -Path $vmPath -ChildPath "${vmName}.zip");
	}

	process {
		#Write-Output "$PSIEVM v$PSIEVMVersion" -ForegroundColor Yellow;

		# if the VM does not exist
		if( !(Test-VMHost -VMHost $VMHost -VMName $vmName) ) {

			# if the vmPath doesnt exist, create it.
			if(!(Test-Path -Path $vmPath)) {
				Write-Output ("Creating path `"$vmPath`"") -BackgroundColor Gray -ForegroundColor Black;
				New-Item -Path $vmPath -ItemType Directory | Out-Null;
			}

			if(!(Test-Path -Path $zip) -and !(Test-Path -Path $vmImportFile)) {
				Write-Output ("Transfer from: `"$url`" -> `"$zip`"") -BackgroundColor Gray -ForegroundColor Black;
				Start-BitsTransfer -Source $url -Destination $zip;
			}

			if((Test-Path -Path $zip) -and !(Test-Path -Path $vmImportFile)) {
				Write-Output ("Validating MD5 File Hash `"$zip`"") -BackgroundColor Gray -ForegroundColor Black;
				$shouldIgnoreMD5Validation = $PSBoundParameters.ContainsKey('IgnoreInvalidMD5');
				if(!($shouldIgnoreMD5Validation)) {
					if(!(Test-MD5Hash -Path $zip -VMName $vmName -VMHost $VMHost)) {
						throw "MD5 hash validation of zip '$zip' failed.";
					}
				}
				Write-Output ("Extracting `"$zip`" -> `"$vmPath`"") -BackgroundColor Gray -ForegroundColor Black;
				Expand-7ZipArchive -Path $zip -DestinationPath (Split-Path $zip);
				Write-Output ("Deleting `"$zip`"") -BackgroundColor Gray -ForegroundColor Black;
				Remove-Item -Path $zip -Force | Out-Null;
			}

			if( !(Test-Path -Path $vmImportFile) ) {
				Write-Output "VM import file '$vmImportFile' not found." -BackgroundColor Red -ForegroundColor White;
				throw "VM import file '$vmImportFile' not found.";
			}
			# Add the VMRootPath to the shares.
			#$Shares.Add($VMRootPath) | Out-Null;
			$importSuccess = Import-VMImage -VMHost $VMHost -VMName $vmName -ImportFile $vmImportFile -IEVersion $IEVersion -OS $OS -VMRootPath $VMRootPath -Shares $Shares;
			if(!$importSuccess) {
				Write-Output "VM import failed." -BackgroundColor Red -ForegroundColor White;
				throw "VM import failed.";
			}
		}

		$startResult = Start-VMHost -VMHost $VMHost -VMName $vmName -VMRootPath $VMRootPath;

		if(-not $startResult) {
			throw "Error starting VM '$vmName' on host '$VMHost' at '$VMRootPath'";
		}
	}
}

Set-Alias -Name psievm -Value Get-IEVM;

function Update-PSIEVM {
	<#
	.SYNOPSIS
	Updates the installed version to the latest version that is available on github.
	.EXAMPLE
	Update-PSIEVM
	#>
	iex ((new-object net.webclient).DownloadString("https://raw.githubusercontent.com/camalot/psievm/master/psievm/psievm.package/tools/chocolateyInstall.ps1"));
}
#endregion


function Import-VMImage {
	Param (
		[Parameter(Mandatory=$true)]
		[string] $IEVersion,
		[Parameter(Mandatory=$true)]
		[string] $OS,
		[Parameter(Mandatory=$true)]
		[string] $VMHost,
		[Parameter(Mandatory=$true)]
		[string] $VMName,
		[Parameter(Mandatory=$true)]
		[string] $ImportFile,
		[Parameter(Mandatory=$true)]
		[string] $VMRootPath,
		[Parameter(Mandatory=$false)]
		[string[]] $Shares
	);

	switch($VMHost) {
		"VirtualBox" {
			return Import-VBoxImage -IEVersion $IEVersion -OS $OS -VMName $VMName -ImportFile $ImportFile -VMRootPath (Join-Path -Path $VMRootPath -ChildPath $VMName) -Shares $Shares;
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
		[Parameter(Mandatory=$true)]
		[string] $VMHost,
		[Parameter(Mandatory=$true)]
		[string] $VMName,
		[Parameter(Mandatory=$false)]
		[string] $VMRootPath
	);
	switch($VMHost) {
		"VirtualBox" {
			return Start-VBoxVM -VMName $VMName -VMRootPath $VMRootPath;
		}
		default {
			return $false;
		}
	};
}

#region VirtualBox
function Import-VBoxImage {
	Param (
		[Parameter(Mandatory=$true)]
		[string] $IEVersion,
		[Parameter(Mandatory=$true)]
		[string] $OS,
		[Parameter(Mandatory=$true)]
		[string] $VMName,
		[Parameter(Mandatory=$true)]
		[string] $ImportFile,
		# This should be the directory that contains the ova, the disk, everything.
		[Parameter(Mandatory=$true)]
		[string] $VMRootPath,
		[Parameter(Mandatory=$false)]
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
		$vbox = (Join-Path -Path $VMRootPath -ChildPath "${$VMName}.vbox");
		$disk = (Join-Path -Path $VMRootPath -ChildPath ("$VMName-disk1.vmdk"));
		Write-Output ("Importing $ImportFile to VM `"$VMName`"") -BackgroundColor Gray -ForegroundColor Black;

		#(& $vbm import `"$ImportFile`" --vsys 0 --vmname `"$VMName`" --unit $vbunit --disk `"$disk`" 2>&1 | Out-String) | Out-Null;
		Invoke-ShellCommand -Command $vbm -CommandArgs @("import",  "`"$ImportFile`"", "--vsys", "0", "--vmname", "`"$VMName`"", "--unit",  "$vbunit", "--disk", "`"$disk`"") | Out-Null;
		$Shares | where { $_ -ne "" -and $_ -ne $null; } | foreach {
			$shareName = (Split-Path -Path $_ -Leaf);
			Write-Output ("Adding share `"$shareName`" on VM `"$VMName`"") -BackgroundColor Gray -ForegroundColor Black;
			Invoke-ShellCommand -Command $vbm -CommandArgs @( "sharefolder", "add", "`"$VMName`"", "--name", "`"$shareName`"", "--automount", "--hostpath", "`"$_`"") | Out-Null;
			#(& $vbm sharedfolder add `"$VMName`" --name `"$shareName`" --automount --hostpath `"$_`" 2>&1 | Out-String) | Out-Null;
		};

		#$dt = (Get-Date -Format 'MM-dd-yyyy hh:mm');
		#(& $vbm setextradata `"$VMName`" `"psievm`" `"{\`"created\`" : \`"$dt\`", \`"version\`" : \`"$PSIEVMVERSION`"}\`" 2>&1 | Out-String) | Out-Null;
		#Invoke-ShellCommand -Command $vbm -CommandArgs @("setextradata", "`"$VMName`"", "`"psievm`"", "`"{\`"created\`" : \`"$dt\`", \`"version\`" : \`"$PSIEVMVERSION`"}\`"") | Out-String | Out-Null;
		
		Write-Output ("Taking initial snapshot of `"$VMName`"") -BackgroundColor Gray -ForegroundColor Black;

		#(& $vbm snapshot `"$VMName`" take clean --description `"The initial VM state.`" 2>&1 | Out-String) | Out-Null;
		Invoke-ShellCommand -Command $vbm -CommandArgs @("snapshot", "`"$VMName`"", "take", "clean", "--description", "`"The initial VM state.`"") | Out-Null;
		return $true;
	} catch [System.Exception] {
		return $false;
	}
}

function Start-VBoxVM {
	Param (
		[Parameter(Mandatory=$true)]
		[string] $VMName,
		[Parameter(Mandatory=$false)]
		[string] $VMRootPath
	);
	try {
		$vbm = Get-VBoxManageExe;
		Write-Output "Starting VM `"$VMName`"" -BackgroundColor Gray -ForegroundColor Black;
		#(& $vbm startvm `"$VMName`" *>&1) | Write-Output;
		Invoke-ShellCommand -Command "$vbm" -CommandArgs "startvm", "`"$VMName`"" | Out-Null;
		return $true;
	} catch [Exception] {
		return $false;
	}
}

function Test-VBoxVM {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $VMName
	);
	try {
		$vbm = Get-VBoxManageExe;
		Write-Output "Testing if VM `"$VMName`" already exists in VirtualBox" -BackgroundColor Gray -ForegroundColor Black;
		#$r = & "$vbm" showvminfo `"$VMName`" 2>&1 | Out-String;
		$r = Invoke-ShellCommand -Command $vbm -CommandArgs "showvminfo", "`"$VMName`"";
		$vmnEscaped = [Regex]::Escape($VMName);
		if($r -imatch "Could\snot\sfind\sa\sregistered\smachine\snamed\s'$vmnEscaped'") {
			Write-Output ("VM Image not found in VirtualBox.") -BackgroundColor Gray -ForegroundColor Black;
			# vm does not exist.
			return $false;
		}
		Write-Output ("VM Image found in VirtualBox.") -BackgroundColor Gray -ForegroundColor Black;
		return $true;
	} catch {
		return $false;
	}
}

#function Invoke-RemoteVBoxCommand {
#	Param (
#		[Parameter(Mandatory=$true, Position=0)]
#		[string] $VMName,
#		[Parameter(Mandatory=$true, Position=1)]
#		[string] $Command,
#		[Parameter(Mandatory=$false, Position=2)]
#		[string] $Arguments
#	);
#	$vbm = Get-VBoxManageExe;
#	Write-Output "Executing `"$Command $Arguments`" on `"$VMName`"" -BackgroundColor Gray -ForegroundColor Black;
#	#(& $vbm guestcontrol `"$VMName`" run --username `"$VMUser`" --password `"$VMPassword`" --exe `"$Command`" -- `"$Arguments`" *>&1) | Out-String | Write-Output;
#	if(Wait-VBoxGuestControl) {
#		Invoke-ShellCommand -Command $vbm -CommandArgs @("guestcontrol", "`"$VMName`"", "run", "--username", "`"$VMUser`"", "--password", "`"$VMPassword`"", "--exe", "`"$Command`"", "--", "`"$Arguments`"");
#	} else {
#		"Unable to execute remote command.`nUnable to get guestcontrol" | Write-Output;
#	}
#}


function Get-VBoxManageExe {
	$vbm = @("${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe","$($env:ProgramFiles)\Oracle\VirtualBox\VBoxManage.exe") | where { Test-Path -Path $_ } | select -First 1;
	if($vbm -eq $null) {
		Write-Output "Unable to locate VirtualBox tools. Installing via Chocolatey.";
		Install-ChocolateyApp -Names virtualbox, vboxguestadditions.install;

		return "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe";
	}
	return $vbm;
}

#function Wait-VBoxGuestControl {
#	try {
#		$vbm = Get-VBoxManageExe;
#		Write-Output "Waiting for Guest Additions Control Process (Max 3 minutes wait)." -BackgroundColor Gray -ForegroundColor Black -NoNewline;
#		$timeout = new-timespan -Minutes 3
#		$sw = [diagnostics.stopwatch]::StartNew()
#		while ($sw.elapsed -lt $timeout){
#			$r = Invoke-ShellCommand -Command $vbm -CommandArgs @("showvminfo", "`"$VMName`"");
#			if($r -match "Additions\srun\slevel\:\s+3") {
#				# vm does not exist.
#				Write-Output "Guest Additions Ready." -BackgroundColor Gray -ForegroundColor Black;
#				return $true;
#			}
#			Write-Output "." -NoNewline -BackgroundColor Gray -ForegroundColor Black;
#			Start-Sleep -Seconds 1;
#		}
#		Write-Output "Guest Additions wait timed out." -BackgroundColor Gray -ForegroundColor Black;
#		return $false;
#	} catch {
#		return $false;
#	}
#}
#endregion

#region Chocolatey
function Get-ChocolateyExe {
	$cho = "$env:ProgramData\chocolatey\choco.exe";
	if(!(Test-Path -Path $cho) ) {
		Write-Output -BackgroundColor Red -ForegroundColor White "Unable to locate chocolatey. Installing chocolatey...";
		Invoke-InstallChocolatey;
		if(!(Test-Path -Path $cho) ) {
			throw [System.IO.FileNotFoundException] "Still unable to locate chocolatey, even after install attempt."
		}
	}
	return $cho;
}

function Invoke-InstallChocolatey {
	Invoke-Expression -Command ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) | Write-Output;
}

function Install-ChocolateyApp {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string[]] $Names
	);

	$choc = Get-ChocolateyExe;
	$list = ($Names -join " ");
	$args = "install -y $list" -split " ";
	Invoke-ShellCommand -Command $choc -CommandArgs $args;
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
			$hash = (Get-FileHash -Path $Path -Algorithm MD5 -Verbose).Hash;
		}
		if(!($hashes.ContainsKey($VMHost)) -or !($hashes[$VMHost].ContainsKey($VMName))) {
			Write-Warning "No Hash Available for $($VMHost):$($VMName)";
			return $true;
		}
		$chash = $hashes[$VMHost][$VMName];
		Write-Output "MD5 Compare: '$hash' -> '$chash'" -BackgroundColor Gray -ForegroundColor Black;
		return $hash -ieq $chash;
	}
}

function Invoke-DownloadFile {
	Param (
		[string] $Url,
		[string] $File
	);
	$downloader = (new-object System.Net.WebClient);
	$downloader.Proxy.Credentials=[System.Net.CredentialCache]::DefaultNetworkCredentials;
	$downloader.DownloadFile($Url, $File);
}

function Expand-7ZipArchive {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $Path,
		[Parameter(Mandatory=$true, Position=1)]
		[string] $DestinationPath
	);
	begin {
		$7zaUrl = "https://raw.githubusercontent.com/camalot/psievm/master/psievm/.tools/7za.exe";
		$scriptRootPath = Get-ScriptRoot;
		$toolsDir = (Join-Path -Path $scriptRootPath -ChildPath "tools");
		if(!(Test-Path -Path $toolsDir)) {
			New-Item -Path $toolsDir -ItemType Directory | Out-Null;
		}
		$7zaExe = (Join-Path -Path $toolsDir -ChildPath "7za.exe");
	}
	process {
		if(!(Test-Path -Path $7zaExe)) {
			# download 7zip
			Write-Output "Download 7Zip commandline tool";
			Invoke-DownloadFile -Url $7zaUrl -File "$7zaExe";
		}
		Start-Process "$7zaExe" -ArgumentList "x -o`"$DestinationPath`" -y `"$Path`"" -Wait -NoNewWindow | Write-Output;
	}
}

function Invoke-ShellCommand {
	param (
		[Parameter(Mandatory=$true)]
		[string] $Command,
		[Parameter(Mandatory=$false)]
		[string[]] $CommandArgs
	);
	$args = $CommandArgs -join " ";
	Write-Output "$Command $args";
	return (& "$Command" $CommandArgs *>&1);
}

function Get-ScriptRoot {
	if(-not $PSScriptRoot) {
		if(-not $PSCommandPath) {
			return (Split-Path -Path $MyInvocation.MyCommand.Path -Parent);
		} else {
			return (Split-Path -Path $PSCommandPath -Parent);
		}
	} else {
		return (Resolve-Path -Path $PSScriptRoot);
	}
}
