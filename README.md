# psievm

*psievm* is a powershell module for standing up an IE VM quickly and without hassle.

Usage:

    PS > Import-Module "psievm"
    PS > Get-IEVM -OS XP -IEVersion 6  

## Parameters
    
| Name                	| Required 	|   Type   	|   Default  	|
|---------------------	|:--------:	|:--------:	|:----------:	|
| OS                  	|    YES   	| String   	| [Empty]    	|
| IEVersion           	|    YES   	| String   	| [Empty]    	|
| Shares              	|    NO    	| String[] 	| [Empty]    	|
| AlternateVMLocation 	|    NO    	| String   	| [Empty]    	|
| VMHost              	|    NO    	| String   	| VirtualBox 	|
| IgnoreInvalidMD5    	|    NO    	| Boolean  	| $False     	|

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