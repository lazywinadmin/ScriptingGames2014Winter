<#
# TO DO
-Should OS and SP being imported from the list of IP ?
-What if multiple diskdrive
-Should i get the OS and SP info
-LastReboot information : is the property LastBootUpTime good enough ?
-order the final $info
-Validate Parameter

-Some change
#>


function Get-ComputerInformation {
<#
	.SYNOPSIS
		Get-ComputerInformation

	.DESCRIPTION
		A detailed description of the Get-Something function.

	.PARAMETER  ParameterA
		The description of a the ParameterA parameter.

	.PARAMETER  ParameterB
		The description of a the ParameterB parameter.

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
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.

	.LINK
		about_modules

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

	.LINK
		about_functions_advanced_parameters

	.LINK
		about_functions_advanced_methods
#>

	[CmdletBinding()]
	PARAM(
		[Parameter(Position=0, Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
		[String[]]$ComputerName,
		
		[Parameter()]
		[Switch]$HardwareInformation,
		
		[Parameter()]
		[Switch]$LastPatchInstalled,
	
		[Parameter()]
		[Switch]$LastReboot,
	
		[Parameter()]
		[Switch]$ApplicationInstalled,
	
		[Parameter()]
		[Switch]$WindowsComponents,
	
		[Alias("RunAs")]
		[System.Management.Automation.Credential()]
		$Credential = [System.Management.Automation.PSCredential]::Empty,
	
		[Alias("Path")]
		[ValidateScript({Test-Path -path $_})]
		[String]$SaveTo,
	
		[Parameter(Mandatory)]
		[ValidateSet("WSMAN","DCOM")]
		[String]$Protocol = 'WSMAN'
	)
	
	BEGIN {
		TRY {
			IF(-not(Get-Module -Name CimCmdlets -ErrorAction Stop | Out-Null){Import-Module -Name CimCmdlets}
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
				}
			
			TRY {
				$RunningNicely = $true
				
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
				
				IF ($PSBoundParameters['LastPatchInstalled']) {
					
					# Get the information from win32_quickfixengineering
					$LastPatchesInstalled = get-ciminstance -CimSession $CimSession -ClassName win32_quickfixengineering -Property Installedon
					
					# Send the information to the array
					$Info.LastPatchInstalled = ($LastPatchesInstalled | Sort-Object -Property InstalledOn -Descending | Select-Object -first 1).HotFixID
					}
				
				IF ($PSBoundParameters['LastReboot']) {
					# Get the information from Win32_OperatingSystem
					$LastReboot = get-ciminstance -CimSession $CimSession -ClassName win32_operatingsystem -Property LastBootUpTime
					
					# Send the information to the array
					$Info.LastReboot = $LastReboot.LastBootUpTime
				}
				
				IF ($PSBoundParameters['ApplicationInstalled']) {
					# Get the information from Win32_OperatingSystem
					$Services = get-ciminstance -CimSession $CimSession -ClassName win32_service -Property Name,State,Status
					
					# Send the information to the array
					$Info.SQLInstalled = 
				}
				
				IF ($PSBoundParameters['WindowsComponents']) {
					
				}
				
			}#TRY Block
			CATCH {
				$RunningNicely = $false
				IF ($ProcessErrorCIM){Write-Warning -Message "$Computer - Can't Connect - $protocol"}
				
			}#CATCH Block
			
			IF ($RunningNicely){
				$Info = [ordered]@{
					ComputerName = $Computer
				}#$Info
				
			}#IF ($RunningNicely)
			
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

