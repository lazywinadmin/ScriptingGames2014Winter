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
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias("IPAddress","NetworkRange")] 
        [String]$IP,

        [Parameter(ParameterSetName='Non-CIDR')]
        [ValidateScript({
            IF ($_.contains("."))
            { #the mask is in the dotted decimal 255.255.255.0 format
                IF (! [bool]($_ -as [ipaddress]))
                {
					throw "Subnet Mask Validation Failed"
                }ELSE{
					return $true}#ELSE
            }#IF
            ELSE
            { #the mask is an integer value so must fall inside range [0,32]
               # use the validate range attribute to verify it falls under the range
                IF ([ValidateRange(0,32)][int]$subnetmask = $_ )
                { 	return $true
				}ELSE{
					throw "Invalid Mask Value"
				}#ELSE
            }#ELSE
            
             })]
        [string]$Mask,
		
		[Alias("ExportPath","Export","Directory")]
		[string]$Path=$(Get-ScriptDirectory),
	
		[Alias("RunAs")]
		[System.Management.Automation.Credential()]
		$Credential = [System.Management.Automation.PSCredential]::Empty,
	
		[Parameter()]
		[ValidateSet("WSMAN","DCOM")]
		[String]$Protocol,
	
		[Parameter(
			ParameterSetName="AllInformation")]
		[Switch]$AllInformation,
		
		[Parameter(
			ParameterSetName="Information")]
		[Switch]$HardwareInformation,
		
		[Parameter(
			ParameterSetName="Information")]
		[Switch]$LastPatchInstalled,
	
		[Parameter(
			ParameterSetName="Information")]
		[Switch]$LastReboot,
		
		[Parameter(
			ParameterSetName="Information")]
		[Switch]$ApplicationsInstalled,
	
		[Parameter(
			ParameterSetName="Information")]
		[Switch]$WindowsComponents,
	
		[Parameter(
			ParameterSetName="ReportCSV")]
		[Switch]$ReportCSV
	
		[Parameter(
			ParameterSetName="ReportHTML")]
		[Switch]$ReportHTML
	
		[Parameter(
			ParameterSetName="ReportPowerPoint")]
		[Switch]$ReportPowerPoint
	
		[Parameter(ParameterSetName="ReportHTML")]
		[Parameter(ParameterSetName="ReportPowerPoint")]
		[String]$Title = "Inventory Report"
	
		[Parameter(ParameterSetName="ReportHTML")]
		[Parameter(ParameterSetName="ReportPowerPoint")]
		[String]$SubTitle = "Team: POSH Monks\n Winter Scripting Games 2014 - Event:00 (Practice)"
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
			Write-Warning -Message "BEGIN Block - Error"
			
		}
	}
	PROCESS {
		TRY {
			[]
			
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


function Get-ScriptDirectory
{ 
	if($hostinvocation -ne $null)
	{
		Split-Path $hostinvocation.MyCommand.path
	}
	else
	{
		Split-Path $script:MyInvocation.MyCommand.Path
	}
}