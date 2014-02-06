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
                
            }

            PROCESS {
                $Account = $ACLNode.InnerText.Trim()

                If (($Account -ne "") -and ($Account -match "^([a-zA-Z0-9\\\s\._-]+)$")) {
                    If ($ACLNode.HasAttribute("Access")) {
                        $ACEs = $ACLNode.Access.Split(",")
                        $ACL = Get-Acl -Path $FolderPath

                        $Action = Get-XMLAttribute -XMLNode $ACLNode -Attribute "Action" -Default "Allow" -ValidValues "Allow", "Deny"
                        $ACEFlat = $ACL.Access | Where-Object {($_.AccessControlType -eq $Action) -and ($_.IdentityReference -eq $Account)} | ForEach-Object {$_.FileSystemRights}

                        ForEach ($ACE in $ACEs) {
                            $EffectiveACE = $ACE.Trim()
                            If ($EffectiveACL -match "^([a-zA-Z]+)$") {
                                If (-not($ACEFlat -contains $EffectiveACE)) {
# Apply Stock ACL on the folder (1: true: block inheritance, false: allow inheritance | 2: true, keep ACE, false: flush ACE)
<#
$AACL = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList 'GCM2000\brouleau', 'FullControl', 'ContainerInherit,ObjectInherit', 'NoPropagateInherit', 'Allow'
$BACL = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList 'BUILTIN\Administrateurs', 'FullControl', 'ContainerInherit,ObjectInherit', 'NoPropagateInherit', 'Allow'
                                
$ACL = Get-ACL -Path $NewPath
$ACL.AddAccessRule($AACL)
$ACL.AddAccessRule($BACL)
$ACL.SetAccessRuleProtection($InheritBlockFlag, $PropagateFlag)
                                
                                
Set-Acl -Path $NewPath -AclObject $ACL
#>
                                } else {
                                    Write-Verbose -Message "[PROCESS] ACE '$EffectiveACE' is already applied to '$Account'"
                                }
                            } else {
                                Write-Error -Message "[PROCESS] Invalid ACE format: $EffectiveACE"
                            }
                        }

                        
                        #Write-Verbose -Message "$($ACLNode.InnerText)"
                    } else {
                        Write-Error -Message "[PROCESS] The ACL does not have any Access attribute"
                    }
                } else {
                    Write-Error -Message "[PROCESS] The ACL is invalid: $Account"
                }
            }

            END {

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
                If ($FolderNode.HasAttribute("Label")) {
                    $Label = $FolderNode.Label
                    If ($Label -match "^([a-zA-Z0-9\s\._-]+)$") {
                        $NewPath = Join-Path -Path $FolderPath -ChildPath $Label

                        # If the given folder doesn't exist then we create it
                        If (-not(Test-Path -Path $NewPath)) {
                            Write-Verbose -Message "  [PROCESS] Creating folder: $NewPath"
                            $Folder = New-Item -Path $NewPath -ItemType "Directory" -Force
                        } else {
                            Write-Verbose -Message "  [PROCESS] Folder: '$NewPath' already exist, skipping creation"
                        }

                        # Attributes?
                        $Propagate = Get-XMLAttribute -XMLNode $FolderNode -Attribute "Propagate" -Default "Yes" -ValidValues "Yes", "No"
                        $Inherit = Get-XMLAttribute -XMLNode $FolderNode -Attribute "Inherit" -Default "Yes" -ValidValues "Yes", "No"

                        # The folder has ACL nodes?
                        $FolderNode.ChildNodes | Where-Object {$_.LocalName -eq "ACL"} | Process-XMLACL -FolderNode $FolderNode -FolderPath $NewPath
                
                        # We have more folders?
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

New-FolderStructure -Path c:\ps\acl\ -Name Finance -XMLConfiguration C:\ps\Folders.xml -Verbose
