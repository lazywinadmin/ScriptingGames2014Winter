<#
# TO DO
-Should OS and SP being imported from the list of IP ?


#>

function Get-ComputerInformation {
<#
	.SYNOPSIS
		Get-ComputerInformation retrieve information such as Last  

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
	
		[Parameter()]
		[String]$SaveTo,
	
		[Parameter()]
		[String]$Protocol = 'WSMAN'
	)
	
	BEGIN {
		TRY {
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
				IF ($PSBoundParameters['HardwareInformation']) {
					
					}
				IF ($PSBoundParameters['LastPatchInstalled']) {
					
					}
				IF ($PSBoundParameters['LastReboot']) {
					
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

