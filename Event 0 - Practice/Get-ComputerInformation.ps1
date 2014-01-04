<#
# TO DO
-Should OS and SP being imported from the list of IP ?
-What if multiple diskdrive
-Should i get the OS and SP info
-LastReboot information : is the property LastBootUpTime good enough ?
-order the final $info
-Validate Parameter
-Files: Validate Naming Convention accepted by Windows ([A-Z]|[a-z]|[0-9]|_|-|\.|\s)+
-Some change
-if WSMAN fail, fall back on DCOM
-LogPath parameter ?

#>


function Get-ComputerInformation {
<#
	.SYNOPSIS
		Get-ComputerInformation function retrieve inventory information from one or multiple computers.

	.DESCRIPTION
		Get-ComputerInformation function retrieve inventory information from one or multiple computers.

	.PARAMETER  ComputerName
		Specifies Defines the ComputerName

	.PARAMETER  Path
		Specifies different credential to use
	
	.PARAMETER  Protocol
		Specifies the protocol to use to establish the connection with the remote computer(s)
		Default: WSMAN
	
	.PARAMETER  HardwareInformation
		Specifies different credential to use
	
	.PARAMETER  LastPatchInstalled
		Specifies different credential to use
	
	.PARAMETER  LastReboot
		Specifies different credential to use
	
	.PARAMETER  ApplicationInstalled
		Specifies different credential to use
	
	.PARAMETER  WindowsComponents
		Specifies different credential to use

	.EXAMPLE
		PS C:\> Get-Something -ParameterA 'One value' -ParameterB 32
		'This is the output'
		This example shows how to call the Get-Something function with named parameters.

	.EXAMPLE
		PS C:\> Get-Something 'One value' 32
		'This is the output'
		This example shows how to call the Get-Something function with positional parameters.

	.INPUTS
		System.String,System.Int32

	.OUTPUTS
		System.String

	.NOTES
		Winter Scripting Games 2014
		Event 0 - Practice Event
		Title: Server Inventory
		
		This function will ...
#>

	[CmdletBinding()]
	PARAM(
		[Parameter(
			Position=0,
			ValueFromPipeline,
			ValueFromPipelineByPropertyName,
			Mandatory,
			HelpMessage="Specify one or more ComputerName(s) (Netbios name, FQDN, or IP Address)")]
		[String[]]$ComputerName,
	
		[Alias("RunAs")]
		[System.Management.Automation.Credential()]
		$Credential = [System.Management.Automation.PSCredential]::Empty,
	
		[Alias("Destination","DestinationPath")]
		[ValidateScript(
			# Validate the Path specified by the user
			{Test-Path -path $_})]
		[String]$Path,
	
		[Parameter(
			Mandatory,
			HelpMessage="Specify the protocol to use")]
		[ValidateSet("WSMAN","DCOM")]
		[String]$Protocol = 'WSMAN',
		
		[Switch]$HardwareInformation,
		
		[Switch]$LastPatchInstalled,
	
		[Switch]$LastReboot,
	
		[Switch]$ApplicationInstalled,
	
		[Switch]$WindowsComponents,
	)
	
	BEGIN {
		TRY {
			
			# Verify CimCmdlets is loaded (CIM is loaded by default)
			#IF(-not(Get-Module -Name CimCmdlets -ErrorAction Stop | Out-Null){Import-Module -Name CimCmdlets}
			
		}#TRY
		CATCH {
		}#CATCH Block
	}#BEGIN Block
	
	PROCESS {
		FOREACH ($Computer in $ComputerName){
			
			# Define Splatting
			$CIMSessionParams = @{
				ComputerName 	= $Computer
				ErrorAction 	= 'Stop'
				ErrorVariable	= 'ProcessErrorCIM'
			}#$CIMSessionParams
			
			TRY {
				# Connectivity Test
                Write-Verbose -Message "$Computer - Testing Connection..."
                Test-Connection -ComputerName $Computer -count 1 -Quiet -ErrorAction Stop | Out-Null
				
				# Credential
				IF ($PSBoundParameters['Credential']) {$CIMSessionParams.credential = $Credential}
				
				# Protocol
				Switch ($Protocol) {
					'DCOM' {
						# Trying with DCOM protocol
                		Write-Verbose -Message "$Computer - Trying to connect via DCOM protocol"
                		$CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
                		$CimSession = New-CimSession @CIMSessionParams
                		$CimProtocol = $CimSession.protocol
                		Write-Verbose -message "$Computer - [$CimProtocol] CIM SESSION - Opened"
					}# 'DCOM'
					'WSMAN' {
						# Trying with WsMan protocol
						Write-Verbose -Message "$Computer - Trying to connect via WSMAN protocol"
						IF ((Test-WSMan -ComputerName $Computer -ErrorAction SilentlyContinue).productversion -match 'Stack: 3.0'){
							Write-Verbose -Message "$Computer - WSMAN is responsive"
                			$CimSession = New-CimSession @CIMSessionParams
                			$CimProtocol = $CimSession.protocol
                			Write-Verbose -message "$Computer - [$CimProtocol] CIM SESSION - Opened"
						}#IF
					}# 'WSMAN'
				}#Switch ($Protocol)
				
				# Data
				
				$Info = @{
					ComputerName = $Computer
				}#$Info
				
				IF ($PSBoundParameters['HardwareInformation']) {
					# Get the information from Win32_ComputerSystem
					$ComputerSystem = Get-CimInstance -CimSession $CimSession -ClassName win32_ComputerSystem -Property Manufacturer,Model,TotalPhysicalMemory,NumberOfProcessors
					
					# Get the information from Win32_diskdrive
					$DiskDrive = Get-CimInstance -CimSession $CimSession -ClassName win32_diskdrive -Property Size
					
					# Send the Info to the array
					$Info.Manufacturer = $ComputerSystem.Manufacturer
					$Info.Model = $ComputerSystem.Model
					$Info.MemoryGB = $ComputerSystem.TotalPhysicalMemory/1GB
					$Info.NumberOfProcessors = $ComputerName.NumberOfProcessors
					$Info.DiskSize = $DiskDrive.Size/1GB
					
					}
				
				# Switch LastPatchInstalled
				IF ($LastPatchInstalled) {
					
					# Get the information from win32_quickfixengineering
					$LastPatchesInstalled = get-ciminstance -CimSession $CimSession -ClassName win32_quickfixengineering -Property Installedon
					
					# Send the information to the array
					$Info.LastPatchInstalled = ($LastPatchesInstalled | Sort-Object -Property InstalledOn -Descending | Select-Object -first 1).HotFixID
					}
				
				# Switch LastReboot
				IF ($LastReboot) {
					# Get the information from Win32_OperatingSystem
					$LastReboot = get-ciminstance -CimSession $CimSession -ClassName win32_operatingsystem -Property LastBootUpTime
					
					# Send the information to the array
					$Info.LastReboot = $LastReboot.LastBootUpTime
				}
				
				# Switch ApplicationInstalled
				IF ($ApplicationInstalled) {
					# Get the information from Win32_OperatingSystem
					$Services = get-ciminstance -CimSession $CimSession -ClassName win32_service -Property Name,State,Status
					
					# Send the information to the array
					$Info.SQLInstalled = 
				}
				
				# Switch WindowsComponents
				IF ($WindowsComponents) {
					
				}
				
			}#TRY Block
			CATCH {
				IF ($ProcessErrorCIM){Write-Warning -Message "$Computer - Can't Connect - $protocol"}
				
			}#CATCH Block
		}#FOREACH Block
	}#PROCESS Block
	
	END {
		TRY {
		}#TRY Block
		CATCH {
		}#CATCH Block
	}#END Block
}#Function Get-ComputerInformation



#Export-ModuleMember -Function Get-Something

# Optional commands to create a public alias for the function
#New-Alias -Name gs -Value Get-Something
#Export-ModuleMember -Alias gs

