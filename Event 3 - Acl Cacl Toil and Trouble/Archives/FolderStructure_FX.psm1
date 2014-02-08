#requires -version 3.0

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
			
			
			IF(-not(Test-Path -Path (Join-Path -Path $Path -ChildPath $Name))) {
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
		[ValidateScript({Test-Path -Path $_})]
		[string]$Path,
		[switch]$OutputXMLConfiguration
	)#PARAM
	BEGIN
	{
		TRY{Write-Verbose -Message "[BEGIN] Starting function Get-FolderStructure"}#TRY Block
		CATCH{}#CATCH Block
	}#BEGIN Block
	PROCESS
	{
		TRY{
			Write-Verbose -Message "[PROCESS] Path: $Path"
			IF((Get-ChildItem -Path $Path -Directory) -eq $null){Write-Verbose -Message "[PROCESS] No directories in this path"}
			ELSE{
				IF($PSBoundParameters['OutputXMLConfiguration'])
				{
					Write-Verbose -Message "[PROCESS] Exporting Directories from $Path"
					
					# Get the name of the parent
					$ParentName = (Get-ChildItem -Path $Path -Directory | Select-Object -First 1).Parent.Name
					
					# Get the directories
					Get-ChildItem -Path $Path -Directory -Recurse | Export-Clixml -Path (Join-Path -Path $Path -ChildPath "$ParentName-$(Get-Date -format 'yyyyMMdd_hhmmss').xml")
					
				}
				ELSE{Get-ChildItem -Path $Path -Directory -Recurse}
			}

		}#TRY Block
		CATCH{
			Write-Warning -Message "[PROCESS] Something went wrong !"
			$Error[0]
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
		TRY{
			
			#http://www.be-init.nl/blog/7531/set-acl-through-powershell
			# Get ACL info on a folder
			$NewAcl = Get-ACL D:\Software
			#Now that we have a point of reference and saved it to a variable, we can use this information when setting the ACL on whatever target (and all it’s sub files and folders by using the –recurse parameter) we specify with the following command:
			Get-ChildItem D:\Pictures -recurse | Set-ACL –ACLObject $NewACL

			#But what if you only want to set the ACL for specific files, for example all files with the .pptx extension?
			Get-ChildItem D:\Pictures –recurse –include *.pptx –force | Set-ACL –ACLObject $NewACL
			
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

Function Get-FolderStructureReport
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
		[Parameter(Mandadory)]
		[ValidateScript({Test-Path -Path $_})]
		$Path,
	
		[Parameter(Mandadory)]
		[ValidateScript({Test-Path -Path "$_.xml"})]
		$XMLConfiguration
	)#PARAM
	BEGIN
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block
	}#BEGIN Block
	PROCESS
	{
		TRY{
			$Folders = Get-ChildItem -Directory -Path $Path -Recurse
			$XML = Import-Clixml -Path $XMLConfiguration
			Compare-Object -ReferenceObject $Folders -DifferenceObject
			
			
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
}#Function Restore-FolderStructurePermission


# Exporting the module members
Export-ModuleMember -Function * -Alias *

# Optional commands to create a public alias for the function
#New-Alias -Name gs -Value Get-Something
#Export-ModuleMember -Alias gs
