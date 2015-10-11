$module = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.ps1", ".psm1");
$manifestPath = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.ps1", ".psd1");
$code = Get-Content $module | Out-String;
Invoke-Expression $code -Verbose;

#Import-Module "$module" -Force -Verbose;

Describe "Manifest Checks" {
	$script:manifest = $null;
	It "Has a valid manifest" {
		{
			$script:manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop -WarningAction SilentlyContinue;
		} | Should Not Throw;
	}

	It "Has a valid version in the manifest" {
		$script:manifest.Version -as [Version] | Should Not BeNullOrEmpty
	}

	It "Has a valid GUID in the manifest" {
		$script:manifest.Guid | Should Be '1e452af5-f4d1-41c1-88f8-e2de734b9db6'
	}

	It "Exports only Get-IEVM" {
		$script:manifest.ExportedFunctions.Values -join "|" | Should Be "Get-IEVM|Update-PSIEVM"
	}

	It "Aliases only psievm" {
		$script:manifest.ExportedAliases.Values -join "|" | Should Be "psievm"
	}
}

#InModuleScope $module {
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
			Mock Write-Host { return; } -ParameterFilter { $BackgroundColor -eq "Red" };
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
			Mock Write-Host { return; } -ParameterFilter { $BackgroundColor -eq "Red" };
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

	Describe "Test-MD5Hash" {
		Context "When VMHost is not VirtualBox and can Get-FileHash" {
			$vmHost = "VMWare";
			$vmName = "IE9 - Win7";
			$path = "c:\vms\IE9 - Win7\IE9 - Win7.vmw";

			Mock Get-Command {return @{};} -ParameterFilter { $Name -and $Name -eq "Get-FileHash"};
			Mock Get-FileHash { return @{ Hash = "61A2B69A5712ABD6566FCBD1F44F7A2B"; }; };
			Mock Get-FileMD5Hash { return "61A2B69A5712ABD6566FCBD1F44F7A2B"; };
			Mock Write-Warning { Microsoft.PowerShell.Utility\Write-Host $Object };
			Mock Write-Host { return; };
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
			$path = "c:\vms\IE9 - Win7\IE9 - Win7.vmw";

			Mock Get-Command {return $null; } -ParameterFilter { $Name -and $Name -eq "Get-FileHash"};
			Mock Get-FileHash { return @{ Hash = "61A2B69A5712ABD6566FCBD1F44F7A2B"; }; };
			Mock Get-FileMD5Hash { return "61A2B69A5712ABD6566FCBD1F44F7A2B"; };
			Mock Write-Warning { Microsoft.PowerShell.Utility\Write-Host $Object };
			Mock Write-Host { return; };
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
			$path = "c:\vms\IE9 - Win7\IE9 - Win7.vmw";

			Mock Get-Command {return $null;} -ParameterFilter { $Name -and $Name -eq "Get-FileHash"};
			Mock Get-FileHash { return @{ Hash = "61A2B69A5712ABD6566FCBD1F44F7A2B"; }; };
			Mock Get-FileMD5Hash { return "61A2B69A5712ABD6566FCBD1F44F7A2B"; };
			Mock Write-Warning { Microsoft.PowerShell.Utility\Write-Host $Object };
			Mock Write-Host { return; };
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
			$path = "c:\vms\IE9 - Win7\IE9 - Win7.vmw";

			Mock Get-Command {return @{};} -ParameterFilter { $Name -and $Name -eq "Get-FileHash"};
			Mock Get-FileHash { return @{ Hash = "61A2B69A5712ABD6566FCBD1F44F7A2B"; }; };
			Mock Get-FileMD5Hash { return "61A2B69A5712ABD6566FCBD1F44F7A2B"; };
			Mock Write-Warning { Microsoft.PowerShell.Utility\Write-Host $Object };
			Mock Write-Host { return; };
			It "must return true" {
				Test-MD5Hash -VMName $vmName -VMHost $vmHost -Path $path | Should Be $true;

				Assert-MockCalled Get-FileMD5Hash -Times 0 -Exactly;
				Assert-MockCalled Get-Command -Times 1 -Exactly;
				Assert-MockCalled Get-FileHash -Times 1 -Exactly;

			}
		}
	}

	Describe "Expand-7ipArchive" {
		Context "When Destination Does not exist and can Expand-Archive" {
			Mock Get-Command {return @{};} -ParameterFilter { $Name -eq "Expand-Archive" };
			Mock Expand-Archive { return; };
			Mock Invoke-DownloadFile { return; };
			Mock Join-Path { return Join-Path -Path (Split-Path -Parent $PSCommandPath) -ChildPath $ChildPath; } -ParameterFilter { $Path -and $Path -eq $PSScriptRoot };
			Mock Test-Path { return $false; };
			Mock Start-Process { "-FilePath: $FilePath -ArgumentList: $ArgumentList" | Write-Host; }
			Mock Get-ScriptRoot {return "c:\vms\modules\"; };
			It "Must Create Destination" {
				Expand-7ZipArchive -Path "c:\vms\IE9 - Win7.zip" -Destination "c:\vms\IE9 - Win7\";

				Assert-MockCalled Get-Command -Times 1 -Exactly;
				Assert-MockCalled Expand-Archive -Times 1 -Exactly;
				Assert-MockCalled Invoke-DownloadFile -Times 0 -Exactly;
				Assert-MockCalled Join-Path -Times 0 -Exactly;
				Assert-MockCalled Test-Path -Times 0 -Exactly;
				Assert-MockCalled Start-Process -Times 0 -Exactly;
				Assert-MockCalled Get-ScriptRoot -Times 0 -Exactly;
			}
		}

		Context "When Destination Does not exist and cannot Expand-Archive" {
			Mock Get-Command {return $null;} -ParameterFilter { $Name -eq "Expand-Archive" };
			Mock Expand-Archive { return; };
			Mock Invoke-DownloadFile { return; };
			Mock Join-Path { return "c:\vms\tools\"; } -ParameterFilter { $ChildPath -eq "tools" };
			Mock Join-Path { return "c:\vms\tools\7za.exe"; } -ParameterFilter { $ChildPath -eq "7za.exe" };
			Mock Test-Path { return $false; };
			Mock New-Item { };
			$script:resultCommand = "";
			Mock Start-Process { $script:resultCommand = "$FilePath $ArgumentList"; }
			Mock Get-ScriptRoot {return "c:\vms\modules\"; };
			It "Must Create Destination" {
				Expand-7ZipArchive -Path "c:\vms\IE9 - Win7.zip" -DestinationPath "c:\vms\IE9 - Win7\";

				$expectedCommand = "c:\vms\tools\7za.exe x -o`"c:\vms\IE9 - Win7\`" -y `"c:\vms\IE9 - Win7.zip`"";
			
				$script:resultCommand | Should BeExactly $expectedCommand;

				Assert-MockCalled Get-Command -Times 1 -Exactly;
				Assert-MockCalled Expand-Archive -Times 0 -Exactly;
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
		Context "When Invalid IE Version" {
			$VMRoot = "c:\vms\";
			$ie = 7;
			$os = "XP";
			$vmName = "IE7 - WinXP";
			$vmHost = "VirtualBox";
			$altLocation = "c:\vms\";

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

		Context "When VM Exists" {
			$VMRoot = "c:\vms\";
			$ie = 6;
			$os = "XP";
			$vmName = "IE6 - WinXP";
			$vmHost = "VirtualBox";
			$altLocation = "c:\vms\";

			Mock Test-VMHost { return $true; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };

			Mock Write-Host { };
			It "Must Start VM" {
				Get-IEVM -OS $os -IEVersion $ie -AlternateVMLocation $altLocation -VMRootPath $altLocation -VMHost $vmHost | Should BeNullOrEmpty;
				Assert-MockCalled -CommandName Start-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Test-VMHost -Times 1 -Exactly;
				Assert-MockCalled -CommandName Start-VBoxVM -Times 0 -Exactly;
			}
		}

		Context "When VM Does Not Exist" {
			$VMRoot = "c:\vms\";
			$ie = 6;
			$os = "XP";
			$vmName = "IE6 - WinXP";
			$vmHost = "VirtualBox";
			$altLocation = "c:\vms\";

			$script:zipCheck = 0;
			$script:ovaCheck = 0;

			$zip = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.zip");

			$ova = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.ova");
			$vmPath = (Join-Path -Path $VMRoot -ChildPath $vmName );
			Mock Test-VMHost { return $false; };
			Mock Start-VMHost { return $true; };
			Mock Start-VBoxVM { return $true; };
			Mock Write-Host { };

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
				Assert-MockCalled -CommandName Expand-7ZipArchive -Times 1 -Exactly;
				Assert-MockCalled -CommandName Remove-Item -Times 1 -Exactly;
			}
		}

		Context "When Error Starting VM" {
			$VMRoot = "c:\vms\";
			$ie = 6;
			$os = "XP";
			$vmName = "IE6 - WinXP";
			$vmHost = "VirtualBox";
			$altLocation = "c:\vms\";

			$script:zipCheck = 0;
			$script:ovaCheck = 0;

			$zip = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.zip");

			$ova = (Join-Path -Path (Join-Path -Path $VMRoot -ChildPath $vmName) -ChildPath "$vmName.ova");
			$vmPath = (Join-Path -Path $VMRoot -ChildPath $vmName );
			Mock Test-VMHost { return $false; };
			Mock Start-VMHost { return $false; };
			Mock Start-VBoxVM { return $true; };
			Mock Write-Host { };

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
			Mock Write-Host { };
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
	#}
}