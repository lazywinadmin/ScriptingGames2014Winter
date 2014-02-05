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
        Function Process-XMLFolder {
	        PARAM(
		        [Parameter(Mandatory)]
		        $XMLNode,

                $FolderPath
            )

            BEGIN {
                $XMLTagName = $XMLNode.LocalName
            }

            PROCESS {
                Switch ($XMLTagName) {
                    # We deal with a folder here
                    "Folder" {
                        Write-Verbose -Message "[PROCESS] Processing a Folder node"

                        # The folder has a name right?
                        If ($XMLNode.HasAttribute("Label")) {
                            $Label = $XMLNode.Label
                            If ($Label -match "^([a-zA-Z0-9\s\._-]+)$") {
                                $NewPath = Join-Path -Path $FolderPath -ChildPath $Label
                                
                                # If the given folder doesn't exist then we create it
                                If (-not(Test-Path -Path $NewPath)) {
                                    Write-Verbose -Message "  [PROCESS] Creating folder: $NewPath"
                                    $Folder = New-Item -Path $NewPath -ItemType "Directory" -Force
                                } else {
                                    Write-Verbose -Message "  [PROCESS] Folder: '$NewPath' already exist"
                                }

                                # As a famous actor said, We 'may' need to go deeper
                                If ($XMLNode.HasChildNodes) {
                                    ForEach ($Node in $XMLNode.ChildNodes) {
                                        Process-XMLFolder -XMLNode $Node -FolderPath $NewPath
                                    }
                                }
                            } else {
                                Write-Error -Message "[PROCESS] Invalid XML Folder label: '$Label'"
                            }
                        } else {
                            Write-Error -Message "[PROCESS] The current folder has no label attribute"
                        }

                        break;
                    }

                    # We deal with an ACL here
                    "ACL" {
                        Write-Verbose -Message "[PROCESS] Processing an ACL node for Folder: '$FolderPath'"

                        # Make sure that we have something to apply on the given ACL
                        
                        $ApplyTo = $XMLNode.InnerText.Trim()
                        If (($ApplyTo -ne "") -and ($ApplyTo -match "^([a-zA-Z\\\s\._-]+)$")) {
                            If ($XMLNode.HasAttribute("Access")) {
                                $Access = $XMLNode.Access.Split(",")

                                ForEach ($ACL in $Access) {
                                    $EffectiveACL = $ACL.Trim()
                                    If ($EffectiveACL -match "^([a-zA-Z]+)$") {
                                        # Todo: check if ACL is already set or not forgiven user/group
                                        Write-Verbose -Message "  [PROCESS] Applying ACL: '$EffectiveACL' for: '$ApplyTo'"
                                    } else {
                                        Write-Error -Message "[PROCESS] Invalid ACL format used: '$EffectiveACL'"
                                    }
                                }
                            } else {
                                Write-Error -Message "[PROCESS] The ACL does not have any Access attribute"
                            }
                        } else {
                            Write-Error -Message "[PROCESS] The ACL is invalid"
                        }

                        break;
                    }
                }
            }

            END {
                
            }
        }
        
        # Create the top root
        $Root = Join-Path -Path $Path -ChildPath $Name
		IF(-not(Test-Path -Path $Root)) {
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
            ForEach ($Node in $XMLInput.Folders.ChildNodes) {
                Process-XMLFolder -XMLNode $Node -FolderPath $Path
            }
        }
    }

    END {
        
    }
}

New-FolderStructure -Path c:\ps\acl\ -Name Finance -XMLConfiguration C:\ps\Folders.xml -Verbose
