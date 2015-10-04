	Import-Module "psievm";

	Param (
		[ValidateSet("XP", "Vista", "7", "8", "8.1", "10")]
		[Parameter(Mandatory=$true, Position=0)]
		[string]$OS,
		[ValidateSet("6", "7", "8", "9", "10", "11", "Edge")]
		[Parameter(Mandatory=$true, Position=0)]
		[string]$IEVersion,
		[Parameter(Mandatory=$false, Position=2)]
		[string[]] $Shares
	);

	Get-IEVM -OS $OS -IEVersion $IEVersion -Shares $Shares;
