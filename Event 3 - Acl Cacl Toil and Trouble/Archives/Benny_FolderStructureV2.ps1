Function New-FolderStructure {
	[CmdletBinding()]
	PARAM(
		[Parameter(Mandatory)]
		[ValidateScript({Test-Path -Path $_})]
		$Path,
	
		[Parameter(Mandatory)]
		[ValidateScript({
			IF ($_ -match '^([a-zA-Z0-9\s\._-]+)$') {$True}
			ELSE {Throw "$_ is not a valid name for a directory"}
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

                $ACEWhiteList = "ListDirectory", "ReadData", "WriteData", "CreateFiles", "CreateDirectories", "AppendData", "ReadExtendedAttributes", "WriteExtendedAttributes", "Traverse", "ExecuteFile", "DeleteSubdirectoriesAndFiles", "ReadAttributes", "WriteAttributes", "Write", "Delete", "ReadPermissions", "Read", "ReadAndExecute", "Modify", "ChangePermissions", "TakeOwnership", "Synchronize", "FullControl"
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
                            If ($ACEWhiteList -contains $EffectiveACE) {
                                If (-not($ACEFlat -match $EffectiveACE)) {
                                    $NewACE += $EffectiveACE
                                } else {
                                    Write-Verbose -Message "  [PROCESS] ACE '$EffectiveACE' is already applied to account: '$Account'"
                                }
                            } else {
                                Write-Error -Message "[PROCESS] Invalid ACE specified: '$EffectiveACE'"
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

                $ACL
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
                        $ACL = $FolderNode.ChildNodes | Where-Object {$_.LocalName -eq "ACL"} | Process-XMLACL -FolderNode $FolderNode -FolderPath $NewPath
                        
                        # We have more nested folders?
                        $FolderNode.ChildNodes | Where-Object {$_.LocalName -eq "Folder"} | Process-XMLFolder -FolderPath $NewPath

                        # We create a quick output
                        $Output = New-Object PSObject -Property @{
                            ACL = $($ACL | Select Access, AreAccessRulesProtected)
                            Folder = $NewPath
                        }
                    } else {
                        Write-Error -Message "[PROCESS] Invalid XML Folder label: '$Label'"
                    }
                } else {
                    Write-Error -Message "[PROCESS] The current folder has no label attribute"
                }
            }

            END {
                $Output
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
            $Output = $XMLInput.Folders.ChildNodes | Where-Object {$_.LocalName -eq "Folder"} | Process-XMLFolder -FolderPath $Path
        }
    }

    END {
        $Output
    }
}


Function Get-AllFolders {
	[CmdletBinding()]
	PARAM(
		[Parameter(Mandatory,
                    ValueFromPipeline,
                    ValueFromPipelineByPropertyName)]
		[ValidateScript({Test-Path -Path $_})]
		$Path,

        [bool]$Recurse=$false
    )

    BEGIN { }

    PROCESS {
        #Get-ChildItem -Path -Directory -Recurse
        $Folders += [Microsoft.Experimental.IO.LongPathDirectory]::EnumerateDirectories( $Path )

        If ($Recurse) {
            $SubFolders = $Folders | Get-AllFolders -Recurse $Recurse
            If ($SubFolders) {$Folders += $SubFolders }
        }
    }

    END {
        $Folders
    }
}

Function Compare-FolderStructure {
	[CmdletBinding()]
	PARAM(
		[Parameter(Mandatory)]
		[ValidateScript({Test-Path -Path $_})]
		$Path,

		[ValidateScript({Test-Path -Path $_})]
		$XMLConfiguration,

        [int]$Depth
    )

    BEGIN {
        # Private Function
        Function Compare-FolderContent {
	        [CmdletBinding()]
	        PARAM(
		        [Parameter(Mandatory,
                            ValueFromPipeline,
                            ValueFromPipelineByPropertyName)]
		        [ValidateScript({Test-Path -Path $_})]
		        $Path,

                [Parameter(Mandatory)]
                $CliXML,
                    
                [Parameter(Mandatory)]
                $ParentValidACL,

                [int]$Depth=-1
            )

            BEGIN { 
                $Output = @()
                If ($Depth -ne -1) { $Depth -= 1 }
            }

            PROCESS {
                Write-Verbose -Message "[PROCESS] Comparing Folder: $Path"
                $Acl = Get-Acl -Path $Path | Select-Object Access, AreAccessRulesProtected

                $XMLMatch = $CliXML | Where-Object { $_.Folder -eq $Path } | Select-Object -ExpandProperty ACL
                $CompareProperties = "Access", "AreAccessRulesProtected"
                $InheritChanged = $false
                $Parent = $ParentValidACL
                
                If (-not($XMLMatch)) {
                    Write-Verbose -Message "  [PROCESS] No match, using parent ACL"
                    
                    # Create a new object to prevent overwritting the parent's one
                    $XMLMatch = New-Object PSObject -Property @{
                        Access = $ParentValidACL.Access
                        AreAccessRulesProtected = $ParentValidACL.AreAccessRulesProtected
                    }
                    If ($XMLMatch.AreAccessRulesProtected -and -not($Acl.AreAccessRulesProtected)) {
                        Write-Verbose -Message "  [PROCESS] Parent ACL are protected, child inherits normally"
                        $CompareProperties = "Access"

                        # We correct the ACL with what it should be according to the parent
                        $XMLMatch.AreAccessRulesProtected = $false
                    }
                    If ($XMLMatch.AreAccessRulesProtected -and $Acl.AreAccessRulesProtected) {
                        Write-Verbose -Message "  [PROCESS] The inheritance has been changed at this level!"
                        $InheritChanged = $true

                        # We correct the ACL with what it should be according to the parent
                        $XMLMatch.AreAccessRulesProtected = $false
                    }
                } else {
                    $Parent = $Acl
                    Write-Verbose -Message "  [PROCESS] Found a Match"
                }

                #Compare-Object -DifferenceObject $Acl -ReferenceObject $XMLMatch -Property Access, AreAccessRulesProtected
                If ((Compare-Object -DifferenceObject $Acl -ReferenceObject $XMLMatch -Property $CompareProperties) -or $InheritChanged) {
                    Write-Verbose -Message "  [PROCESS] ACL Difference found!"
                    $Output += New-Object PSObject -Property @{
                        Path = $Path
                        CorrectACL = $XMLMatch
                        CurrentACL = $Acl
                    }
                }

                If (($Depth -gt 0) -or ($Depth -eq -1)) {
                    $Output += $Path | Get-AllFolders | Compare-FolderContent -CliXML $CliXML -ParentValidACL $Parent -Depth $Depth
                }
            }

            END {
                $Output
            }
        }



        Write-Verbose -Message "[BEGIN] Starting a compare on path: $Path from CLI XML: $XMLConfiguration"
        $PreviousACL = Import-Clixml -Path $XMLConfiguration
        #$PreviousACL
    }

    PROCESS {
        $Differences = Compare-FolderContent -Path $Path -CliXML $PreviousACL -Depth $Depth -ParentValidACL (Get-Acl -Path $Path | Select-Object Access, AreAccessRulesProtected)
    }

    END {
        # Maybe we have some difference, maybe we don't
        $Now = Get-Date
        If ($Differences) {
            $html = @"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://
www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
  <title>ACL Report: $($Now.ToString("yyyy-MM-dd HH:mm:ss"))</title>
  <style type="text/css">
body {
    height: 100%;
    margin: 0px;
	background-color: #a0e1ff;
	background-image: -ms-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: -moz-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: -o-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: -webkit-gradient(linear, left top, right bottom, color-stop(0, #FFFFFF), color-stop(1, #00A3EF));
	background-image: -webkit-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: linear-gradient(to bottom right, #FFFFFF 0%, #00A3EF 100%);
    background-repeat: no-repeat;
    background-attachment: fixed;
	font-family:"Tahoma", "Lucida Sans Unicode", Verdana, Arial, Helvetica, sans-serif;
	font-size:12px;
}
#container {
	padding-top:50px;
	padding-bottom:50px;
}

#core {
	background-color: #efefef;
	-webkit-background-size: 50px 50px;
	-moz-background-size: 50px 50px;
	background-size: 50px 50px;
	-moz-box-shadow: 1px 1px 8px gray;
	-webkit-box-shadow: 1px 1px 8px gray;
	box-shadow: 1px 1px 8px gray;
	box-shadow: 0 0 5px #888;
	border: 1px solid #91938d;
	margin: 0 auto;
    padding-bottom: 15px;
	width: 880px;
}

#header {
	background-color: #2d2d2d;
	border-bottom: 3px solid #666863;
	height: 35px;
	margin-bottom: 20px;
}

#title {
	color: #ffffff;
	font-family: Tahoma;
	font-size: 18px;
	line-height: 35px;
	font-variant: small-caps;
	font-weight: bold;
	padding-left: 25px;
	margin: 0 auto;
	text-transform: uppercase;
	vertical-align:middle;
}

#ACLContent {
    background-color: #fff;
    border-bottom: 1px solid #ddd;
    border-top: 1px solid #ddd;
    display: block;
    margin: 0 auto;
    margin-bottom: 25px;
    padding: 10px;
}

#content_subtitle {
	display: block;
	margin-bottom: 10px;
	padding-left: 14px;
	font-size: 15px;
}

#content_legend {
	display: block;
	margin-bottom: 5px;
    margin-top: 5px;
	padding-left: 14px;
	font-size: 14px;
    font-weight: bold;
}

table {
	border-collapse: collapse;
	border: 1px solid #ddd;
}

table td {
	padding-left: 10px;
	padding-right: 20px;
}
  </style>
</head>
<body>
<div id="container">
	<div id="core">
		<div id="header"><span id="title">ACL Report: $($Now.ToString("yyyy-MM-dd HH:mm:ss"))</span></div>
		<span id="content_subtitle">It appears as if someone had touched our ACLs!</span>
"@
            $Differences | ForEach-Object {
                $html += @"
                <div id="ACLContent">
                    <span id="content_legend">Folder: </span>
                    $($_.Path)
                    <br /><br /><span id="content_legend">Correct ACL:</span>
                    ACL Access Rules Protection: $($_.CorrectACL.AreAccessRulesProtected)<br /><br />
"@
                $html += $_.CorrectACL.Folder
                $html += $_.CorrectACL.Access | ConvertTo-Html -Fragment -As List
                $html += @"
                    <br />
                    <span id="content_legend">Current ACL:</span>
                    ACL Access Rules Protection: $($_.CurrentACL.AreAccessRulesProtected)<br /><br />
"@
                $html += $_.CurrentACL.Access | ConvertTo-Html -Fragment -As List
                $html += "</div>"
            }
            #$Differences | Select-Object Path, CorrectACL, CurrentACL -ExpandProperty CurrentACL | Select-Object Access -ExpandProperty Access | ConvertTo-Html -Fragment | Out-File $PSScriptRoot\report.html
            $html += "</div></div></body></html>"
            $html | Out-File $PSScriptRoot\report.html
        } else {

        }
    }
}

Function Remediate-FolderStructure {
	[CmdletBinding()]
	PARAM(
		[Parameter(Mandatory)]
		[ValidateScript({Test-Path -Path $_})]
		$Path,

		[ValidateScript({Test-Path -Path $_})]
		$XMLConfiguration,

        [int]$Depth=-1
    )

    BEGIN {
        # Private Function
        Function Remediate-FolderContent {
	        [CmdletBinding()]
	        PARAM(
		        [Parameter(Mandatory,
                            ValueFromPipeline,
                            ValueFromPipelineByPropertyName)]
		        [ValidateScript({Test-Path -Path $_})]
		        $Path,

                [Parameter(Mandatory)]
                $CliXML,
                    
                [Parameter(Mandatory)]
                $ParentValidACL,

                [int]$Depth
            )

            BEGIN { 
                $Output = @()
                If ($Depth -ne -1) { $Depth -= 1 }
            }

            PROCESS {
                Write-Verbose -Message "[PROCESS] Analysing Folder: $Path"
                $Acl = Get-Acl -Path $Path | Select-Object Access, AreAccessRulesProtected

                $XMLMatch = $CliXML | Where-Object { $_.Folder -eq $Path } | Select-Object -ExpandProperty ACL
                $CompareProperties = "Access", "AreAccessRulesProtected"
                $InheritChanged = $false
                $Parent = $ParentValidACL
                $UseParent = $false
                
                If (-not($XMLMatch)) {
                    Write-Verbose -Message "  [PROCESS] No match, using parent ACL"
                    $UseParent = $true

                    # Create a new object to prevent overwritting the parent's one
                    $XMLMatch = New-Object PSObject -Property @{
                        Access = $ParentValidACL.Access
                        AreAccessRulesProtected = $ParentValidACL.AreAccessRulesProtected
                    }
                    If ($XMLMatch.AreAccessRulesProtected -and -not($Acl.AreAccessRulesProtected)) {
                        Write-Verbose -Message "  [PROCESS] Parent ACL are protected, child inherits normally"
                        $CompareProperties = "Access"

                        # We correct the ACL with what it should be according to the parent
                        $XMLMatch.AreAccessRulesProtected = $false
                    }
                    If ($XMLMatch.AreAccessRulesProtected -and $Acl.AreAccessRulesProtected) {
                        Write-Verbose -Message "  [PROCESS] The inheritance has been changed at this level!"
                        $InheritChanged = $true

                        # We correct the ACL with what it should be according to the parent
                        $XMLMatch.AreAccessRulesProtected = $false
                    }
                } else {
                    $Parent = $Acl
                    Write-Verbose -Message "  [PROCESS] Found a Match"
                }

                #Compare-Object -DifferenceObject $Acl -ReferenceObject $XMLMatch -Property Access, AreAccessRulesProtected
                If ((Compare-Object -DifferenceObject $Acl -ReferenceObject $XMLMatch -Property $CompareProperties) -or $InheritChanged) {
                    Write-Verbose -Message "  [PROCESS] ACL Difference found!"
                    
                    $RemediateAcl = Get-Acl -Path $Path

                    # Determine what differs and fix it
                    If (Compare-Object -DifferenceObject $Acl.AreAccessRulesProtected -ReferenceObject $XMLMatch.AreAccessRulesProtected) {
                        Write-Verbose -Message "    [PROCESS] Proceeding to Access Rules Protection remediation"
                        
                        $RemediateAcl.SetAccessRuleProtection($XMLMatch.AreAccessRulesProtected, $false)
                    }

                    If (Compare-Object -DifferenceObject $Acl.Access -ReferenceObject $XMLMatch.Access) {
                        Write-Verbose -Message "    [PROCESS] Proceeding to Security Access remediation"

                        # Simply remove what doesn't belong here
                        $Remediation = $RemediateAcl.Access | Where-Object { -not $_.IsInherited } | ForEach-Object { $RemediateAcl.RemoveAccessRule($_) }
                        If (-not $UseParent) {
                            # We recompose the potential deserialized ACLs
                            $Remediation = $XMLMatch.Access | Where-Object { -not $_.IsInherited } | ForEach-Object { 
                                $Rule = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList $_.IdentityReference.ToString(), $_.FileSystemRights, $_.InheritanceFlags, $_.PropagationFlags, $_.AccessControlType
                                $RemediateAcl.AddAccessRule($Rule)
                            }
                        }
                    }

                    $Output += $Path
                    Set-Acl -Path $Path -AclObject $RemediateAcl
                }

                If (($Depth -gt 0) -or ($Depth -eq -1)) {
                    $Output += $Path | Get-AllFolders | Remediate-FolderContent -CliXML $CliXML -ParentValidACL $Parent -Depth $Depth
                }
            }

            END {
                $Output
            }
        }

        Write-Verbose -Message "[BEGIN] Starting a remediation on path: $Path from CLI XML: $XMLConfiguration"
        $PreviousACL = Import-Clixml -Path $XMLConfiguration
    }

    PROCESS {
        Remediate-FolderContent -Path $Path -CliXML $PreviousACL -Depth $Depth -ParentValidACL (Get-Acl -Path $Path | Select-Object Access, AreAccessRulesProtected)
    }

    END {
        
    }
}

# We use the experimental IO Long Path module to handle long files
if(!("Microsoft.Experimental.IO.LongPathDirectory" -as [type])) {
    Add-Type -Path $PSScriptRoot\Microsoft.Experimental.IO.dll
}

#$xml=New-FolderStructure -Path c:\ps\acl\ -Name Finance -XMLConfiguration $PSScriptRoot\Folders.xml -Verbose | ConvertTo-Xml -NoTypeInformation -Depth 3
#$xml.InnerXml | out-file c:\ps\dump.xml
#New-FolderStructure -Path c:\ps\acl\ -Name Finance -XMLConfiguration $PSScriptRoot\Folders.xml -Verbose | Export-Clixml c:\ps\dump.xml

#Compare-FolderStructure -Path C:\ps\acl\Finance -XMLConfiguration C:\ps\dump.xml -Depth 3 -Verbose

Remediate-FolderStructure -Path C:\ps\acl\Finance -XMLConfiguration C:\ps\dump.xml -Depth 4 -Verbose
