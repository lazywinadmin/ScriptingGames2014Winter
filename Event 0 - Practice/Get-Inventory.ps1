<#
	.SYNOPSIS
		A brief description of the Get-Something function.

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
function Get-Inventory {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[System.String]
		$ParameterA,
		[Parameter(Position=1)]
		[System.Int32]
		$ParameterB
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			
		}
		catch {
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
Export-ModuleMember -Function Get-Something

# Optional commands to create a public alias for the function
New-Alias -Name gs -Value Get-Something
Export-ModuleMember -Alias gs