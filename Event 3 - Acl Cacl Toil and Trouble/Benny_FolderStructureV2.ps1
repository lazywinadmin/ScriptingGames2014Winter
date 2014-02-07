Function New-FolderStructure {
	[CmdletBinding()]
	PARAM(
		[Parameter(Mandatory)]
		[ValidateScript({Test-Path -Path $_})]
		$Path,
	
		[Parameter(Mandatory)]
		[ValidateScript({
			IF ($_ -match '^([a-zA-Z0-9\s\._-]+)$') {$True}
			ELSE {Throw "$_ is either not a valid name for a directory or it is not recommended. See this MSDN article for more information: http://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx#naming_conventions"}
		})]
		$Name,

		[ValidateScript({Test-Path -Path $_})]
		$XMLConfiguration
    )

    BEGIN {
        # Private Function
        Function Get-XMLAttribute {
            [CmdletBinding()]
	        PARAM(
                [Parameter(Mandatory)]
		        $XMLNode,
                
                [Parameter(Mandatory)]
                [string]$Attribute,

                [string]$Default,

                $ValidValues
            )

            BEGIN {
                $Value = $null
                If ($PSBoundParameters.ContainsKey('Default')) { $Value = $Default }
            }

            PROCESS {
                If ($XMLNode.HasAttribute($Attribute)) { 
                    If ($ValidValues -contains $($XMLNode.$Attribute)) {
                        $Value = $($XMLNode.$Attribute)
                    }
                }
            }

            END {
                $Value
            }
        }
        
        # Private Function
        Function Process-XMLACL {
            [CmdletBinding()]
	        PARAM(
                [Parameter(
                          Mandatory,
                          ValueFromPipeline,
                          ValueFromPipelineByPropertyName)]
		        $ACLNode,
                
                [Parameter(Mandatory)]
                $FolderNode,

                [Parameter(Mandatory)]
                $FolderPath
            )

            BEGIN {
                $UpdateACL = $false

                $ACL = Get-Acl -Path $FolderPath

                # Attributes?
                $AllowInherit = Get-XMLAttribute -XMLNode $FolderNode -Attribute "Inherit" -Default "Yes" -ValidValues "Yes", "No"
                $AllowInherit = (@{ "Yes" = $false ; "No" = $true })[$AllowInherit]
                
                # Here we simply check whether we have to modify the Access Rules Protection regarding inheritance
                $ACLProtected = $ACL.AreAccessRulesProtected
                
                If (($ACLProtected -and !$AllowInherit) -or (!$ACLProtected -and $AllowInherit)) {
                    Write-Verbose -Message "  [BEGIN] Modifying Inheritance: Blocked -> $AllowInherit"

                    # Access Rules Protection determine whether the folder may inherit from it's parent container or not. (block inheritance, keep ace)
                    $ACL.SetAccessRuleProtection($AllowInherit, $false)
                    $UpdateACL = $true
                }
            }

            PROCESS {
                $Account = $ACLNode.InnerText.Trim()

                # Our given account has to be valid
                If (($Account -ne "") -and ($Account -match "^([a-zA-Z0-9\\\s\._-]+)$")) {
                    # An access attribute is required on the XML
                    If ($ACLNode.HasAttribute("Access")) {
                        $ACEs = $ACLNode.Access.Split(",")

                        $Action = Get-XMLAttribute -XMLNode $ACLNode -Attribute "Action" -Default "Allow" -ValidValues "Allow", "Deny"
                        $ACEFlat = ($ACL.Access | Where-Object {($_.AccessControlType -eq $Action) -and ($_.IdentityReference -eq $Account)} | ForEach-Object {$_.FileSystemRights}) -join ","

                        $NewACE = @()
                        
                        # We iterate thru all of the given ACE and check for missing ones.
                        ForEach ($ACE in $ACEs) {
                            $EffectiveACE = $ACE.Trim()
                            # TODO: ACL is within the given list: http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemrights%28v=vs.110%29.aspx
                            If ($EffectiveACE -match "^([a-zA-Z]+)$") {
                                If (-not($ACEFlat -match $EffectiveACE)) {
                                    $NewACE += $EffectiveACE
                                } else {
                                    Write-Verbose -Message "  [PROCESS] ACE '$EffectiveACE' is already applied to account: '$Account'"
                                }
                            } else {
                                Write-Error -Message "[PROCESS] Invalid ACE format: '$EffectiveACE'"
                            }
                        }

                        # If we have a missing ACE then we create a new Access Rule and apply it to the existing ACL
                        If ($NewACE -gt 0) {
                            Write-Verbose -Message "  [PROCESS] Adding ACLs: '$($NewACE -join ",")' to account: '$Account'"
                            $nACL = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList $Account, @($NewACE -join ","), 'ContainerInherit,ObjectInherit', 'None', $Action
                            $ACL.AddAccessRule($nACL)
                            $UpdateACL = $true
                        }
                    } else {
                        Write-Error -Message "[PROCESS] The ACL does not have any Access attribute"
                    }
                } else {
                    Write-Error -Message "[PROCESS] The ACL is invalid: $Account"
                }
            }

            END {
                # Only update the ACL if needed
                If ($UpdateACL) {
                    Write-Verbose -Message "  [END] Applying ACL"
                    Set-Acl -Path $FolderPath -AclObject $ACL
                }
            }
        }
        
        # Private Function
        Function Process-XMLFolder {
            [CmdletBinding()]
	        PARAM(
                [Parameter(
                          Mandatory,
                          ValueFromPipeline,
                          ValueFromPipelineByPropertyName)]
		        $FolderNode,
                
                [Parameter(Mandatory)]
                $FolderPath
            )

            BEGIN {
                #Write-Verbose -Message "[PROCESS] Folder Processing: $FolderPath"
            }

            PROCESS {
                # Our folder need to have a label
                If ($FolderNode.HasAttribute("Label")) {
                    $Label = $FolderNode.Label
                    # Make sure that our folder is compliant
                    If ($Label -match "^([a-zA-Z0-9\s\._-]+)$") {
                        $NewPath = Join-Path -Path $FolderPath -ChildPath $Label

                        # If the given folder doesn't exist then we create it
                        If (-not(Test-Path -Path $NewPath)) {
                            Write-Verbose -Message "[PROCESS] Creating folder: $NewPath"
                            $Folder = New-Item -Path $NewPath -ItemType "Directory" -Force
                        } else {
                            Write-Verbose -Message "[PROCESS] Folder: '$NewPath' already exist, skipping creation"
                        }

                        # The folder has ACL nodes?
                        $FolderNode.ChildNodes | Where-Object {$_.LocalName -eq "ACL"} | Process-XMLACL -FolderNode $FolderNode -FolderPath $NewPath
                
                        # We have more nested folders?
                        $FolderNode.ChildNodes | Where-Object {$_.LocalName -eq "Folder"} | Process-XMLFolder -FolderPath $NewPath
                    } else {
                        Write-Error -Message "[PROCESS] Invalid XML Folder label: '$Label'"
                    }
                } else {
                    Write-Error -Message "[PROCESS] The current folder has no label attribute"
                }
            }

            END {
                
            }
        }
        
        # Create the top root
        $Root = Join-Path -Path $Path -ChildPath $Name
		If (-not(Test-Path -Path $Root)) {
			Write-Verbose -Message "[BEGIN] Createing the folder $Name at $Path"
			$Folder = New-Item -Path $Root -ItemType "Directory" -Force
		}
    }

    PROCESS {
        # Process the ACL/Structure if an XML was specified
        If ($PSBoundParameters.ContainsKey('XMLConfiguration')) {
            Write-Verbose -Message "[PROCESS] An XML was specified, attempting to create the structure"
            [xml]$XMLInput = Get-Content $XMLConfiguration
            
            # Process each Nodes within the Folders tag
            $XMLInput.Folders.ChildNodes | Where-Object {$_.LocalName -eq "Folder"} | Process-XMLFolder -FolderPath $Path
        }
    }

    END {
        
    }
}

New-FolderStructure -Path c:\ps\acl\ -Name Finance -XMLConfiguration $PSScriptRoot\Folders.xml -Verbose
