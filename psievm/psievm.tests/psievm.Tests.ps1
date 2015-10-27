if($PSCommandPath -eq $null) {
	Write-Output "Using MyInvoction.MyCommand.Path";
	$CommandRootPath = (Split-Path -Parent $MyInvocation.MyCommand.Path);
} else {
	Write-Output "Using PSCommandPath";
	$CommandRootPath = (Split-Path -Parent $PSCommandPath);
}

$module = Join-Path -Path $CommandRootPath -ChildPath "psievm.psm1";
$manifestPath = Join-Path -Path $CommandRootPath -ChildPath "psievm.psd1";

Import-Module $manifestPath -Force -Verbose;

Describe "Manifest Checks" {
	$script:manifest = $null;
	It "Has a valid manifest" {
		{
			$script:manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop -WarningAction SilentlyContinue;
		} | Should Not Throw;
	}

	It "Has a valid version in the manifest" {
		$script:manifest.Version -as [Version] | Should Not BeNullOrEmpty;
	}

	It "Has a valid GUID in the manifest" {
		$script:manifest.Guid | Should Be '1e452af5-f4d1-41c1-88f8-e2de734b9db6';
	}

	It "Exports Get-IEVM and Update-PSIEVM" {
		$script:manifest.ExportedFunctions.Values -join "|" | Should Be "Get-IEVM|Update-PSIEVM";
	}

	It "Aliases only psievm" {
		$script:manifest.ExportedAliases.Values -join "|" | Should Be "psievm";
	}

	It "Must have a version of 0.0.0.0" {
		$script:manifest.Version | Should Be "0.0.0.0";
	}

	It "Must support PowerShell Version 3.0" {
		$script:manifest.PowerShellVersion | Should Be "3.0";
	}
}

InModuleScope "psievm" {
	Describe "Start-VMHost" {
		Context "When VMHost is not VirtualBox" {
			$vmHost = "VMWare";
			$vmName = "IE9 - Win7";
			It "Must return false" {
				Start-VMHost -VMHost $vmHost -VMName $vmName | Should Be $false;
			}
		}
		Context "When VMHost is VirtualBox" {
			$vmHost = "VirtualBox";
			$vmName = "IE9 - Win7";

			Mock Start-VBoxVM { return $true; }
			It "Must return true" {
				Start-VMHost -VMHost $vmHost -VMName $vmName | Should Be $true;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 1 -Exactly;
			}
		}
	}

	Describe "Test-VMHost" {
		Context "When VMHost is not VirtualBox" {
			$vmHost = "VMWare";
			$vmName = "IE9 - Win7";
			It "must return false" {
				Test-VMHost -VMHost $vmHost -VMName $vmName | Should Be $false;
			}
		}
		Context "When VMHost is VirtualBox" {
			$vmHost = "VirtualBox";
			$vmName = "IE9 - Win7";

			Mock Test-VBoxVM { return $true; }
			It "must return true" {
				Test-VMHost -VMHost $vmHost -VMName $vmName | Should Be $true;
				Assert-MockCalled -CommandName Test-VBoxVM -Times 1 -Exactly;
			}
		}
	}

	Describe "Import-VMImage" {
		Context "When VMHost is not VirtualBox" {
			$vmHost = "VMWare";
			$vmName = "IE9 - Win7";

			It "must return false" {
				Import-VMImage -VMHost $vmHost -VMName $vmName -OS 7 -IEVersion 9 -ImportFile "c:\vms\$vmName.box" -VMRootPath "c:\vms\" | Should Be $false;
			}
		}

		Context "When VMHost is VirtualBox" {
			$vmHost = "VirtualBox";
			$vmName = "IE9 - Win7";

			Mock Import-VBoxImage { return $true; }
			It "must return true" {
				Import-VMImage -VMHost $vmHost -VMName $vmName -OS 7 -IEVersion 9 -ImportFile "c:\vms\$vmName.box" -VMRootPath "c:\vms\" | Should Be $true;
				Assert-MockCalled -CommandName Import-VBoxImage -Times 1 -Exactly;
			}
		}
	}

	Describe "Get-VBoxManageExe" {
		Context "When VirtualBox Not Installed" {
			Mock Install-ChocolateyApp { };
			Mock Test-Path { return $false; }
			It "Must install VirtualBox via Chocolatey" {
				Get-VBoxManageExe | Should BeExactly "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe";
				Assert-MockCalled -CommandName "Install-ChocolateyApp" -Times 1 -Exactly;
			};
		}

		Context "When VirtualBox Is Installed" {
			Mock Install-ChocolateyApp { };
			Mock Test-Path { return $true; }
			It "Must return first path" {
				Get-VBoxManageExe | Should BeExactly "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe";
				Assert-MockCalled -CommandName "Install-ChocolateyApp" -Times 0 -Exactly;
			};
		}

		Context "When VirtualBox 64bit Is Installed" {
			Mock Install-ChocolateyApp { };
			Mock Test-Path { return $false; } -ParameterFilter { $Path -and $Path.StartsWith( "${env:ProgramFiles(x86)}\" ) };
			Mock Test-Path { return $true; } -ParameterFilter { $Path -and $Path.StartsWith( "$env:ProgramFiles\" )};
			It "Must return 64bit path when VirtualBox is installed" {
				Get-VBoxManageExe | Should BeExactly "${env:ProgramFiles}\Oracle\VirtualBox\VBoxManage.exe";
				Assert-MockCalled -CommandName "Install-ChocolateyApp" -Times 0 -Exactly;
			};
		}
	}

	Describe "Get-ChocolateyExe" {
		Context "When chocolatey is not installed" {
			$script:tpathCalled = 0;
			$chocoPath = "$env:ProgramData\chocolatey\choco.exe";
			# The first time this is called, it should return false.
			Mock Test-Path { $script:tpathCalled += 1; return @{$true=$false;$false=$true}[$script:tpathCalled -eq 1] };
			Mock Invoke-InstallChocolatey { };
			Mock Write-Output { return; } -ParameterFilter { $BackgroundColor -eq "Red" };
			It "Must install chocolatey" {
				Get-ChocolateyExe | Should BeExactly "$env:ProgramData\chocolatey\choco.exe";
				Assert-MockCalled -CommandName Invoke-InstallChocolatey -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 2 -Exactly;
			}
		}

		Context "When chocolatey is not installed and chocolatey fails to install" {
			$chocoPath = "$env:ProgramData\chocolatey\choco.exe";
			Mock Test-Path { return $false; };
			Mock Invoke-InstallChocolatey { };
			Mock Write-Output { return; } -ParameterFilter { $BackgroundColor -eq "Red" };
			It "Must throw FileNotFoundException" {
				{ return Get-ChocolateyExe } | Should Throw;
				Assert-MockCalled -CommandName Invoke-InstallChocolatey -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 2 -Exactly;
			}
		}

		Context "When chocolatey is installed" {
			$chocoPath = "$env:ProgramData\chocolatey\choco.exe";
			# The first time this is called, it should return false.
			Mock Test-Path { return $true; };
			Mock Invoke-InstallChocolatey { };
			It "Must install chocolatey" {
				Get-ChocolateyExe | Should BeExactly "$env:ProgramData\chocolatey\choco.exe";
				Assert-MockCalled -CommandName Invoke-InstallChocolatey -Times 0 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly;
			}
		}

	}

	Describe "Invoke-InstallChocolatey" {
		It "Should download and install chocolatey" {
			Mock Invoke-Expression { 
				param ( [string] $Command );

			};
			Mock New-Object {
				$retval = [PSCustomObject]@{};
				Add-Member -InputObject $retval -MemberType ScriptMethod DownloadString {
						param( [string] $url );
					return "Write-Output `"Choco Script`"";
				}
				return $retval;
		} -ParameterFilter {$TypeName -and ($TypeName -ilike 'Net.WebClient') }
			Invoke-InstallChocolatey | Should BeNullOrEmpty;
			Assert-MockCalled Invoke-Expression -Times 1 -Exactly;
		}
	}

	Describe "Install-ChocolateyApp" {
		Context "When need to install app" {
			Mock Invoke-ShellCommand { Write-Output "$Command $($CommandArgs -join " ")"};
			It "Should invoke the install" {
				Install-ChocolateyApp virtualbox, virtualbox.additions;
				Assert-MockCalled Invoke-ShellCommand -Times 1 -Exactly;
			}
		}
	}

	Describe "Get-ScriptRoot" -Tags ScriptRoot {
		Context "When PSScriptRoot has value" {
			It "Must return PSScriptRoot Value" {
				Get-ScriptRoot | Should Be (Test-Path -Path $PSScriptRoot);
			}
		}

		# I want to test the other possible values, but I can't get it to override the values.

		#Context "When PSScriptRoot does not have a value" {
		#	$global:PSScriptRoot = $null;
		#	It "Must return PSCommandPath Value" {
		#		$global:PSCommandPath = $TestDrive;
		#		$r = Get-ScriptRoot;
		#		$r | Should Be (Test-Path -Path $TestDrive);
		#		$r | Should Be $TestDrive;
		#	}
		#}
	}

	Describe "Get-FileMD5Hash" {
		Context "When the path exists" {
			It "Must return a valid MD5 hash" {

				$file = Join-Path -Path $TestDrive -ChildPath "hashme.file";
				New-Item -ItemType File -Force -Path $file;
				"Some text for the file" | Out-File -FilePath $file -Force;

				Get-FileMD5Hash -Path $file | Should Match "^[A-Z0-9]{32}$";

			}
		}
	}

	Describe "Test-MD5Hash" {
		Context "When VMHost is not VirtualBox and can Get-FileHash" {
			$vmHost = "VMWare";
			$vmName = "IE9 - Win7";
			$path = (Join-Path -Path $TestDrive -ChildPath "\IE9 - Win7\IE9 - Win7.vmw");

			Mock Get-Command {return @{};} -ParameterFilter { $Name -and $Name -eq "Get-FileHash"};
			Mock Get-FileHash { return @{ Hash = "61A2B69A5712ABD6566FCBD1F44F7A2B"; }; };
			Mock Get-FileMD5Hash { return "61A2B69A5712ABD6566FCBD1F44F7A2B"; };
			Mock Write-Warning { Microsoft.PowerShell.Utility\Write-Output $Object };
			Mock Write-Output { return; };
			It "must return true" {
				Test-MD5Hash -VMName $vmName -VMHost $vmHost -Path $path | Should Be $true;

				Assert-MockCalled Get-FileMD5Hash -Times 0 -Exactly;
				Assert-MockCalled Get-Command -Times 1 -Exactly;
				Assert-MockCalled Get-FileHash -Times 1 -Exactly;

			}
		}

		Context "When VMHost is not VirtualBox and cannot Get-FileHash" {
			$vmHost = "VMWare";
			$vmName = "IE9 - Win7";
			$path = (Join-Path -Path $TestDrive -ChildPath "\IE9 - Win7\IE9 - Win7.vmw");

			Mock Get-Command {return $null; } -ParameterFilter { $Name -and $Name -eq "Get-FileHash"};
			Mock Get-FileHash { return @{ Hash = "61A2B69A5712ABD6566FCBD1F44F7A2B"; }; };
			Mock Get-FileMD5Hash { return "61A2B69A5712ABD6566FCBD1F44F7A2B"; };
			Mock Write-Warning { Microsoft.PowerShell.Utility\Write-Output $Object };
			Mock Write-Output { return; };
			It "must return true" {
				Test-MD5Hash -VMName $vmName -VMHost $vmHost -Path $path | Should Be $true;

				Assert-MockCalled Get-FileMD5Hash -Times 1 -Exactly;
				Assert-MockCalled Get-Command -Times 1 -Exactly;
				Assert-MockCalled Get-FileHash -Times 0 -Exactly;

			}
		}

		Context "When VMHost is VirtualBox and cannot Get-FileHash" {
			$vmHost = "VirtualBox";
			$vmName = "IE9 - Win7";
			$path = (Join-Path -Path $TestDrive -ChildPath "\IE9 - Win7\IE9 - Win7.vmw");

			Mock Get-Command {return $null;} -ParameterFilter { $Name -and $Name -eq "Get-FileHash"};
			Mock Get-FileHash { return @{ Hash = "61A2B69A5712ABD6566FCBD1F44F7A2B"; }; };
			Mock Get-FileMD5Hash { return "61A2B69A5712ABD6566FCBD1F44F7A2B"; };
			Mock Write-Warning { Microsoft.PowerShell.Utility\Write-Output $Object };
			Mock Write-Output { return; };
			It "must return true" {
				Test-MD5Hash -VMName $vmName -VMHost $vmHost -Path $path | Should Be $true;

				Assert-MockCalled Get-FileMD5Hash -Times 1 -Exactly;
				Assert-MockCalled Get-Command -Times 1 -Exactly;
				Assert-MockCalled Get-FileHash -Times 0 -Exactly;

			}
		}

		Context "When VMHost is VirtualBox and can Get-FileHash" {
			$vmHost = "VirtualBox";
			$vmName = "IE9 - Win7";
			$path = (Join-Path -Path $TestDrive -ChildPath "\IE9 - Win7\IE9 - Win7.vmw");

			Mock Get-Command {return @{};} -ParameterFilter { $Name -and $Name -eq "Get-FileHash"};
			Mock Get-FileHash { return @{ Hash = "61A2B69A5712ABD6566FCBD1F44F7A2B"; }; };
			Mock Get-FileMD5Hash { return "61A2B69A5712ABD6566FCBD1F44F7A2B"; };
			Mock Write-Warning { Microsoft.PowerShell.Utility\Write-Output $Object };
			Mock Write-Output { return; };
			It "must return true" {
				Test-MD5Hash -VMName $vmName -VMHost $vmHost -Path $path | Should Be $true;

				Assert-MockCalled Get-FileMD5Hash -Times 0 -Exactly;
				Assert-MockCalled Get-Command -Times 1 -Exactly;
				Assert-MockCalled Get-FileHash -Times 1 -Exactly;

			}
		}
	}

	Describe "Expand-7ipArchive" {
		

		Context "When Destination Does not exist" {
			$rootPath = $TestDrive;
			$vmName = "IE9 - Win7";
			Mock Invoke-DownloadFile { return; };
			Mock Join-Path { return (Microsoft.PowerShell.Management\Join-Path -Path $rootPath -ChildPath "\tools\"); } -ParameterFilter { $ChildPath -eq "tools" };
			Mock Join-Path { return (Microsoft.PowerShell.Management\Join-Path -Path $rootPath -ChildPath "\tools\7za.exe"); } -ParameterFilter { $ChildPath -eq "7za.exe" };
			Mock Test-Path { return $false; };
			Mock New-Item { };
			$script:resultCommand = "";
			Mock Start-Process { $script:resultCommand = "$FilePath $ArgumentList"; }
			Mock Get-ScriptRoot {return (Microsoft.PowerShell.Management\Join-Path -Path $rootPath -ChildPath "\Modules\");; };
			It "Must Create Destination" {

				Expand-7ZipArchive -Path (Microsoft.PowerShell.Management\Join-Path -Path $rootPath -ChildPath "$vmName.zip") -DestinationPath (Microsoft.PowerShell.Management\Join-Path -Path $rootPath -ChildPath $vmName) | Should BeNullOrEmpty;
				$exe = (Microsoft.PowerShell.Management\Join-Path -Path $rootPath -ChildPath "tools\7za.exe");
				$folder = (Microsoft.PowerShell.Management\Join-Path -Path $rootPath -ChildPath "$vmName");
				$zip =  (Microsoft.PowerShell.Management\Join-Path -Path $rootPath -ChildPath "$vmName.zip");
				$expectedCommand = "$exe x -o`"$folder`" -y `"$zip`"";
			
				$script:resultCommand | Should BeExactly $expectedCommand;

				Assert-MockCalled Invoke-DownloadFile -Times 1 -Exactly;
				Assert-MockCalled Join-Path -Times 1 -Exactly -ParameterFilter { $ChildPath -eq "tools" };;
				Assert-MockCalled Join-Path -Times 1 -Exactly -ParameterFilter { $ChildPath -eq "7za.exe" };
				Assert-MockCalled Test-Path -Times 2 -Exactly;
				Assert-MockCalled Start-Process -Times 1 -Exactly;
				Assert-MockCalled Get-ScriptRoot -Times 1 -Exactly;
				Assert-MockCalled New-Item -Times 1 -Exactly;


			}

		}
	}

	Describe "Update-PSIEVM" {
		Mock iex { };
		It "Must Execute script" {
			Update-PSIEVM | Should BeNullOrEmpty;
		}
	}

	Describe "Get-IEVM" {
		Context "When Invalid VMHost" {
			$VMRoot = "$TestDrive";
			$ie = 7;
			$os = "XP";
			$vmName = "IE7 - WinXP";
			$vmHost = "VMWare";
			$altLocation = "$TestDrive";
			It "Must throw error" {
				$error = $null;
				try {
					Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost;
				} catch [Exception] {
					$error = $_;
				}
				$error | Should Not BeNullOrEmpty;
			}
		}
		Context "When Invalid IE Version" {
			$VMRoot = "$TestDrive";
			$ie = 7;
			$os = "XP";
			$vmName = "IE7 - WinXP";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			Mock Test-VMHost { return $true; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };
			It "Must Throw" {
				$error = $null;
				try {
					Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost;
				} catch [Exception] {
					$error = $_;
				}
				$expectedError = "The argument `"7`" does not belong to the set `"6,8`" specified by the ValidateSet attribute. Supply an argument that is in the set and then try the command again.";
				$error | Should Be $expectedError;
				Assert-MockCalled -CommandName Start-VMHost -Times 0 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 0 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;

			}
		}

		Context "When XP VM Exists" {
			$VMRoot = "$TestDrive";
			$ie = 6;
			$os = "XP";
			$vmName = "IE6 - WinXP";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			Mock Test-VMHost { return $true; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };

			Mock Write-Output { };
			It "Must Start VM" {
				Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost | Should BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
			}
		}

		Context "When Vista VM Exists" {
			$VMRoot = "$TestDrive";
			$ie = 7;
			$os = "Windows Vista";
			$vmName = "IE7 - WinVista";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			Mock Test-VMHost { return $true; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };

			Mock Write-Output { };
			It "Must Start VM" {
				Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost | Should BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
			}
		}

		Context "When Win7 VM Exists" {
			$VMRoot = "$TestDrive";
			$ie = 9;
			$os = "Windows 7";
			$vmName = "IE7 - Win7";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			Mock Test-VMHost { return $true; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };

			Mock Write-Output { };
			It "Must Start VM" {
				Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost | Should BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
			}
		}

		Context "When Win8 VM Exists" {
			$VMRoot = "$TestDrive";
			$ie = 10;
			$os = "Windows 8";
			$vmName = "IE10 - Win8";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			Mock Test-VMHost { return $true; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };

			Mock Write-Output { };
			It "Must Start VM" {
				Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost | Should BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
			}
		}

		Context "When Win8.1 VM Exists" {
			$VMRoot = "$TestDrive";
			$ie = 11;
			$os = "Windows 8.1";
			$vmName = "IE11 - Win8.1";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			Mock Test-VMHost { return $true; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };

			Mock Write-Output { };
			It "Must Start VM" {
				Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost | Should BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
			}
		}

		Context "When Win10 VM Exists" {
			$VMRoot = "$TestDrive";
			$ie = "Edge";
			$os = "Windows 10";
			$vmName = "IE11 - Win10";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			Mock Test-VMHost { return $true; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };
			Mock Import-VMImage { return $true; };
			Mock Write-Output { };
			It "Must Start VM" {
				Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost | Should BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Import-VMImage -Times 0 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
			}
		}

		Context "When VM Does Not Exist but import fails" {
			$VMRoot = "$TestDrive";
			$ie = 6;
			$os = "XP";
			$vmName = "IE6 - WinXP";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			$script:zipCheck = 0;
			$script:ovaCheck = 0;

			$zip = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.zip");

			$ova = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.ova");
			$vmPath = (Join-Path -Path $VMRoot -ChildPath $vmName );
			Mock Test-VMHost { return $false; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };
			Mock Write-Output { };

			Mock Test-Path { return $true } -ParameterFilter { $Path -eq $vmPath };
			Mock Test-Path { 
				$script:zipCheck += 1; 
				return ( $script:zipCheck -gt 1 );
			} -ParameterFilter { $Path -eq $zip};
			Mock Test-Path { 
				$script:ovaCheck += 1; 
				return ( $script:ovaCheck -gt 2 );
				return $false;
			} -ParameterFilter { $Path -eq $ova};

			Mock Start-BitsTransfer { return; };
			Mock Test-MD5Hash { return $true; };
			Mock Import-VMImage { return $false; };
			Mock Remove-Item { return; };
			Mock Expand-7ZipArchive { return; };
			It "Must throw" {
				$error = $null;
				try {
					Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost | Should BeNullOrEmpty;
				} catch [Exception] {
					$error = $_;
				}
				$error | Should Not BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 0 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -ParameterFilter { $Path -eq $vmPath};
				Assert-MockCalled -CommandName Start-BitsTransfer -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 2 -Exactly -ParameterFilter { $Path -eq $zip};
				Assert-MockCalled -CommandName Test-Path -Times 3 -Exactly -ParameterFilter { $Path -eq $ova};
				Assert-MockCalled -CommandName Test-MD5Hash -Times 1 -Exactly;
				Assert-MockCalled -CommandName Import-VMImage -Times 1 -Exactly;
				Assert-MockCalled -CommandName Expand-7ZipArchive -Times 1 -Exactly;
				Assert-MockCalled -CommandName Remove-Item -Times 1 -Exactly;
			}
		}

		Context "When VM Does Not Exist" {
			$VMRoot = "$TestDrive";
			$ie = 6;
			$os = "XP";
			$vmName = "IE6 - WinXP";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			$script:zipCheck = 0;
			$script:ovaCheck = 0;

			$zip = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.zip");

			$ova = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.ova");
			$vmPath = (Join-Path -Path $VMRoot -ChildPath $vmName );
			Mock Test-VMHost { return $false; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };
			Mock Write-Output { };

			Mock Test-Path { return $true } -ParameterFilter { $Path -eq $vmPath };
			Mock Test-Path { 
				$script:zipCheck += 1; 
				return ( $script:zipCheck -gt 1 );
			} -ParameterFilter { $Path -eq $zip};
			Mock Test-Path { 
				$script:ovaCheck += 1; 
				return ( $script:ovaCheck -gt 2 );
				return $false;
			} -ParameterFilter { $Path -eq $ova};

			Mock Start-BitsTransfer { return; };
			Mock Test-MD5Hash { return $true; };
			Mock Import-VMImage { return $true; };
			Mock Remove-Item { return; };
			Mock Expand-7ZipArchive { return; };
			It "Must Prep VM and Must Start VM" {
				Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost | Should BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -ParameterFilter { $Path -eq $vmPath};
				Assert-MockCalled -CommandName Start-BitsTransfer -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 2 -Exactly -ParameterFilter { $Path -eq $zip};
				Assert-MockCalled -CommandName Test-Path -Times 3 -Exactly -ParameterFilter { $Path -eq $ova};
				Assert-MockCalled -CommandName Test-MD5Hash -Times 1 -Exactly;
				Assert-MockCalled -CommandName Import-VMImage -Times 1 -Exactly;
				Assert-MockCalled -CommandName Expand-7ZipArchive -Times 1 -Exactly;
				Assert-MockCalled -CommandName Remove-Item -Times 1 -Exactly;
			}
		}

		Context "When VM Does Not Exist and using standard location" {
			$VMRoot = "$TestDrive";
			$ie = "Edge";
			$os = "10";
			$vmName = "IE11 - Win10";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			$script:zipCheck = 0;
			$script:ovaCheck = 0;

			$zip = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.zip");

			$ova = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.ova");
			$vmPath = (Join-Path -Path $VMRoot -ChildPath $vmName );
			Mock New-Item {
				Microsoft.PowerShell.Management\New-Item -Path $Path -Force -ItemType $ItemType | Out-Null;
			}
			Mock Write-Output { };
			Mock Test-VMHost { return $false; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };
			Mock Test-Path { return $false } -ParameterFilter { $Path -eq $vmPath };
			Mock Start-BitsTransfer { 
				(Microsoft.PowerShell.Management\New-Item -Path (Split-Path -Path $zip -Parent) -Force -ItemType Directory) | Out-Null;
				Microsoft.PowerShell.Management\New-Item -Path $zip -Force -ItemType File | Out-Null;
			};
			Mock Test-MD5Hash { return $true; };
			Mock Import-VMImage { return $true; };
			Mock Remove-Item { return; };
			Mock Expand-7ZipArchive { 
				Microsoft.PowerShell.Management\New-Item -Path $ova -Force -ItemType File | Out-Null;

			};
			It "Must Prep VM and Must Start VM" {
				Get-IEVM -OS $os -IEVersion $ie -VMRootPath $altLocation -VMHost $vmHost | Should BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -ParameterFilter { $Path -eq $vmPath};
				Assert-MockCalled -CommandName Start-BitsTransfer -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-MD5Hash -Times 1 -Exactly;
				Assert-MockCalled -CommandName Expand-7ZipArchive -Times 1 -Exactly;
				Assert-MockCalled -CommandName Remove-Item -Times 1 -Exactly;
				Assert-MockCalled -CommandName Import-VMImage -Times 1 -Exactly;
				Assert-MockCalled -CommandName New-Item -Times 1 -Exactly;
			}
		}

		Context "When VM Does Not Exist and using standard location and md5 fails, but ignore hash" {
			$VMRoot = "$TestDrive";
			$ie = "Edge";
			$os = "10";
			$vmName = "IE11 - Win10";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			$script:zipCheck = 0;
			$script:ovaCheck = 0;

			$zip = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.zip");

			$ova = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.ova");
			$vmPath = (Join-Path -Path $VMRoot -ChildPath $vmName );
			Mock New-Item {
				Microsoft.PowerShell.Management\New-Item -Path $Path -Force -ItemType $ItemType | Out-Null;
			}
			Mock Write-Output { };
			Mock Test-VMHost { return $false; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };
			Mock Test-Path { return $false } -ParameterFilter { $Path -eq $vmPath };
			Mock Start-BitsTransfer { 
				(Microsoft.PowerShell.Management\New-Item -Path (Split-Path -Path $zip -Parent) -Force -ItemType Directory) | Out-Null;
				Microsoft.PowerShell.Management\New-Item -Path $zip -Force -ItemType File | Out-Null;
			};
			Mock Test-MD5Hash { return $false; };
			Mock Import-VMImage { return $true; };
			Mock Remove-Item { return; };
			Mock Expand-7ZipArchive { 
				Microsoft.PowerShell.Management\New-Item -Path $ova -Force -ItemType File | Out-Null;

			};
			It "Must Prep VM and Must Start VM" {
				Get-IEVM -OS $os -IEVersion $ie -VMRootPath $altLocation -VMHost $vmHost -IgnoreInvalidMD5 | Should BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -ParameterFilter { $Path -eq $vmPath};
				Assert-MockCalled -CommandName Start-BitsTransfer -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-MD5Hash -Times 0 -Exactly;
				Assert-MockCalled -CommandName Expand-7ZipArchive -Times 1 -Exactly;
				Assert-MockCalled -CommandName Remove-Item -Times 1 -Exactly;
				Assert-MockCalled -CommandName Import-VMImage -Times 1 -Exactly;
				Assert-MockCalled -CommandName New-Item -Times 1 -Exactly;
			}
		}

		Context "When VM Does Not Exist and using standard location and md5 fails" {
			$VMRoot = "$TestDrive";
			$ie = "Edge";
			$os = "10";
			$vmName = "IE11 - Win10";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			$script:zipCheck = 0;
			$script:ovaCheck = 0;

			$zip = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.zip");

			$ova = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.ova");
			$vmPath = (Join-Path -Path $VMRoot -ChildPath $vmName );
			Mock New-Item {
				Microsoft.PowerShell.Management\New-Item -Path $Path -Force -ItemType $ItemType | Out-Null;
			}
			Mock Write-Output { };
			Mock Test-VMHost { return $false; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };
			Mock Test-Path { return $false } -ParameterFilter { $Path -eq $vmPath };
			Mock Start-BitsTransfer { 
				(Microsoft.PowerShell.Management\New-Item -Path (Split-Path -Path $zip -Parent) -Force -ItemType Directory) | Out-Null;
				Microsoft.PowerShell.Management\New-Item -Path $zip -Force -ItemType File | Out-Null;
			};
			Mock Test-MD5Hash { return $false; };
			Mock Import-VMImage { return $true; };
			Mock Remove-Item { return; };
			Mock Expand-7ZipArchive { 
				Microsoft.PowerShell.Management\New-Item -Path $ova -Force -ItemType File | Out-Null;

			};
			It "Must Throw" {
				$error = $null;
				try {
					Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost | Should BeNullOrEmpty;
				} catch [Exception] {
					$error = $_;
				}
				Assert-MockCalled -CommandName Start-VMHost -Times 0 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -ParameterFilter { $Path -eq $vmPath};
				Assert-MockCalled -CommandName Start-BitsTransfer -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-MD5Hash -Times 1 -Exactly;
				Assert-MockCalled -CommandName Expand-7ZipArchive -Times 0 -Exactly;
				Assert-MockCalled -CommandName Remove-Item -Times 0 -Exactly;
				Assert-MockCalled -CommandName Import-VMImage -Times 0 -Exactly;
				Assert-MockCalled -CommandName New-Item -Times 1 -Exactly;
			}
		}

		Context "When import file does not exist after extract" {
			$VMRoot = "$TestDrive";
			$ie = "Edge";
			$os = "10";
			$vmName = "IE11 - Win10";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			$script:zipCheck = 0;
			$script:ovaCheck = 0;

			$zip = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.zip");

			$ova = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.ova");
			$vmPath = (Join-Path -Path $VMRoot -ChildPath $vmName );
			Mock New-Item {
				Microsoft.PowerShell.Management\New-Item -Path $Path -Force -ItemType $ItemType | Out-Null;
			}
			Mock Write-Output { };
			Mock Test-VMHost { return $false; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };
			Mock Test-Path { return $false } -ParameterFilter { $Path -eq $vmPath };
			Mock Start-BitsTransfer { 
				(Microsoft.PowerShell.Management\New-Item -Path (Split-Path -Path $zip -Parent) -Force -ItemType Directory) | Out-Null;
				Microsoft.PowerShell.Management\New-Item -Path $zip -Force -ItemType File | Out-Null;
			};
			Mock Test-MD5Hash { return $false; };
			Mock Import-VMImage { return $true; };
			Mock Remove-Item { return; };
			Mock Expand-7ZipArchive { 
				Microsoft.PowerShell.Management\New-Item -Path $ova -Force -ItemType File | Out-Null;

			};
			Mock Test-Path {
				return $false;
			} -ParameterFilter { $Path -eq $ova };
			It "Must throw" {
				$error = $null;
				try{
					Get-IEVM -OS $os -IEVersion $ie -VMRootPath $altLocation -VMHost $vmHost -IgnoreInvalidMD5 | Should BeNullOrEmpty;
				} catch [Exception] {
					$error = $_;
				}
				$error | Should Not BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 0 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -ParameterFilter { $Path -eq $vmPath};
				Assert-MockCalled -CommandName Start-BitsTransfer -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-MD5Hash -Times 0 -Exactly;
				Assert-MockCalled -CommandName Expand-7ZipArchive -Times 1 -Exactly;
				Assert-MockCalled -CommandName Remove-Item -Times 1 -Exactly;
				Assert-MockCalled -CommandName New-Item -Times 1 -Exactly;
				Assert-MockCalled -CommandName Import-VMImage -Times 0 -Exactly;
			}
		}

		Context "When Error Starting VM" {
			$VMRoot = "$TestDrive";
			$ie = 6;
			$os = "XP";
			$vmName = "IE6 - WinXP";
			$vmHost = "VirtualBox";
			$altLocation = "$TestDrive";

			$script:zipCheck = 0;
			$script:ovaCheck = 0;

			$zip = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.zip");

			$ova = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.ova");
			$vmPath = (Join-Path -Path $VMRoot -ChildPath $vmName );
			Mock Test-VMHost { return $false; };
			Mock Start-VMHost { return $false; };
			Mock Start-VBoxVM { return $true; };
			Mock Write-Output { };

			Mock Test-Path { return $true } -ParameterFilter { $Path -eq $vmPath };
			Mock Test-Path { 
				$script:zipCheck += 1; 
				return ( $script:zipCheck -gt 1 );
			} -ParameterFilter { $Path -eq $zip};
			Mock Test-Path { 
				$script:ovaCheck += 1; 
				return ( $script:ovaCheck -gt 2 );
				return $false;
			} -ParameterFilter { $Path -eq $ova};
			Mock Write-Output { };
			Mock Start-BitsTransfer { return; };
			Mock Test-MD5Hash { return $true; };
			Mock Import-VMImage { return $true; };
			Mock Remove-Item { return; };
			Mock Expand-7ZipArchive { return; };
			It "Must Throw" {
				$error = $null;
				try {
					Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost;
				} catch [Exception] {
					$error = $_;
				}
				$expectedError = "Error starting VM '$vmName' on host '$vmHost' at '$altLocation'";
				$error | Should Be $expectedError;
				Assert-MockCalled -CommandName Start-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -ParameterFilter { $Path -eq $vmPath};
				Assert-MockCalled -CommandName Start-BitsTransfer -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-Path -Times 2 -Exactly -ParameterFilter { $Path -eq $zip};
				Assert-MockCalled -CommandName Test-Path -Times 3 -Exactly -ParameterFilter { $Path -eq $ova};
				Assert-MockCalled -CommandName Test-MD5Hash -Times 1 -Exactly;
				Assert-MockCalled -CommandName Expand-7ZipArchive -Times 1 -Exactly;
				Assert-MockCalled -CommandName Remove-Item -Times 1 -Exactly;

			}
		}
	}

	Describe "Invoke-DownloadFile" {
		It "Should download file" {
			$url = "https://raw.githubusercontent.com/camalot/psievm/master/README.md";
			$file = Join-Path -Path $TestDrive -ChildPath "README.md";

			Invoke-DownloadFile -File $file -Url $url | Should BeNullOrEmpty;
			Test-Path -Path $file | Should Be $true;

		}
	}

	Describe "Invoke-ShellCommand" {
		Context "When calling 'dir'" {
			It "Should return the results of the directory" {
				$data = [string[]](Invoke-ShellCommand -Command "cmd" -CommandArgs "/c", "dir", $TestDrive);
				$data.Length | Should BeGreaterThan 2;
			}
		}
		Context "When calling 'mkdir'" {
			It "Should create the specified directory" {
				$TestPath = (Join-Path -Path $TestDrive -ChildPath "test");
				(Invoke-ShellCommand -Command "cmd" -CommandArgs "/c", "mkdir", $TestPath);
				Test-Path -Path $TestPath | Should Be $true;
			}
		}
		Context "When calling 'rmdir'" {
			It "Should delete the specified directory" {
				$TestPath = (Join-Path -Path $TestDrive -ChildPath "test");
				New-Item -Path $TestPath -ItemType Directory -Force | Out-Null;
				(Invoke-ShellCommand -Command "cmd" -CommandArgs "/c", "rmdir", $TestPath);
				Test-Path -Path $TestPath | Should Be $false;
			}
		}

		Context "When calling 'choco list'" {
			It "Should return installed packages" {
				$choco = Get-ChocolateyExe;
				$result = (Invoke-ShellCommand -Command $choco -CommandArgs "list", "--local-only", $TestPath);
				$result | Should BeGreaterThan 1;
			}
		}
	}

	Describe "Test-VBoxVM" {
		Context "When VM does not exist" {
			$vmName = "IE11 - Win10";
			Mock Get-VBoxManageExe {
				return Join-Path -Path $TestDrive -ChildPath "VBoxManage.exe";
			}
			Mock Invoke-ShellCommand {
				"$Command $CommandArgs" | Write-Output;
				return "Could not find a registered machine named '$vmName'";
			}
			It "Must return false" {
				Test-VBoxVM -VMName $vmName | Should Be $false;
			}
		}

		Context "When VM does exist" {
			$vmName = "IE11 - Win10";
			Mock Get-VBoxManageExe {
				return Join-Path -Path $TestDrive -ChildPath "VBoxManage.exe";
			}
			Mock Invoke-ShellCommand {
				"$Command $CommandArgs" | Write-Output;
				return "Not The Error Message";
			}
			It "Must return true" {
				Test-VBoxVM -VMName $vmName | Should Be $true;
			}
		}

		Context "When Invoke-ShellCommand errors" {
			$vmName = "IE11 - Win10";
			Mock Get-VBoxManageExe {
				return Join-Path -Path $TestDrive -ChildPath "VBoxManage.exe";
			}
			Mock Invoke-ShellCommand {
				throw "Error message";
			}
			It "Must return false" {
				Test-VBoxVM -VMName $vmName | Should Be $false;
			}
		}
	}
	
	Describe "Import-VBoxImage" {
		Context "When IE11/Win10 import is successful" {
			$vmName = "IE11 - Win10";
			$vmRoot = Join-Path -Path $TestDrive -ChildPath $vmName;
			$import = Join-Path -Path $vmRoot -ChildPath "$vmName.ova";

			Mock Get-VBoxManageExe {
				return Join-Path -Path $TestDrive -ChildPath "VBoxManage.exe";
			}
			Mock Invoke-ShellCommand {
				return "";
			}
			It "Must return true" {
				Import-VBoxImage -IEVersion "Edge" -OS "10" -VMName $vmName -VMRootPath $vmRoot -ImportFile $import -Shares "$vmRoot" | Should Be $true;
				Assert-MockCalled Get-VBoxManageExe -Times 1 -Exactly;
				Assert-MockCalled Invoke-ShellCommand -Times 3 -Exactly;
			}
		}

		Context "When IE8/Win7 import is successful" {
			$vmName = "IE8 - Win7";
			$vmRoot = Join-Path -Path $TestDrive -ChildPath $vmName;
			$import = Join-Path -Path $vmRoot -ChildPath "$vmName.ova";

			Mock Get-VBoxManageExe {
				return Join-Path -Path $TestDrive -ChildPath "VBoxManage.exe";
			}
			Mock Invoke-ShellCommand {
				return "";
			}
			It "Must return true" {
				Import-VBoxImage -IEVersion "8" -OS "7" -VMName $vmName -VMRootPath $vmRoot -ImportFile $import -Shares "$vmRoot" | Should Be $true;
				Assert-MockCalled Get-VBoxManageExe -Times 1 -Exactly;
				Assert-MockCalled Invoke-ShellCommand -Times 3 -Exactly;
			}
		}

		Context "When import is unsuccessful" {
			$vmName = "IE11 - Win10";
			$vmRoot = Join-Path -Path $TestDrive -ChildPath $vmName;
			$import = Join-Path -Path $vmRoot -ChildPath "$vmName.ova";

			Mock Get-VBoxManageExe {
				return Join-Path -Path $TestDrive -ChildPath "VBoxManage.exe";
			}
			Mock Invoke-ShellCommand {
				throw "some error";
			}
			It "Must return false" {
				Import-VBoxImage -IEVersion "Edge" -OS "10" -VMName $vmName -VMRootPath $vmRoot -ImportFile $import | Should Be $false;
				Assert-MockCalled Get-VBoxManageExe -Times 1 -Exactly;
				Assert-MockCalled Invoke-ShellCommand -Times 1 -Exactly;
			}
		}
	}

	Describe "Start-VBoxVM" {
		Context "When Start is successful" {
			$vmName = "IE11 - Win10";
			$vmRoot = Join-Path -Path $TestDrive -ChildPath $vmName;
			Mock Get-VBoxManageExe {
				return Join-Path -Path $TestDrive -ChildPath "VBoxManage.exe";
			}
			Mock Invoke-ShellCommand {
				return "";
			}
			It "Must return true" {
				Start-VBoxVM -VMName $vmName -VMRootPath $vmRoot | Should Be $true;
				Assert-MockCalled Get-VBoxManageExe -Times 1 -Exactly;
				Assert-MockCalled Invoke-ShellCommand -Times 1 -Exactly;
			}
		}

		Context "When Start is unsuccessful" {
			$vmName = "IE11 - Win10";
			$vmRoot = Join-Path -Path $TestDrive -ChildPath $vmName;
			Mock Get-VBoxManageExe {
				return Join-Path -Path $TestDrive -ChildPath "VBoxManage.exe";
			}
			Mock Invoke-ShellCommand {
				throw "some error";
			}
			It "Must return false" {
				Start-VBoxVM -VMName $vmName -VMRootPath $vmRoot | Should Be $false;
				Assert-MockCalled Get-VBoxManageExe -Times 1 -Exactly;
				Assert-MockCalled Invoke-ShellCommand -Times 1 -Exactly;
			}
		}
	}

	Describe "Wait-VBoxGuestControl" {

	}

	Describe "Invoke-RemoteVBoxCommand" {

	}
}