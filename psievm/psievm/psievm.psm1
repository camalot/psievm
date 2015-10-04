<#
	this is loosely based on https://github.com/xdissent/ievms/blob/master/ievms.sh
#>
$PSIEVMVERSION = "0.1.0.0";
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
		[ValidateSet("XP", "Vista", "7", "8", "8.1", "10", "WinXP","WinVista", "Win7", "Win8", "Win8.1", "Win10", "WindowsXP","WindowsVista", "Windows7", "Windows8", "Windows8.1", "Windows10")]
		[Parameter(Mandatory=$true, Position=0)]
		[string] $OS,
		[Parameter(Mandatory=$false, Position=2)]
		[string[]] $Shares,
		[Parameter(Mandatory=$false,Position=3)]
		[string] $AlternateVMLocation = "",
		[Parameter(Mandatory=$false, Position=4)]
		[ValidateSet("VirtualBox", "VMWare", "VPC", "HyperV", "Vagrant")]
		[string] $VMHost = "VirtualBox",
		[Parameter(Mandatory=$false, Position=5)]
		[bool] $IgnoreInvalidMD5 = $false
	);

	DynamicParam {
		# Set the dynamic parameters' name
		$ievParam = "IEVersion";
		# Create the dictionary 
		$RuntimeParameterDictionary = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameterDictionary;
		# Create the collection of attributes
		$AttributeCollection = New-Object -TypeName System.Collections.ObjectModel.Collection[System.Attribute];
		# Create and set the parameters' attributes
		$ParameterAttribute = New-Object -TypeName System.Management.Automation.ParameterAttribute;
		$ParameterAttribute.Mandatory = $true;
		$ParameterAttribute.Position = 1;

		# Add the attributes to the attributes collection
		$AttributeCollection.Add($ParameterAttribute);
		$arrSet = @();
		switch ($OS) {
			"^(win(dows)?)?xp" {
				$OS = "XP";
				$arrSet = @("6","8");
			}
			"^(win(dows)?)?vista" {
				$OS = "Vista";
				$arrSet = @("7");
			}
			"^(win(dows)?)?7" {
				$OS = "7";
				$arrSet = @("8","9","10","11");
			}
			"^(win(dows)?)?8" {
				$OS = "8";
				$arrSet = @("10");
			}
			"^(win(dows)?)?8.1" {
				$OS = "8.1";
				$arrSet = @("11");
			}
			"^(win(dows)?)?10" {
				$OS = "10";
				$arrSet = @("Edge");
			}
		}
		$ValidateSetAttribute = New-Object -TypeName System.Management.Automation.ValidateSetAttribute($arrSet);
		# Add the ValidateSet to the attributes collection
		$AttributeCollection.Add($ValidateSetAttribute);
		# Create and return the dynamic parameter
		$RuntimeParameter = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter($ievParam, [string], $AttributeCollection);
		$RuntimeParameterDictionary.Add($ievParam, $RuntimeParameter);
		return $RuntimeParameterDictionary;
	}

	begin {
		$VMUser = "IEUser";
		$VMPassword = "Passw0rd!";
		$IEVersion = $PsBoundParameters[$ievParam];

		switch ($VMHost) {
			"HyperV" {
				$VMHost = "HyperV_2012";
				$vmext = "vhd";
				throw "Currently unsupported VMHost : $VMHost";
				return;
			}
			"VirtualBox" {
				$vmext = "ova";
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


		# No alternate VM Location is specified, download from ms
		if($AlternateVMLocation -eq "" -or $AlternateVMLocation -eq $null) {
			$buildNumber = "20141027";
			$baseURL = "https://az412801.vo.msecnd.net/vhd/VMBuild_{0}/{3}/IE{1}/Windows/IE{1}.{3}{2}.For.Windows.{4}.zip";		
			switch -Regex ($IEVersion) {
				"^edge$" {
					$buildNumber = "20150801";
					$baseURL = "https://az792536.vo.msecnd.net/vms/VMBuild_{0}/{3}/MS{1}/Windows/Microsoft%20{1}.{3}{2}.For.Windows.{4}.zip";
				}
			}
			$url = $baseURL -f $buildNumber, $IEVersion, $OS, @{$true="";$false="Win"}[$OS -imatch "^(xp|vista)$"], $VMHost;
		} else {
			# use alternate path for the images (like a share)
			$baseFile = "IE{0}.{2}{1}.For.Windows.{3}.zip";
			# combine the paths, validate and add missing slashes if needed
			$baseUrl = "{0}$AlternateVMLocation{2}{1}" -f (@{$true="";$false="\\"}[$AlternateVMLocation -imatch "^(\\\\|https?:\/\/|[a-z]:\\)"]), 
				($baseFile -f $IEVersion, $OS,  @{$true="";$false="Win"}[$OS -imatch "^(xp|vista)$"], $VMHost),
				@{$true="";$false="/"}[$AlternateVMLocation -match "(\\|\/)$"];
			$url = $baseURL;
		}

		$vmName = ("IE{0} - Win{1}" -f $IEVersion, $OS);
		$vmPath = (Join-Path -Path $pwd -ChildPath $vmName);
		
		$vmImportFile = (Join-Path -Path $vmPath -ChildPath "${vmName}.${vmext}" );
		$zip = (Join-Path -Path $vmPath -ChildPath "${vmName}.zip");
	}
	
	process {
		# if the vmPath doesnt exist, create it.
		if(!(Test-Path -Path $vmPath)) {
			Write-Host ("Creating path `"$vmPath`"") -BackgroundColor Gray -ForegroundColor Black;
			New-Item -Path $vmPath -ItemType Directory | Out-Null;
		}

		
		# if the VM does not exist
		if( !(Test-VMHost -VMHost $VMHost -VMName $vmName) ) {
			if(!(Test-Path -Path $zip) -and !(Test-Path -Path $vmImportFile)) {
				Write-Host ("Transfer from: `"$url`" -> `"$zip`"") -BackgroundColor Gray -ForegroundColor Black;
				Start-BitsTransfer -Source $url -Destination $zip;
			}

			if((Test-Path -Path $zip) -and !(Test-Path -Path $vmImportFile)) {
				Write-Host ("Validating MD5 File Hash `"$zip`"") -BackgroundColor Gray -ForegroundColor Black;
				if(!(Validate-ZipMD5 -Path $zip -VMName $vmName -VMHost $VMHost)) {
					Write-Host "MD5 hash validation of zip '$zip' failed." -BackgroundColor @{$true="Yellow";$false="Red"}[$IgnoreInvalidMD5] -ForegroundColor @{$true="Black";$false="White"}[$IgnoreInvalidMD5];
					if(!$IgnoreInvalidMD5) {
						return;
					}
				}
				Write-Host ("Extracting `"$zip`" -> `"$vmPath`"") -BackgroundColor Gray -ForegroundColor Black;
				Expand-Archive -Path $zip -DestinationPath (Split-Path -Path $zip) -Force;
				Write-Host ("Deleting `"$zip`"") -BackgroundColor Gray -ForegroundColor Black;
				Remove-Item -Path $zip -Force | Out-Null;
			}

			if( !(Test-Path -Path $vmImportFile) ) {
				Write-Host "VM import file '$vmImportFile' not found." -BackgroundColor Red -ForegroundColor White;
				return;
			}

			Import-VMImage -VMHost $VMHost -VMName $vmName -ImportFile $vmImportFile -IEVersion $IEVersion -OS $OS -Shares $Shares;
		}

		Start-VMHost -VMHost $VMHost -VMName $vmName;
	}
}

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
			return Import-VBoxImage -IEVersion $IEVersion -OS $OS -VMName $VMName -ImportFile $ImportFile -Shares $Shares
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
		[string] $VMName
	);
	switch($VMHost) {
		"VirtualBox" {
			return Start-VBoxVM -VMName $VMName;
		}
		default {
			return $false;
		}
	};
}

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
}

function Start-VBoxVM {
	Param (
		[Parameter(Mandatory=$true, Position=0)]
		[string] $VMName
	);
	$vbm = Get-VBoxManageExe;
	Write-Host "Starting VM `"$VMName`"" -BackgroundColor Gray -ForegroundColor Black;
	& $vbm startvm `"$VMName`";
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
			# vm does not exist.
			return $false;
		}
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
	(& $vbm guestcontrol `"$VMName`" run --username `"$VMUser`" --password `"$VMPassword`" --exe `"$Command`" -- `"$Arguments`" *>&1) | select-object @{$true=$_.ToString();$false=""}[$_ -ne $null] | Write-Host;
}

function Get-VBoxManageExe {
	$vbm = @("${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe","${env:ProgramFiles}\Oracle\VirtualBox\VBoxManage.exe") | where { Test-Path -Path $_ } | Select-Object -First 1;
	if($vbm -eq $null) {
		Write-Host "Unable to locate VirtualBox tools. Installing via Chocolatey.";
		$choc = Get-ChocolateyExe;
		& $choc install virtualbox vboxguestadditions.install -y | Write-Host;
	}
	return $vbm;
}

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
	Invoke-Expression -Command ((new-object -TypeName net.webclient).DownloadString('https://chocolatey.org/install.ps1')) | Write-Host;
}

function Validate-ZipMD5 {
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
				"IE8 - WinXP" = "EFBF507C4A3CE533C7AE539E59FB8A17";
				"IE7 - WinVista" = "C144A18EA40848F2611036448D598002";
				"IE8 - Win7" = "86D481F517CA18D50F298FC9FB1C5A18";
				"IE9 - Win7" = "61A2B69A5712ABD6566FCBD1F44F7A2B";
				"IE10 - Win7" = "755F05AF1507CD8940354BF564A08D50";
				"IE11 - Win7" = "7AA66EC15A51EE8B0A4AB39353472F07";
				"IE10 - Win8" = "CAF9FCEF0A4EE13A236BDC7BDB9FF1D3";
				"IE11 - Win8.1" = "080C652C69359B6742DE547BA594AB2A";
				"Edge - Win10" = "";
			}
		};
	}
	process {
		$hash = (Get-FileHash -Path $Path -Algorithm MD5).Hash;
		$chash = $hashes[$VMHost][$VMName];
		Write-Host "MD5 Compare: '$hash' -> '$chash'" -BackgroundColor Gray -ForegroundColor Black;
		return $hash -ieq $chash;
	}
}

