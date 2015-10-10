$module = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.ps1", ".psm1");
$manifestPath = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.ps1", ".psd1");
$code = Get-Content $module | Out-String;
Invoke-Expression $code;


Describe -Tags "VersionChecks" "Manifest Version" {
	$script:manifest = $null;
	It "has a valid manifest" {
		{
			$script:manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop -WarningAction SilentlyContinue;
		} | Should Not Throw;
	}

	It "has a valid version in the manifest" {
		$script:manifest.Version -as [Version] | Should Not BeNullOrEmpty
	}

	It "has a valid GUID in the manifest" {
		$script:manifest.Guid | Should Be '1e452af5-f4d1-41c1-88f8-e2de734b9db6'
	}

	It "exports only Get-IEVM" {
		$script:manifest.ExportedFunctions.Values -join "|" | Should Be "Get-IEVM"
	}

	It "aliases only psievm" {
		$script:manifest.ExportedAliases.Values -join "|" | Should Be "psievm"
	}
}

Describe "Start-VMHost" {
	Context "When VMHost is not VirtualBox" {
		$vmHost = "VMWare";
		$vmName = "IE7 - Win7";
		It "must return false" {
			Start-VMHost -VMHost $vmHost -VMName $vmName;
		}
	}
	Context "When VMHost is VirtualBox" {
		$vmHost = "VMWare";
		$vmName = "IE7 - Win7";

		Mock Start-VBoxVM { return $true; }
		It "must return true" {
			Start-VMHost -VMHost $vmHost -VMName $vmName;
		}
	}
}

Describe "Test-VMHost" {
	Context "When VMHost is not VirtualBox" {
		$vmHost = "VMWare";
		$vmName = "IE7 - Win7";
		It "must return false" {
			Test-VMHost -VMHost $vmHost -VMName $vmName;
		}
	}
	Context "When VMHost is VirtualBox" {
		$vmHost = "VMWare";
		$vmName = "IE7 - Win7";

		Mock Test-VBoxVM { return $true; }
		It "must return true" {
			Test-VMHost -VMHost $vmHost -VMName $vmName;
		}
	}
}