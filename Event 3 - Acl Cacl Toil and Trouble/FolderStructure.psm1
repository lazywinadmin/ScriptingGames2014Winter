Function New-FolderStructure
{
<#
Parameter: -Path
	Validate: Test-Path
	Validate: Path lenght
Parameter: -Name
	Validate Name does not contain forbidden caractere by window
	Validate a AD Group exist for this name
Parameter: -XMLConfiguration (specifies file that contains the permissions to apply)
	Validate: Test-Path
	Validate: Format
#>
	[CmdletBinding()]
	PARAM(
		$Path,
		$Name,
		$XMLConfiguration
	)#PARAM
	BEGIN
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block
	}#BEGIN Block
	PROCESS
	{
		TRY{}#TRY Block
		CATCH{
			Write-Warning -Message "[PROCESS] Something went wrong !"
			Write-Warning -Message $Error[0]	
		}#CATCH Block	
	}#PROCESS Block
	END
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block	
	}#END Block
}#Function New-FolderStructure

Function Get-FolderStructure
{
<#(Only useful if we use the OutPutXMLConfiguration parameter)
Generate a psobject
Parameter: -Path
Parameter: -OutputXMLConfiguration (generate xml config output of the ACL, this can be reused with Set-FolderStructurePermission)
	Validate: Test-Path
#>
	[CmdletBinding()]
	PARAM(
		$Path,
		$OutputXMLConfiguration
	)#PARAM
	BEGIN
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block
	}#BEGIN Block
	PROCESS
	{
		TRY{}#TRY Block
		CATCH{
			Write-Warning -Message "[PROCESS] Something went wrong !"
			Write-Warning -Message $Error[0]
		}#CATCH Block	
	}#PROCESS Block
	END
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block	
	}#END Block
}#Function Get-FolderStructure

Function Set-FolderStructurePermission
{
<#
Parameter: -XMLConfiguration (specifies file that contains the permissions to apply)
Validate: Test-Path
Validate: Format
Parameter: -Path
Parameter: -LogPath (must contains the date)
#>
	[CmdletBinding()]
	PARAM(
		$Path,
		$LogPath,
		$XMLConfiguration
	)#PARAM
	BEGIN
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block
	}#BEGIN Block
	PROCESS
	{
		TRY{}#TRY Block
		CATCH{
			Write-Warning -Message "[PROCESS] Something went wrong !"
			Write-Warning -Message $Error[0]	
		}#CATCH Block	
	}#PROCESS Block
	END
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block	
	}#END Block
	
}#Function Set-FolderStructurePermission

Function Get-FolderStructurePermission
{
<#(generate a psobject)
Parameter: -Path
Validate: Test-Path
Parameter: -OutputXMLConfiguration (generate xml config output of the ACL, this can be reused with Set-FolderStructurePermission)
Validate: Test-Path
#>
	[CmdletBinding()]
	PARAM(
		$Path,
		$OutputXMLConfiguration
	)#PARAM
	BEGIN
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block
	}#BEGIN Block
	PROCESS
	{
		TRY{}#TRY Block
		CATCH{
			Write-Warning -Message "[PROCESS] Something went wrong !"
			Write-Warning -Message $Error[0]	
		}#CATCH Block	
	}#PROCESS Block
	END
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block	
	}#END Block
	
}#Function Get-FolderStructurePermission

Function Compare-FolderStructurePermission
{
<#(Compare current and (Import of XML)
Parameter: -Path
Validate: Test-Path
	
Should be able to pass info to RESTORE-FolderStructurepermission
#>
	[CmdletBinding()]
	PARAM(
		[Parameter(Mandatory,ParameterSetName="PathsCompare")]
		[Parameter(Mandatory,ParameterSetName="XML")]
		$ReferencePath,
		[Parameter(Mandatory,ParameterSetName="PathsCompare")]
		$DifferencePath,
		[Parameter(Mandatory,ParameterSetName="XML")]
		$XMLConfiguration
	)#PARAM
	BEGIN
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block
	}#BEGIN Block
	PROCESS
	{
		TRY{}#TRY Block
		CATCH{
			Write-Warning -Message "[PROCESS] Something went wrong !"
			Write-Warning -Message $Error[0]	
		}#CATCH Block	
	}#PROCESS Block
	END
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block	
	}#END Block	
}#Function Compare-FolderStructurePermission

Function Report-FolderStructure
{
<#-HTML -CSV
Parameter: -Path
#>
	[CmdletBinding()]
	PARAM(
		$Path
	)#PARAM
	BEGIN
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block
	}#BEGIN Block
	PROCESS
	{
		TRY{}#TRY Block
		CATCH{
			Write-Warning -Message "[PROCESS] Something went wrong !"
			Write-Warning -Message $Error[0]	
		}#CATCH Block	
	}#PROCESS Block
	END
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block	
	}#END Block
}#Function Report-FolderStructure

Function Test-FolderStructurePermission
{
<#
Parameter: -Path
Parameter: -XMLConfiguration(file that contains the permissions to apply)
Validate: Test-Path
Validate: Format
#>
	[CmdletBinding()]
	PARAM(
		$Path,
		$XMLConfiguration
	)#PARAM
	BEGIN
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block
	}#BEGIN Block
	PROCESS
	{
		TRY{}#TRY Block
		CATCH{
			Write-Warning -Message "[PROCESS] Something went wrong !"
			Write-Warning -Message $Error[0]	
		}#CATCH Block	
	}#PROCESS Block
	END
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block	
	}#END Block
}#Function Test-FolderStructurePermission

Function Restore-FolderStructurePermission
{
<#
Parameter: -Path
Parameter: -XMLConfiguration(file that contains the permissions to apply)
Validate: Test-Path
Validate: Format
#>
	[CmdletBinding()]
	PARAM(
		$Path,
		$XMLConfiguration
	)#PARAM
	BEGIN
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block
	}#BEGIN Block
	PROCESS
	{
		TRY{}#TRY Block
		CATCH{
			Write-Warning -Message "[PROCESS] Something went wrong !"
			Write-Warning -Message $Error[0]	
		}#CATCH Block	
	}#PROCESS Block
	END
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block	
	}#END Block
}#Function Restore-FolderStructurePermission