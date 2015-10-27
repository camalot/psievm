if($PSCommandPath -eq $null) {
	Write-Host "Using MyInvoction.MyCommand.Path";
	$CommandRootPath = (Split-Path -Parent $MyInvocation.MyCommand.Path);
} else {
	Write-Host "Using PSCommandPath";
	$CommandRootPath = (Split-Path -Parent $PSCommandPath);
}
# This stops the initial invoking of Invoke-Uninstall;
$DoUninstall = $false;

."$CommandRootPath\chocolateyUninstall.ps1";

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

Describe "Invoke-Uninstall" {
	Context "When in the context of chocolatey" {

		$env:chocolateyPackageFolder = (Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "\chocolatey\lib\psievm\")
		$target = (Microsoft.PowerShell.Management\Join-Path -Path $env:chocolateyPackageFolder -ChildPath "Modules");
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
		} -ParameterFilter { $Path -eq $target -and $Path -and $ChildPath -eq "psievm"; };
		Mock Write-Host { return; };
		Mock Test-Path { return $true; };
		Mock Invoke-ShellCommand {}
		Mock Remove-Item { return; }

		It "Must execute successfully" {
			Invoke-Uninstall | Should BeNullOrEmpty;
			Assert-MockCalled ConvertFrom-StringData -Times 1 -Exactly;
			Assert-MockCalled Get-DocumentsModulePath -Times 0 -Exactly;
			Assert-MockCalled Invoke-ShellCommand -Times 1 -Exactly;
			Assert-MockCalled Remove-Item -Times 1 -Exactly;
			Assert-MockCalled Test-Path -Times 2 -Exactly;
			Assert-MockCalled Join-Path -Times 2 -Exactly;
		}

	}

	Context "When PSModuleDirectory not specified" {
		
		$env:chocolateyPackageFolder = (Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "\chocolatey\lib\psievm\")
		$target = (Microsoft.PowerShell.Management\Join-Path -Path $env:chocolateyPackageFolder -ChildPath "Modules");
		Mock ConvertFrom-StringData { return $null };
		Mock Get-DocumentsModulePath { 
			return (Microsoft.PowerShell.Management\Join-Path -Path $TestDrive -ChildPath "\WindowsPowerShell\Modules\"); 
		};
		Mock Join-Path { 
			return (Microsoft.PowerShell.Management\Join-Path -Path $Path -ChildPath $ChildPath);
		}
		Mock Join-Path {
			return (Microsoft.PowerShell.Management\Join-Path -Path $Path -ChildPath $ChildPath);
		} -ParameterFilter { $Path -eq $target -and $Path -and $ChildPath -eq "psievm"; };
		Mock Write-Host { return; };
		Mock Test-Path { return $true; };
		Mock Invoke-ShellCommand {}
		Mock Remove-Item { return; }

		It "Must execute successfully" {
			Invoke-Uninstall | Should BeNullOrEmpty;
			Assert-MockCalled ConvertFrom-StringData -Times 1 -Exactly;
			Assert-MockCalled Get-DocumentsModulePath -Times 1 -Exactly;
			Assert-MockCalled Invoke-ShellCommand -Times 1 -Exactly;
			Assert-MockCalled Remove-Item -Times 1 -Exactly;
			Assert-MockCalled Test-Path -Times 2 -Exactly;
			Assert-MockCalled Join-Path -Times 2 -Exactly;
		}
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

