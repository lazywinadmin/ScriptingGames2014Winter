Function New-FolderStructure
{
<#
Parameter: -Path
	Validate: Test-Path
	Validate: Path lenght
Parameter: -Name
	Validate Name does not contain forbidden caractere by window
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx#naming_conventions
	Validate a AD Group exist for this name
Parameter: -XMLConfiguration (specifies file that contains the permissions to apply)
	Validate: Test-Path
	Validate: Format
#>
	[CmdletBinding()]
	PARAM(
		[Parameter(Mandatory)]
		[ValidateScript({Test-Path -Path $_})]
		$Path,
	
		[Parameter(Mandatory)]
		[ValidateScript({
			IF ($_ -match '@"^(?!^(PRN|AUX|CLOCK\$|NUL|CON|COM\d|LPT\d|\..*)(\..+)?$)[^\x00-\x1f\\?*:\"";|/]+$') {$True}
			ELSE {Throw "$_ is either not a valid name for a directory or it is not recommended. See this MSDN article for more information: http://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx#naming_conventions"}
		})]
		$Name,
	
		[Parameter(Mandatory)]
		[ValidateScript({Test-Path -Path $_})]
		$XMLConfiguration
	)#PARAM
	BEGIN
	{
		TRY{
			#Validate the XML, if not valid, ask the user to run Get-FolderStructure with XML. Or ask questions ?
			
			
			IF(-not(Test-Path -Path (Join-Path -Path $Path -ChildPath $Name)){
				Write-Verbose -Message "[BEGIN] Create the folder $Name"
				New-Item -Path $Path -ItemType "Directory" -Value $Name -Force
			}
			
			}#TRY Block
		CATCH{}#CATCH Block
	}#BEGIN Block
	PROCESS
	{
		TRY{
			#$Directories = Get-ChildItem $Source -Recurse -Directory
			$ImportXML = Import-Clixml -Path $XMLConfiguration
			$XMLSource = ($ImportXML |Select-Object -First 1).fullname
			$Destination = (Join-Path -Path $Path -ChildPath $Name)

			FOREACH ($Directory in $ImportXML)
			{
				$TargetDirectory = ($dir.Fullname -replace [regex]::Escape($XMLSource), $Destination)
				IF (-not(Test-Path -Path $TargetDirectory))
				{
					Write-Verbose -Message "Creation of $TargetDirectory"
					New-Item -itemtype "Directory" $TargetDirectory -force
				}#IF (-not(Test-Path -Path $TargetDirectory))
				
			}#FOREACH ($Directory in $ImportXML)
			
		}#TRY Block
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