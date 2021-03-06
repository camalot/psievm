function Invoke-DownloadFile {
	Param (
		[string]$url,
		[string]$file
	);
	process {
		"Downloading $url to $file" | Write-Host;
		$downloader = new-object System.Net.WebClient;
		$downloader.DownloadFile($url, $file);
	}
}

Export-ModuleMember -Function Invoke-DownloadFile;

function Expand-ZipArchive {
	Param (
		[string] $File,
		[string] $Destination
	);
	# download 7zip
	$7zaExe = "$env:APPVEYOR_BUILD_FOLDER\psievm\.tools\7za.exe";
	if(!(Test-Path -Path $7zaExe)) {
		throw "7za.exe not found";
	}

	# unzip the package
	"Extracting $file to $Destination" | Write-Host;
	Start-Process "$7zaExe" -ArgumentList "x -o`"$Destination`" -y `"$File`"" -Wait -NoNewWindow;
}

Export-ModuleMember -Function Expand-ZipArchive;

Function Send-PushBulletMessage {
	<#
.Synopsis
   Use this Function to use the pushbullet service to send push messages to your browser, computer or device 
.DESCRIPTION
   Use this Function as a stand-alone push service, or embed within your other functions to perform dynamic messaging as needed
    
.EXAMPLE
   Send-PushMessage -msg "Hello world" -title "Mandatory first message text" 
 
   #You will receive a push message on all of your configured devices with a "Hello World" message
    
.EXAMPLE
   get-winevent -LogName System | Select -first 1500 | ? Id -eq '1074' | % {Send-PushMessage -Title "Reboot detected on System" -msg ("Reboot detected on " + $_.MachineName + "@ " +  $_.TimeCreated) -Type Message}
 
 
   #In this more complex scenario, if an event of 1074 (System Reboot) is noted within the most recent 1500 events, send a message using PushBullet with information from the event.  
.NOTES
    If this function halts with a Warning message of "Please place your API Key within line 48 and try again", be certain to provide your API key on line 48.
#>

	[CmdletBinding(DefaultParameterSetName='Message')] 
	param(
		[Parameter(Mandatory=$false,ParameterSetName="File")]$FileName,
		[Parameter(Mandatory=$true, ParameterSetName="File")]$FileType,
		[Parameter(Mandatory=$true, ParameterSetName="File")]
		[Parameter(Mandatory=$true, ParameterSetName="Link")]$url,
         
		[Parameter(Mandatory=$false,ParameterSetName="Address")]$PlaceName,
		[Parameter(Mandatory=$true, ParameterSetName="Address")]$PlaceAddress,
 
		[Parameter(Mandatory=$false)]
		[ValidateSet("Address","Message", "File", "List","Link")]
		[Alias("Content")] 
		$Type,

		[Parameter(Mandatory=$true)]
		[string]$apiKey,
         
		[switch]$UploadFile,
		[string[]]$items,
		$title="PushBullet Message",
		$msg
	);
	begin {
    $api = $apiKey
    $PushURL = "https://api.pushbullet.com/v2/pushes";
    $devices = "https://api.pushbullet.com/v2/devices";
    $uploadRequestURL   = "https://api.pushbullet.com/v2/upload-request";
    $uploads = "https://s3.amazonaws.com/pushbullet-uploads";
 
    $cred = New-Object System.Management.Automation.PSCredential ($api,(ConvertTo-SecureString $api -AsPlainText -Force));
 
    if (($PlaceName) -or ($PlaceAddress)){
			$type = "address";
		}
  }
	process {
 
    switch($Type) {
			'Address'{
				Write-Verbose "Sending an Address";
				$body = @{
					type = "address"
					title = $Placename
					address = $PlaceAddress
				};
				break;
			};
			'Message'{
				Write-Verbose "Sending a message";
				$body = @{
					type = "note"
					title = $title
					body = $msg
				};
				break;
			};
			'List' {
				Write-Verbose "Sending a list";
				$body = @{
					type = "list"
					title = $title
					items = $items
				};
				break;
			};
			'Link' {
				Write-Verbose "Sending a link";
				$body = @{
					type = "link"
					title = $title
					body = $msg
					url = $url
				};
				break;
			};
			'File' {
				Write-Verbose "Sending a file";  
				if ($UploadFile) {  
					$UploadRequest = @{
						file_name = $FileName
						fileType  = $FileType
					};
					# Ref: Pushing files https://docs.pushbullet.com/v2/pushes/#pushing-files
					# "Once the file has been uploaded, set the file_name, file_url, and file_type returned in the response to the upload request as the parameters for a new push with type=file."
					#Create Upload request first
					$attempt = Invoke-WebRequest -Uri $uploadRequestURL -Credential $cred -Method Post -Body $UploadRequest -ErrorAction SilentlyContinue;
					if ($attempt.StatusCode -eq "200") {
						Write-Verbose "Upload Request OK";
					} else {
						Write-Warning "error encountered, check `$Uploadattempt for more info";
						$global:Uploadattempt = $attempt;
					}
 
					#Have to include the data field from the full response in order to begin an upload
					$UploadApproval = $attempt.Content | ConvertFrom-Json | select -ExpandProperty data ;
					#Have to append the file data to the Upload request        
					$UploadApproval | Add-Member -Name "file" -MemberType NoteProperty -Value ([System.IO.File]::ReadAllBytes((get-item C:\TEMP\upload.txt).FullName));
 
					#Upload the file and get back the url
					#$UploadAttempt = 
					#Invoke-WebRequest -Uri $uploads -Credential $cred -Method Post -Body $UploadApproval -ErrorAction SilentlyContinue
					#Doesn't work...maybe invoke-restMethod is the way to go?
					Invoke-WebRequest -Uri $uploads -Method Post -Body $UploadApproval -ErrorAction SilentlyContinue;
				} else {
					# If we don't need to upload the file
					$body = @{
						type = "file"
						file_name = $fileName
						file_type = $filetype
						file_url = $url
						body = $msg
					};       
				};
				$global:UploadApproval = $UploadApproval;
				break;
			};
		}
 
		Write-Debug "Test-value of `$body before it gets passed to Invoke-WebRequest";
		$Sendattempt = Invoke-WebRequest -Uri $PushURL -Credential $cred -Method Post -Body $body -ErrorAction SilentlyContinue;
 
		if ($Sendattempt.StatusCode -eq "200"){
			Write-Verbose "OK";
		} else {
			Write-Warning "error encountered, check `$attempt for more info";
			$global:Sendattempt = $Sendattempt;  
		}
	}
 
	end {
		$global:Sendattempt = $Sendattempt;
	}

}

Export-ModuleMember -Function Send-PushBulletMessage;

function Set-BuildVersion {
	process {
		Write-Host "Setting up build version";
		$dt = (Get-Date).ToUniversalTime();
		$doy = $dt.DayOfYear.ToString();
		$yy = $dt.ToString("yy");
		$revision = "$doy$yy";
		$version = "$env:APPVEYOR_BUILD_VERSION.$revision";
		$split = $version.split(".");
		$m1 = $split[0];
		$m2 = $split[1];
		$b = $env:APPVEYOR_BUILD_NUMBER;
		$r = $split[3];		
		
		Set-AppveyorBuildVariable -Name CI_BUILD_MAJOR -Value $m1;
		Set-AppveyorBuildVariable -Name CI_BUILD_MINOR -Value $m2;

		Set-AppveyorBuildVariable -Name CI_BUILD_NUMBER -Value $b;
		Set-AppveyorBuildVariable -Name CI_BUILD_REVISION -Value $r;
		Set-AppveyorBuildVariable -Name CI_BUILD_VERSION -Value "$m1.$m2.$b.$r";

		Write-Host "Set the CI_BUILD_VERSION to $env:CI_BUILD_VERSION";
	}
}

Export-ModuleMember -Function Set-BuildVersion;

function Invoke-FtpUpload {
	param (
		[string] $Server,
		[string] $Username,
		[string] $Password,
		[string] $Path,
		[string[]] $Files

	);
	$ldir = $pwd;
	$fscript = "";
	($Files | foreach {
		$ppath = (Split-Path -Path $_ -Parent); 
		$lfile = (Split-Path -Path $_ -Leaf); 
		$fscript += "lcd `"$ppath`"`n"; 
		$fscript += "put `"$lfile`"`n"; 
	});
$script = "open $Server
user $Username $Password
binary  
status
verbose
mkdir $Path
cd $Path     
$($fscript)bye`n`n";

	$script | ftp -i -in; 
	Set-Location -Path $ldir | Out-Null;
}

Export-ModuleMember -Function Invoke-FtpUpload;

