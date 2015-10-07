# psievm [![Build status](https://ci.appveyor.com/api/projects/status/kxd0a7tvffjiqgm7?svg=true)](https://ci.appveyor.com/project/camalot/psievm)

*psievm* is a powershell module for standing up an IE VM quickly and without hassle. This will do all the steps needed to get the VM running. 

- Install the VM Host (if needed, and supported)
- Download the VM image
- Extract the image
- Import the image to VirtualBox
- Take the initial snapshot
- Start the VM Host with the VM

#### Installation

 From PowerShell console:

    PS:\> iex ((new-object net.webclient).DownloadString("https://raw.githubusercontent.com/camalot/psievm/master/psievmInstall.ps1"));

From command console:

    C:\> @powershell -NoProfile -ExecutionPolicy -ByPass -Command "iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/camalot/psievm/master/psievmInstall.ps1'))"

#### Usage

    PS > Import-Module psievm
    PS > Get-IEVM -OS XP -IEVersion 6  

## Parameters

| Name                	| Required 	|   Type   	|   Default  	|  Description  |
|---------------------	|:--------:	|:--------:	|:----------:	|-------------- |
| OS                  	|    YES   	| String   	| [Empty]    	| The Windows OS Version |
| IEVersion           	|    YES   	| String   	| [Empty]    	| The IE Version |
| Shares              	|    NO    	| String[] 	| [Empty]    	|  |
| AlternateVMLocation 	|    NO    	| String   	| [Empty]    	| The alternate location to use to find the VM images |
| VMHost              	|    NO    	| String   	| VirtualBox 	| The VM Host |
| IgnoreInvalidMD5    	|    NO    	| Switch  	| $False     	| If the script should ignore failed MD5 hash validation |
| VMRootPath            |    NO     | String    | $PWD        | The location to put the VM images |

### OS / IEVersion
This is the version of the OS that you want hosted and the version of IE you want with it. Here are the supported values:

|        	| IE 6 	| IE 7 	| IE 8 	| IE 9 	| IE 10 	| IE 11 	| MS Edge 	| Requires 64-bit Emulation |
|--------	|:----:	|:----:	|:----:	|:----:	|:-----:	|:-----:	|:-------:	|:------------------------: |
| XP     	|   X  	|      	| X    	|      	|       	|       	|         	|                           |
| Vista  	|      	| X    	|      	|      	|       	|       	|         	|                           |
| Win7   	|      	|      	| X    	| X    	| X     	| X     	|         	|                           |
| Win8   	|      	|      	|      	|      	| X     	|       	|         	|                           |
| Win8.1 	|      	|      	|      	|      	|       	| X     	|         	| X                         |
| Win10  	|      	|      	|      	|      	|       	|       	| X       	| X                         |


## Supported VM Hosts

- [VirtualBox][4] _[default]_
 - If not installed, [chocolatey][1] will be used to install [VirtualBox][2], and the [Guest Additions][3].
- [Vagrant][6] _[future support]_
 - If not installed, [chocolatey][1] will be used to install [Vagrant][5].
- [VMWare][7] _[future support]_
 - If not installed, [chocolatey][1] will be used to install [VMWare Player][8].
- HyperV _[future support]_
- VirtualPC _[future support]_

[1]: https://chocolatey.org
[2]: https://chocolatey.org/packages/virtualbox
[3]: https://chocolatey.org/packages/VBoxGuestAdditions.install
[4]: https://www.virtualbox.org/
[5]: https://chocolatey.org/packages/vagrant
[6]: https://www.vagrantup.com/
[7]: https://www.vmware.com/products/player
[8]: https://chocolatey.org/packages/vmwareplayer
[9]: https://www.powershellgallery.com/
[10]: http://go.microsoft.com/fwlink/?LinkID=624830&clcid=0x409
[11]: http://go.microsoft.com/fwlink/?LinkId=398175
