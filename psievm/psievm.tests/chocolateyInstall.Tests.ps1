if($PSCommandPath -eq $null) {
	Write-Host "Using MyInvoction.MyCommand.Path";
	$CommandRootPath = (Split-Path -Parent $MyInvocation.MyCommand.Path);
} else {
	Write-Host "Using PSCommandPath";
	$CommandRootPath = (Split-Path -Parent $PSCommandPath);
}
# This stops the initial invoking of Invoke-Setup;
$DoSetup = $false;
."$CommandRootPath\chocolateyInstall.ps1";

Describe "Get-DocumentsModulePath" {
	Context "When MyDocuments Exists" {
		Mock Get-EnvironmentFolderPath { 
			return Join-Path -Path "$TestDrive" -ChildPath "\documents\";
		} -ParameterFilter { $Name -eq "MyDocuments" };
		It "Must return MyDocuments Modules Path" {
			$expectedPath = "$TestDrive\documents\WindowsPowerShell\Modules\";
			Get-DocumentsModulePath | Should Be $expectedPath;
			Assert-MockCalled Get-EnvironmentFolderPath -Times 1 -Exactly;		
		}
	}

	Context "When MyDocuments does not exist" {
		Mock Get-EnvironmentFolderPath { 
			return $null;
		} -ParameterFilter { $Name -eq "MyDocuments" };
		Mock Join-Path { return Join-Path $TestDrive -ChildPath "\profile\$ChildPath"; } -ParameterFilter { $ChildPath -eq "Documents\WindowsPowerShell\Modules\" };
		It "Must return Documents Modules Path" {
			$expectedPath = Join-Path -Path $TestDrive -ChildPath "\profile\Documents\WindowsPowerShell\Modules\";
			Get-DocumentsModulePath | Should Be $expectedPath;
			Assert-MockCalled Get-EnvironmentFolderPath -Times 1 -Exactly;		
		}
	}
}

Describe "Install-PSIEVM" {
	Context "When Installing" {
		Mock Test-Path { return $true; };
		Mock Get-LatestGithubRelease { 
			return "https://github.com/camalot/psievm/releases/download/psievm-v0.1.44.28215/psievm.0.1.44.28215.zip";
		};
		Mock Join-Path { 
			return Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "psievm";
		} -ParameterFilter { $ChildPath -eq "psievm" };
		Mock Join-Path {
			return Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "\psievm\psievm.zip";
		} -ParameterFilter { $ChildPath -eq "psievm.zip" };
		Mock Join-Path { 
			return Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "7za.exe";
		} -ParameterFilter { $ChildPath -eq "7za.exe" };
		Mock Get-ChildItem { 
			return Microsoft.PowerShell.Management\Get-ChildItem -Path $TestDrive -File -Recurse; 
		};
		Mock Invoke-DownloadFile { };
		Mock Unblock-File { return; };
		Mock Start-Process { return; };
		Mock Remove-Item { return; };
		Mock New-Item { return; };
		Mock Write-Host { return; };
		It "Must Install From Github Release" {
			Install-PSIEVM -ModulesPath (Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "\WindowsPowerShell\Modules\") | Should BeNullOrEmpty;
			Assert-MockCalled Get-LatestGithubRelease -Times 1 -Exactly;	
			Assert-MockCalled Join-Path -Times 2 -Exactly -ParameterFilter { $ChildPath -eq "psievm" };	
			Assert-MockCalled Join-Path -Times 1 -Exactly -ParameterFilter { $ChildPath -eq "psievm.zip" };
			Assert-MockCalled New-Item -Times 0 -Exactly;
			Assert-MockCalled Invoke-DownloadFile -Times 2 -Exactly;
			Assert-MockCalled Start-Process -Times 1 -Exactly;
			Assert-MockCalled Remove-Item -Times 1 -Exactly;
			Assert-MockCalled Test-Path -Times 3 -Exactly;
		}
	}

	Context "When Installing and paths do not exist" {
		Mock Test-Path { return $false; };
		Mock Get-LatestGithubRelease { 
			return "https://github.com/camalot/psievm/releases/download/psievm-v0.1.44.28215/psievm.0.1.44.28215.zip";
		};
		Mock Join-Path { 
			return Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "psievm";
		} -ParameterFilter { $ChildPath -eq "psievm" };
		Mock Join-Path {
			return Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "\psievm\psievm.zip";
		} -ParameterFilter { $ChildPath -eq "psievm.zip" };
		Mock Join-Path { 
			return Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "7za.exe";
		} -ParameterFilter { $ChildPath -eq "7za.exe" };
		Mock Get-ChildItem { 
			return Microsoft.PowerShell.Management\Get-ChildItem -Path $TestDrive -File -Recurse; 
		};
		Mock Invoke-DownloadFile { };
		Mock Unblock-File { return; };
		Mock Start-Process { return; };
		Mock Remove-Item { return; };
		Mock New-Item { return; };
		Mock Write-Host { return; };
		It "Must Install From Github Release" {
			Install-PSIEVM -ModulesPath (Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "\WindowsPowerShell\Modules\") | Should BeNullOrEmpty;
			Assert-MockCalled Get-LatestGithubRelease -Times 1 -Exactly;	
			Assert-MockCalled Join-Path -Times 2 -Exactly -ParameterFilter { $ChildPath -eq "psievm" };	
			Assert-MockCalled Join-Path -Times 1 -Exactly -ParameterFilter { $ChildPath -eq "psievm.zip" };
			Assert-MockCalled New-Item -Times 2 -Exactly;
			Assert-MockCalled Invoke-DownloadFile -Times 2 -Exactly;
			Assert-MockCalled Start-Process -Times 1 -Exactly;
			Assert-MockCalled Remove-Item -Times 0 -Exactly;
			Assert-MockCalled Test-Path -Times 3 -Exactly;
		}
	}
}

Describe "Invoke-Setup" {
	Context "When not in the context of Chocolatey" {
		Mock Install-PSIEVM { return $null; };
		Mock ConvertFrom-StringData { return $null; };
		Mock Get-DocumentsModulePath { 
			return Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "\WindowsPowerShell\Modules\"; 
		};
		It "Should not do the chocolatey work" {
			Invoke-Setup | Should BeNullOrEmpty;
			Assert-MockCalled ConvertFrom-StringData -Times 1 -Exactly;
			Assert-MockCalled Install-PSIEVM -Times 1 -Exactly;
			Assert-MockCalled Get-DocumentsModulePath -Times 1 -Exactly;
		}
	}

	Context "When in the context of Chocolatey" {
		$env:chocolateyPackageFolder = (Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "\chocolatey\lib\psievm\")
		$target = (Microsoft.PowerShell.Management\Join-Path -Path $env:chocolateyPackageFolder -ChildPath "Modules");
		Mock Install-PSIEVM { return $null; };
		Mock ConvertFrom-StringData { return @{
			PSModuleDirectory = (Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "\WindowsPowerShell\Modules\");	
		}; };
		Mock Get-DocumentsModulePath { 
			throw "Should not call Get-DocumentsModulePath"; 
		};
		Mock Join-Path { 
			return (Microsoft.PowerShell.Management\Join-Path -Path $Path -ChildPath $ChildPath);
		}
		Mock Join-Path {
			return (Microsoft.PowerShell.Management\Join-Path -Path $Path -ChildPath $ChildPath);
		} -ParameterFilter { $Path -eq $env:chocolateyPackageFolder -and $Path -and $ChildPath -eq "psievm"; }
		Mock Join-Path {
			return (Microsoft.PowerShell.Management\Join-Path -Path $Path -ChildPath $ChildPath);
		} -ParameterFilter { $Path -eq $target -and $Path -and $ChildPath -eq "psievm"; };
		Mock Write-Host { return; };
		Mock Test-Path { return $true; };
		Mock Invoke-ShellCommand {}
		Mock Remove-Item { return; }
		It "Should do the chocolatey work" {
			Invoke-Setup | Should BeNullOrEmpty;
			Assert-MockCalled ConvertFrom-StringData -Times 1 -Exactly;
			Assert-MockCalled Install-PSIEVM -Times 1 -Exactly;
			Assert-MockCalled Get-DocumentsModulePath -Times 0 -Exactly;
			Assert-MockCalled Test-Path -Times 1 -Exactly;
			Assert-MockCalled Join-Path -Times 3 -Exactly;
			Assert-MockCalled Invoke-ShellCommand -Times 2 -Exactly;
			Assert-MockCalled Remove-Item -Times 1 -Exactly;
		}
	}
}

Describe "Invoke-ShellCommand" {
	Context "When command is to make new directory" {
		$target = Join-Path -Path "$TestDrive" -ChildPath "testPath";

		It "Must create the directory" {
			Invoke-ShellCommand -CommandArgs "mkdir", "`"$target`"";
			Test-Path -Path $target | Should Be $true;
		}
	}

	Context "When command is to delete a directory" {
		$target = Join-Path -Path "$TestDrive" -ChildPath "testPath";
		It "Must delete the directory" {
			Invoke-ShellCommand -CommandArgs "mkdir", "`"$target`"";
			# check that it was created
			Test-Path -Path $target | Should Be $true;
			Invoke-ShellCommand -CommandArgs "rmdir", "/S", "/Q", "`"$target`"";
			Test-Path -Path $target | Should Be $false;
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

Describe "Get-LatestGithubRelease" {
	$url = "https://raw.githubusercontent.com/camalot/psievm/master/README.md";
	Mock New-Object {
		$retval = [PSCustomObject]@{
			Headers = [PSCustomObject]@{};

		};
		Add-Member -InputObject $retval -MemberType ScriptMethod DownloadString {
				return "[{ 
				assets: [{
					browser_download_url: `"$url`"
				}]
				}]";
		};
		Add-Member -InputObject $retval.Headers -MemberType ScriptMethod Add {
			return;
		}
		return $retval;
	} -ParameterFilter {$TypeName -and ($TypeName -ilike 'net.webclient') }

	It "Should return a valid download url" {
		Get-LatestGithubRelease -Owner "camalot" -Repo "psievm" | Should Be $url;
	}
}

Describe "Get-EnvironmentFolderPath" {
	Context "When it exists" {
		It "Should return the path" {
			Get-EnvironmentFolderPath -Name "ApplicationData" | Should Not BeNullOrEmpty;
		}
	}
	Context "When it does not exist" {
		It "Should throw" {
			$error = $null;
			try {
				Get-EnvironmentFolderPath -Name "MadeUpName";
			} catch [Exception] {
				$error = $_;
			}

			$error | Should Not Be $null;
		}
	}
}