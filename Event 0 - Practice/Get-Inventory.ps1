function Get-Inventory {
	<#
	.SYNOPSIS
		Get-Inventory function can Scan a subnet, Gather information on available computer(s) and Export the information into HTML/CSV or PPTX file

	.DESCRIPTION
		Get-Inventory function can Scan a subnet, Gather information on available computer(s) and Export the information into HTML/CSV or PPTX file

	.PARAMETER  IP
		

	.PARAMETER  MASK
	
	.PARAMETER  Path

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
		$IP,
		$Mask,
		$Path,
	
		[Alias("RunAs")]
		[System.Management.Automation.Credential()]
		$Credential = [System.Management.Automation.PSCredential]::Empty,
	
		[Parameter()]
		[ValidateSet("WSMAN","DCOM")]
		[String]$Protocol,
		
		[Switch]$HardwareInformation,
		
		[Switch]$LastPatchInstalled,
	
		[Switch]$LastReboot,
	
		[Switch]$ApplicationsInstalled,
	
		[Switch]$WindowsComponents,
	
		[Parameter(ParameterSetName="Reporting")]
		[Switch]$Report,
	
		[Parameter(ParameterSetName="Reporting",Mandatory,HelpMessage="Please specify the type of report."))]
		[Validateset("CSV","HTML","PowerPoint")]
		$ReportType
	)
	
	BEGIN {
		TRY {
			# DOT SOURCING
			# Scan Scanning
			. .\Get-IPAddressInRange.ps1
			
			# Gather Information
			. .\Get-ComputerInventory.ps1
			
			# Export/Reporting
			. .\New-Export.ps1
		}
		CATCH {
			
		}
	}
	PROCESS {
		TRY {
			
		}
		CATCH {
		}
	}
	END {
		TRY {
		}
		CATCH {
		}
	}
}