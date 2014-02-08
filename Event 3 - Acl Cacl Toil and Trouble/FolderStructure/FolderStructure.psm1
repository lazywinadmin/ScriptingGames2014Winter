#requires -version 3.0

Function New-FolderStructure {
<#
    .SYNOPSIS
            This function will create a new folder structure based on XML file specified in the XMLConfiguration parameter
    .DESCRIPTION
            This function will create a new folder structure based on XML file specified in the XMLConfiguration parameter
    .PARAMETER  Path
            Specifies the location at which the folder structure will be created
    .PARAMETER  XMLConfiguration
            Contains the Folder Structure which will be applied created from the Path
    .PARAMETER  ExportXMLPath
            Exports the created Folders and their respective ACL to a CLI XML file.
            This XML may be used for other functions and comes as: New-FolderStructure-yyyyMMdd_HHmmss.xml
    .EXAMPLE
            New-FolderStructure -Path C:\PS -XMLConfiguration C:\PS\FoldersStructure.xml
            
            Folder                                                 ACL                                                   
            ------                                                 ---                                                   
            C:\PS\Finance\Finance Open                             @{Access=System.Security.AccessControl.Authorizatio...
            C:\PS\Finance\RECEIPTS\Shared                          @{Access=System.Security.AccessControl.Authorizatio...
            C:\PS\Finance\RECEIPTS\Private                         @{Access=System.Security.AccessControl.Authorizatio...
            C:\PS\Finance\RECEIPTS\Lead                            @{Access=System.Security.AccessControl.Authorizatio...
            C:\PS\Finance\RECEIPTS                                 @{Access=System.Security.AccessControl.Authorizatio...
            C:\PS\Finance                                          @{Access=System.Security.AccessControl.Authorizatio...
    .EXAMPLE
            New-FolderStructure -Path C:\PS -XMLConfiguration C:\PS\FoldersStructure.xml -ExportXMLPath C:\PS
            
            Folder                                                 ACL                                                   
            ------                                                 ---                                                   
            C:\PS\Finance\Finance Open                             @{Access=System.Security.AccessControl.Authorizatio...
            C:\PS\Finance\RECEIPTS\Shared                          @{Access=System.Security.AccessControl.Authorizatio...
            C:\PS\Finance\RECEIPTS\Private                         @{Access=System.Security.AccessControl.Authorizatio...
            C:\PS\Finance\RECEIPTS\Lead                            @{Access=System.Security.AccessControl.Authorizatio...
            C:\PS\Finance\RECEIPTS                                 @{Access=System.Security.AccessControl.Authorizatio...
            C:\PS\Finance                                          @{Access=System.Security.AccessControl.Authorizatio...
            
    .NOTES
            Winter Scripting Games 2014 - Event 3
#>
    [CmdletBinding()]
    PARAM(
            [Parameter(Mandatory)]
            [ValidateScript({Test-Path -Path $_})]
            [String]$Path,
            [Parameter(Mandatory)]
            [ValidateScript({Test-Path -Path $_})]
            [String]$XMLConfiguration,
            [ValidateScript({Test-Path -Path $_})]
            [String]$ExportXMLPath
    )
    BEGIN {
        Write-Verbose -Message "[BEGIN] Function New-FolderStructure is Starting..."
        
        # Declare function Get-XMLAttribute
        Write-Verbose -Message "[BEGIN] Load Function Get-XMLAttribute"
        Function Get-XMLAttribute {
        <#
            .SYNOPSIS
                    Read an XML Attribute and return it's value or a specified default value
            .DESCRIPTION
                    Read an XML Attribute and return it's value or a specified default value
            .PARAMETER XMLNode
                    This is the desired XML Node
            .PARAMETER Attribute
                    This is the default attribute which we want to get from the XML Node
            .PARAMETER Default       
                    Specifies a Default value if the Attribute is missing from the XML Node
            .PARAMETER $ValidValues       
                    Specifies a Range of valid values for the attribute
            .NOTES
                    Winter Scripting Games 2014 - Event 3
        #>
            [CmdletBinding()]
            PARAM(
                [Parameter(Mandatory)]
                        $XMLNode,
                
                [Parameter(Mandatory)]
                [string]$Attribute,
                
                [string]$Default,
                
                $ValidValues
            )#PARAM Block
            
            BEGIN {
                $Value = $null
                Write-Verbose -Message "[BEGIN] Function Get-XMLAttribute is Starting..."
                IF ($PSBoundParameters.ContainsKey('Default')) { $Value = $Default }
            }#BEGIN Block
            
            PROCESS {
                IF ($ValidValues -contains $($XMLNode.$Attribute)) {
                    $Value = $($XMLNode.$Attribute)
                }#IF
                
            }#PROCESS Block
            END {
                $Value
                Write-Verbose -Message "[END] Function Get-XMLAttribute Completed!"
            }#END Block
        }#function Get-XMLAttribute
        
        
        # Declare function Set-XmlAcl
        Write-Verbose -Message "[BEGIN] Load Function Set-XmlAcl"
        Function Set-XmlAcl {
        <#
            .SYNOPSIS
                    Function to Apply an ACL on a folder according to an XML Value
            .DESCRIPTION
                    Function to Apply an ACL on a folder according to an XML Value
            .PARAMETER ACLNode
                    Specifies the XML ACL Node which we want to deal with
            .PARAMETER FolderNode
                    Specifies the XML Folder Node which the ACL shall refers to
            .PARAMETER FolderPath
                    Specifies the folder on which we want to apply this ACL
            .NOTES
                    Winter Scripting Games 2014 - Event 3
        #>
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
                [ValidateScript({Test-Path -Path $_})]
                [string]$FolderPath
            )#PARAM Block
            
            BEGIN {
                Write-Verbose -Message "[BEGIN] Function Set-XmlAcl is Starting"
                
                TRY
                {
                    $UpdateACL = $false
                    $ACL = Get-Acl -Path $FolderPath -ErrorAction Stop -ErrorVariable ErrorBeginGetACL
                    # Attributes
                    $AllowInherit = Get-XMLAttribute -XMLNode $FolderNode -Attribute "Inherit" -Default "Yes" -ValidValues "Yes", "No"
                    $AllowInherit = (@{ "Yes" = $false ; "No" = $true })[$AllowInherit]
                    
                    # Here we simply check whether we have to modify the Access Rules Protection regarding inheritance
                    $ACLProtected = $ACL.AreAccessRulesProtected
                    
                    If (($ACLProtected -and !$AllowInherit) -or (!$ACLProtected -and $AllowInherit)) {
                        Write-Verbose -Message "[BEGIN] Modifying Inheritance: Blocked -> $AllowInherit"
                        # Access Rules Protection determine whether the folder may inherit from it's parent container or not. (block inheritance, keep ace)
                        $ACL.SetAccessRuleProtection($AllowInherit, $false)
                        $UpdateACL = $true
                    }
                    $ACEWhiteList = "ListDirectory", "ReadData", "WriteData", "CreateFiles", "CreateDirectories", "AppendData", "ReadExtendedAttributes", "WriteExtendedAttributes", "Traverse", "ExecuteFile", "DeleteSubdirectoriesAndFiles", "ReadAttributes", "WriteAttributes", "Write", "Delete", "ReadPermissions", "Read", "ReadAndExecute", "Modify", "ChangePermissions", "TakeOwnership", "Synchronize", "FullControl"
                }#TRY Block
                
                CATCH {
                    Write-Warning -Message "[BEGIN] Something wrong happened"
                    IF ($ErrorBeginGetACL){Write-Warning -Message "[BEGIN] Error while retrieving the ACL from $FolderPath"}
                    $Error[0]
                }#CATCH Block
            }#BEGIN Block
            
            PROCESS {
                TRY{
                    $Account = $ACLNode.InnerText.Trim()
                    
                    # Our given account has to be valid
                    IF (($Account -ne "") -and ($Account -match "^([a-zA-Z0-9\\\s\._-]+)$")) {
                        
                        # An access attribute is required on the XML
                        IF ($ACLNode.HasAttribute("Access")) {
                            $ACEs = $ACLNode.Access.Split(",")
                            $Action = Get-XMLAttribute -XMLNode $ACLNode -Attribute "Action" -Default "Allow" -ValidValues "Allow", "Deny"
                            $ACEFlat = ($ACL.Access | Where-Object {($_.AccessControlType -eq $Action) -and ($_.IdentityReference -eq $Account)} | ForEach-Object {$_.FileSystemRights}) -join ","
                            $NewACE = @()
                            
                            # We iterate through all of the given ACE and check for missing ones.
                            FOREACH ($ACE in $ACEs) {
                                
                                $EffectiveACE = $ACE.Trim()
                                
                                # TODO: ACL is within the given list: http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemrights%28v=vs.110%29.aspx
                                IF ($ACEWhiteList -contains $EffectiveACE) {
                                    IF (-not($ACEFlat -match $EffectiveACE)) {
                                        $NewACE += $EffectiveACE
                                    } ELSE {
                                        Write-Verbose -Message "[PROCESS] ACE '$EffectiveACE' is already applied to account: '$Account'"
                                    }#ELSE
                                    
                                } ELSE {
                                    Write-Error -Message "[PROCESS] Invalid ACE specified: '$EffectiveACE'"
                                }#ELSE
                                
                            }#FOREACH
                            
                            # If we have a missing ACE then we create a new Access Rule and apply it to the existing ACL
                            IF ($NewACE -gt 0) {
                                Write-Verbose -Message "[PROCESS] Adding ACLs: '$($NewACE -join ",")' to account: '$Account'"
                                $nACL = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList $Account, @($NewACE -join ","), 'ContainerInherit,ObjectInherit', 'None', $Action
                                $ACL.AddAccessRule($nACL)
                                $UpdateACL = $true
                            } #IF
                        } ELSE {
                            Write-Error -Message "[PROCESS] The ACL does not have any Access attribute"
                        }#ELSE
                    } ELSE  {
                        Write-Error -Message "[PROCESS] The ACL is invalid: $Account"
                    }#ELSE
                    
                }#TRY
                
                CATCH{
                    Write-Verbose -Message "[BEGIN] Something wrong happened !"
                    $Error[0]
                }#CATCH Block
                
            }#PROCESS Block
            
            END {
                TRY{
                    # Only update the ACL if needed
                    IF ($UpdateACL) {
                        Write-Verbose -Message "[END] Applying ACL"
                        Set-Acl -Path $FolderPath -AclObject $ACL -ErrorAction Stop -ErrorVariable ErrorEndSetAcl
                    }#IF ($UpdateACL)
                    $ACL
                    
                }#TRY Block
                CATCH{
                    Write-Warning -Message "[END] Something wrong happened !"
                    IF($ErrorEndSetAcl){Write-Verbose -Message "[END] Error while setting the ACL"}
                    $Error[0]
                }#CATCH Block
                
                Write-Verbose -Message "[END] Function Set-XmlAcl Completed!"
            }#END Block
        }#Function Set-XmlAcl
        
        # Declare function Set-XmlFolder
        Write-Verbose -Message "[BEGIN] Load Function Set-XmlFolder"
        Function Set-XmlFolder {
        <#
            .SYNOPSIS
                    Function to create a Folder according to an XML Node
            .DESCRIPTION
                    Function to create a Folder according to an XML Node
            .PARAMETER FolderNode
                    Specifies the XML Folder Node that we want to create
            .PARAMETER FolderPath
                    Specifies the Folder Path on which we want to create the XML Folder Node
            .NOTES
                    Winter Scripting Games 2014 - Event 3
        #>
            [CmdletBinding()]
            PARAM(
                [Parameter(
                          Mandatory,
                          ValueFromPipeline,
                          ValueFromPipelineByPropertyName)]
                        $FolderNode,
                
                [Parameter(Mandatory)]
                [ValidateScript({Test-Path -Path $_})]
                [String]$FolderPath
            )#PARAM Block
            
            BEGIN {
                Write-Verbose -Message "[BEGIN] Function Set-XmlFolder is Starting..."
            }#BEGIN Block
            
            PROCESS {
                TRY{
                    # Our folder need to have a label
                    IF ($FolderNode.HasAttribute("Label")) {
                        $Label = $FolderNode.Label
                        # Make sure that our folder is compliant
                        IF ($Label -match "^([a-zA-Z0-9\s\._-]+)$") {
                            $NewPath = Join-Path -Path $FolderPath -ChildPath $Label
                            # If the given folder doesn't exist then we create it
                            IF (-not(Test-Path -Path $NewPath)) {
                                Write-Verbose -Message "[PROCESS] Creating folder: $NewPath"
                                $Folder = New-Item -Path $NewPath -ItemType "Directory" -Force
                            } ELSE {
                                Write-Verbose -Message "[PROCESS] Folder: '$NewPath' already exist, skipping creation"
                            }#ELSE
                            # The folder has ACL nodes?
                            $ACL = $FolderNode.ChildNodes | Where-Object {$_.LocalName -eq "ACL"} | Set-XMLACL -FolderNode $FolderNode -FolderPath $NewPath
                            
                            # We have more nested folders?
                            $FolderNode.ChildNodes | Where-Object {$_.LocalName -eq "Folder"} | Set-XMLFolder -FolderPath $NewPath
                            # Creating Output
                            New-Object PSObject -Property @{
                                ACL = $($ACL | Select Access, AreAccessRulesProtected)
                                Folder = $NewPath
                            }#NEW-OBJECT
                        } ELSE {
                            Write-Error -Message "[PROCESS] Invalid XML Folder label: '$Label'"
                        }#ELSE
                    } ELSE {
                        Write-Error -Message "[PROCESS] The current folder has no label attribute"
                    }#ELSE
                }
                CATCH{
                    Write-Warning -Message "[PROCESS] Something Wrong happened"
                    $Error[0]
                }
            }#PROCESS Block
            END {
                Write-Verbose -Message "[END] Function Set-XmlAcl Completed!"
            }#END Block
        }#Function Set-XmlFolder
        
    }#BEGIN Block
    
    PROCESS {
        
        TRY{
            $Now = Get-Date
        
            # Process the ACL/Structure if an XML was specified
            Write-Verbose -Message "[PROCESS] An XML was specified, attempting to create the structure"
            [xml]$XMLInput = Get-Content $XMLConfiguration -ErrorAction Stop -ErrorVariable ErrorProcessGetContent
                
            # Process each Nodes within the Folders tag
            $Output = $XMLInput.Folders.ChildNodes | Where-Object {$_.LocalName -eq "Folder"} | Set-XMLFolder -FolderPath $Path
        }#TRY
        CATCH{
            Write-Warning -Message "[PROCESS] Something wrong happened"
            IF($ErrorProcessGetContent){Write-Warning -Message "[PROCESS] Error while reading the file:$XMLConfiguration"}
            $error[0]
        }
    }#PROCESS Block
    
    END {
        TRY{
            IF ($PSBoundParameters.ContainsKey('ExportXMLPath')) {
                Write-Verbose -Message "[END] Exporting the result within file: New-FolderStructure-$($Now.ToString("yyyyMMdd_HHmmss")).xml"
                $Output | Export-Clixml -Path (Join-Path -Path $ExportXMLPath -ChildPath "New-FolderStructure-$($Now.ToString("yyyyMMdd_HHmmss")).xml") -Force -ErrorAction Continue -ErrorVariable ErrorEndExportCliXML
            }
        }#TRY
        CATCH{
            Write-Warning -Message "[PROCESS] Something wrong happened"
            IF($ErrorEndExportCliXML){Write-Warning -Message "[PROCESS] Error while exporting the xml file"}
            $error[0]
        }
        
        $Output
    }#END Block
    
}#Function New-FolderStructure


Function Get-AllFolders {
<#
    .SYNOPSIS
            This function will retrieve all the folders from a specific path.
    .DESCRIPTION
            This function will retrieve all the folders from a specific path.
    .PARAMETER  Path
            Specifies the path of the folders you want to retrieve.
    .PARAMETER  Recurse
            Specifies that the script must retrieve all the subfolders too
    .EXAMPLE
            Get-AllFolders -Path C:\ps\pathtest
            
            C:\ps\pathtest\subfolder1
            C:\ps\pathtest\subfolder2
    .EXAMPLE
            Get-AllFolders -Path C:\ps\pathtest -Recurse
            
            C:\ps\pathtest\subfolder1
            C:\ps\pathtest\subfolder2
            C:\ps\pathtest\subfolder1\subsubfolder1
            C:\ps\pathtest\subfolder1\subsubfolder2
            C:\ps\pathtest\subfolder1\subsubfolder3
            C:\ps\pathtest\subfolder1\subsubfolder4
            C:\ps\pathtest\subfolder1\subsubfolder5
            C:\ps\pathtest\subfolder1\subsubfolder6
            C:\ps\pathtest\subfolder2\subsubfolder1
            C:\ps\pathtest\subfolder2\subsubfolder2
            C:\ps\pathtest\subfolder2\subsubfolder3
            C:\ps\pathtest\subfolder2\subsubfolder4
            C:\ps\pathtest\subfolder2\subsubfolder5
            C:\ps\pathtest\subfolder2\subsubfolder6
    .NOTES
            Winter Scripting Games 2014 - Event 3
#>
        [CmdletBinding()]
        PARAM(
                [Parameter(Mandatory,
                    ValueFromPipeline,
                    ValueFromPipelineByPropertyName)]
                [ValidateScript({Test-Path -Path $_})]
                $Path,
        [Switch]$Recurse
    )
    BEGIN {
        Write-Verbose -Message "[BEGIN] Function Get-AllFolders is Starting..."
        TRY{
            # We use the experimental IO Long Path module to handle long files
            IF(-not("Microsoft.Experimental.IO.LongPathDirectory" -as [type])) {
                Write-Verbose -Message "[BEGIN] Microsoft.Experimental.IO.LongPathDirectory - Loading..."
                Add-Type -Path $PSScriptRoot\Microsoft.Experimental.IO.dll
                Write-Verbose -Message "[BEGIN] Microsoft.Experimental.IO.LongPathDirectory - Loaded"
            }#IF
        }#TRYBlock
        CATCH{
            Write-Verbose -Message "[BEGIN] Something wrong happened"
            $error[0]
        }#CATCH
    }#BEGIN Block
    PROCESS {
        IF($Recurse) {
            # List the folder $Path
            [Microsoft.Experimental.IO.LongPathDirectory]::EnumerateDirectories($path)
            
            # List the subfolders of $Path
            FOREACH ($folder in ([Microsoft.Experimental.IO.LongPathDirectory]::EnumerateDirectories($path) | where {$_ -ne ""} ))
            {
                Get-AllFolders -path $folder
            }#FOREACH
        } ELSE
        {
            # List the folder $Path
            [Microsoft.Experimental.IO.LongPathDirectory]::EnumerateDirectories($path)
        }#ELSE
    }#PROCESS Block
    END {Write-Verbose -Message "[END] Function Get-AllFolders Completed!"}#END Block
}

Function Compare-SecurityACL {
<#
    .SYNOPSIS
            Function which compare two ACLs on their Access properties
    .DESCRIPTION
            Function which compare two ACLs on their Access properties
    .PARAMETER ACLa
            The first ACL
    .PARAMETER ACLb
            The second ACL
    .NOTES
            Winter Scripting Games 2014 - Event 3
            
    .EXAMPLE
            Compare-SecurityACL -ACLa (Get-Acl c:\PS) -ACLb (Get-ACL c:\PS\Finance)
            True
            
    .EXAMPLE
            Compare-SecurityACL -ACLa (Get-Acl c:\PS) -ACLb (Get-ACL c:\PS\Finance) -Verbose
            VERBOSE: [BEGIN] Function Compare-SecurityACL is Starting...
            VERBOSE: [PROCESS] Create Object A from ACLa
            VERBOSE: [PROCESS] Create Object B from ACLb
            VERBOSE: [END] Function Compare-SecurityACL Completed!
            True
#>
	[CmdletBinding()]
	PARAM(
		[Parameter(Mandatory)]
		$ACLa,

		[Parameter(Mandatory)]
		$ACLb
    )#PARAM

    BEGIN {
        Write-Verbose -Message "[BEGIN] Function Compare-SecurityACL is Starting..."
        $DiffSecurityACL = $false
    }#BEGIN Block

    PROCESS {
        TRY {
            # Create Object A
            Write-Verbose -message "[PROCESS] Create Object A from ACLa"
            $CompareA = @{
                FileSystemRights = $ACLa.Access | ForEach-Object {$_.FileSystemRights}
                AccessControlType = $ACLa.Access | ForEach-Object {$_.AccessControlType}
                IdentityReference = $ACLa.Access | ForEach-Object {$_.IdentityReference.ToString()}
                IsInherited = $ACLa.Access | ForEach-Object {$_.IsInherited}
                InheritanceFlags = $ACLa.Access | ForEach-Object {$_.InheritanceFlags}
                PropagationFlags = $ACLa.Access | ForEach-Object {$_.InheritanceFlags}
            }#$CompareA
            
            # Create Object B
            Write-Verbose -message "[PROCESS] Create Object B from ACLb"
            $CompareB = @{
                FileSystemRights = $ACLb.Access | ForEach-Object {$_.FileSystemRights}
                AccessControlType = $ACLb.Access | ForEach-Object {$_.AccessControlType}
                IdentityReference = $ACLb.Access | ForEach-Object {$_.IdentityReference.ToString()}
                IsInherited = $ACLb.Access | ForEach-Object {$_.IsInherited}
                InheritanceFlags = $ACLb.Access | ForEach-Object {$_.InheritanceFlags}
                PropagationFlags = $ACLb.Access | ForEach-Object {$_.InheritanceFlags}
            }#$CompareB
            
            # Compare the two ACL
            FOREACH ($Value in "FileSystemRights", "AccessControlType", "IdentityReference", "InheritanceFlags", "PropagationFlags") {
                IF (Compare-Object -DifferenceObject $CompareA[$Value] -ReferenceObject $CompareB[$Value] -ErrorAction Stop -ErrorVariable ErrorProcessCompareObject) {
                    $DiffSecurityACL = $true
                    break
                }#IF
            }#FOREACH
        }#TRY
        CATCH{
            Write-Warning -Message "[PROCESS] Something wrong happened"
            IF($ErrorProcessCompareObject){Write-Warning -Message "[PROCESS] Error while comparing the two ACL"}
            $Error[0]
        }#CATCH
    }#PROCESS Block

    END {
        Write-Verbose -Message "[END] Function Compare-SecurityACL Completed!"
        $DiffSecurityACL
    }#END Block
}#Function Compare-SecurityACL


Function Compare-FolderStructure {
<#
    .SYNOPSIS
            Compare an actual Folder Structure with a given CLI XML
    .DESCRIPTION
            Compare an actual Folder Structure with a given CLI XML
    .PARAMETER  Path
            Specifies the Path to the Root of the Folder Structure
    .PARAMETER  XMLConfiguration
            Specifies the CLI XML to use as a comparison
    .PARAMETER  ExportHTMLPath
            Specifies the Path where the HTML report will be created
    .PARAMETER  Depth
            Determines how deep the comparison shall occur
        
    .EXAMPLE
            Compare-FolderStructure -Path C:\ps\Finance -XMLConfiguration C:\ps\New-FolderStructure-20140208_204021.xml

            CorrectACL                                   Path                                         CurrentACL                                 
            ----------                                   ----                                         ----------                                 
            @{Access=System.Collections.ArrayList; Ar... C:\ps\Finance\RECEIPTS                       @{Access=System.Security.AccessControl.A...
            @{Access=System.Collections.ArrayList; Ar... C:\ps\Finance\RECEIPTS\Private               @{Access=System.Security.AccessControl.A...
            
            This example will compare all the subfolders from the folder path c:\ps\finance with the XML file reference: c:\ps\New-FolderStructure-20140208_204021.xml
            
    .EXAMPLE
            Compare-FolderStructure -Path C:\ps\Finance -XMLConfiguration C:\ps\New-FolderStructure-20140208_204021.xml -Depth 2

            CorrectACL                                   Path                                         CurrentACL                                 
            ----------                                   ----                                         ----------                                 
            @{Access=System.Collections.ArrayList; Ar... C:\ps\Finance\RECEIPTS                       @{Access=System.Security.AccessControl.A...
            
            This example will compare all the subfolders with a depth of 2 from the folder path c:\ps\finance with the XML file reference: c:\ps\New-FolderStructure-20140208_204021.xml
   
    .EXAMPLE
            Compare-FolderStructure -Path C:\ps\Finance -XMLConfiguration C:\ps\New-FolderStructure-20140208_204021.xml -ExportHTMLPath c:\ps -Depth 3

            CorrectACL                                   Path                                         CurrentACL                                 
            ----------                                   ----                                         ----------                                 
            @{Access=System.Collections.ArrayList; Ar... C:\ps\Finance\RECEIPTS                       @{Access=System.Security.AccessControl.A...
            @{Access=System.Collections.ArrayList; Ar... C:\ps\Finance\RECEIPTS\Private               @{Access=System.Security.AccessControl.A...
            
            This example will compare all the subfolders with a depth of 3 from the folder path c:\ps\finance with the XML file reference: c:\ps\New-FolderStructure-20140208_204021.xml
            The function will also generate a HTML report in c:\ps called: Compare-FolderStructure-20140208_211515.html
    .NOTES
            Winter Scripting Games 2014 - Event 3
#>
    [CmdletBinding()]
    PARAM(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path -Path $_})]
        $Path,
        
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path -Path $_})]
        $XMLConfiguration,
        
        [ValidateScript({Test-Path -Path $_})]
        [String]$ExportHTMLPath,
        
        [int]$Depth
    )#PARAM
    BEGIN {
        TRY{
            Write-Verbose -Message "[BEGIN] Function Compare-FolderStructure is Starting..."
            
            # Declare Function Compare-FolderContent
            Write-Verbose -Message "[BEGIN] Load Function Compare-FolderContent"
            Function Compare-FolderContent {
            <#
                .SYNOPSIS
                        This function will compare the ACLs of a Given folder with the one from the XML if available
                .DESCRIPTION
                        This function will compare the ACLs of a Given folder with the one from the XML if available
                .PARAMETER Path
                        Specifies the Path that we want to analyse
                .PARAMETER CliXML
                        Specifies the XML which contains the correct ACLs
                .PARAMETER ParentValidACL
                        Specifies the last known correct XML ACL
                .PARAMETER Depth
                        Determines the maximum depth
                .NOTES
                        Winter Scripting Games 2014 - Event 3
            #>
                [CmdletBinding()]
                PARAM(
                    [Parameter(Mandatory,
                        ValueFromPipeline,
                        ValueFromPipelineByPropertyName)]
                    [ValidateScript({Test-Path -Path $_})]
                    $Path,
                    
                    [Parameter(Mandatory)]
                    $CliXML,
                        
                    $ParentValidACL,
                    [int]$Depth=-1
                )#PARAM Block
                
                BEGIN {
                    Write-Verbose -Message "[BEGIN] Function Compare-FolderContent is Starting..."
                    IF ($Depth -ne -1) { $Depth -= 1 }#IF
                }#BEGIN Block
                
                PROCESS {
                    TRY{
                        Write-Verbose -Message "[PROCESS] Comparing Folder: $Path"
                        $Acl = Get-Acl -Path $Path -ErrorAction Stop -ErrorVariable ErrorProcessGetAcl
                        IF (-not $ParentValidACL) {$ParentValidACL = $Acl}#IF
                        $Acl = $Acl | Select-Object Access, AreAccessRulesProtected
                        $XMLMatch = $CliXML | Where-Object { $_.Folder -eq $Path } | Select-Object -ExpandProperty ACL
                        $InheritChanged = $false
                        $Parent = $ParentValidACL
                        
                        IF (-not($XMLMatch)) {
                            Write-Verbose -Message "[PROCESS] No match, using parent ACL"
                            
                            # Create a new object to prevent overwritting the parent's one
                            $XMLMatch = New-Object PSObject -Property @{
                                Access = $ParentValidACL.Access
                                AreAccessRulesProtected = $ParentValidACL.AreAccessRulesProtected
                            }
                            If ($XMLMatch.AreAccessRulesProtected -and -not($Acl.AreAccessRulesProtected)) {
                                Write-Verbose -Message "[PROCESS] Parent ACL are protected, child inherits normally"
                                # We correct the ACL with what it should be according to the parent
                                $XMLMatch.AreAccessRulesProtected = $false
                            }
                            If ($XMLMatch.AreAccessRulesProtected -and $Acl.AreAccessRulesProtected) {
                                Write-Verbose -Message "[PROCESS] The inheritance has been changed at this level!"
                                $InheritChanged = $true
                                # We correct the ACL with what it should be according to the parent
                                $XMLMatch.AreAccessRulesProtected = $false
                            }
                        } else {
                            $Parent = $Acl
                            Write-Verbose -Message "[PROCESS] Found a Match"
                        }
                        #Compare-Object -DifferenceObject $Acl -ReferenceObject $XMLMatch -Property Access, AreAccessRulesProtected
                        If ((Compare-SecurityACL -ACLa $Acl -ACLb $XMLMatch) -or $InheritChanged) {
                            Write-Verbose -Message "[PROCESS] ACL Difference found!"
                            New-Object PSObject -Property @{
                                Path = $Path
                                CorrectACL = $XMLMatch
                                CurrentACL = $Acl
                            }
                        }
                        If (($Depth -gt 0) -or ($Depth -eq -1)) {
                            $Path | Get-AllFolders | Compare-FolderContent -CliXML $CliXML -ParentValidACL $Parent -Depth $Depth
                        }
                    }#TRY
                    CATCH{
                        Write-Warning -Message "[PROCESS] Something Wrong happened!"
                        IF($ErrorProcessGetAcl){Write-Warning -Message "[PROCESS] Error while getting the ACL from $path"}
                        $Error[0]
                    }
                }#PROCESS Block
                END {
                    Write-Verbose -Message "[END] Function Compare-FolderContent completed!"
                }#END Block
            }
            
            Write-Verbose -Message "[BEGIN] Starting a compare on path: $Path from CLI XML: $XMLConfiguration"
            $PreviousACL = Import-Clixml -Path $XMLConfiguration -ErrorAction Stop -ErrorVariable ErrorBeginImportCliXml
        }#TRY Block
        CATCH{
            Write-Warning -Message "[BEGIN] Something wrong happened!"
            IF($ErrorBeginImportCliXml){Write-Warning -Message "[BEGIN] Error while importing the XML file $XMLConfiguration"}
            $error[0]
        }#CATCH Block
    }#BEGIN
    
    PROCESS {
        TRY{
            $Now = Get-Date
            $Differences = Compare-FolderContent -Path $Path -CliXML $PreviousACL -Depth $Depth -ParentValidACL (Get-Acl -Path $Path -ErrorAction Stop -ErrorVariable ErrorProcessGetACL| Select-Object Access, AreAccessRulesProtected)
        }#TRY Block
        CATCH{
            Write-Warning -Message "[PROCESS] Something wrong happened!"
            IF($ErrorProcessGetACL){Write-Warning -Message "[PROCESS] Error while getting the ACL from $Path"}
            $error[0]
        }#CATCH Block
    }#PROCESS Block
    
    END {
        TRY {
            # Here we may have to create an HTML report
            IF ($PSBoundParameters.ContainsKey('ExportHTMLPath')) {
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
"@
                IF ($Differences) {
                    $html += '<span id="content_subtitle">Warning! Our structure ACLs have been modified on the following entries</span>'
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
                    }#FOREACH
                } ELSE {
                    $html += '<span id="content_subtitle">All Clear! Our Structure ACLs are untouched!</span>'
                }#ELSE
                
                Write-Verbose -Message "[END] Exporting the result within file: Compare-FolderStructure-$($Now.ToString("yyyyMMdd_HHmmss")).html"
                $html += "</div></div></body></html>"
                $html | Out-File (Join-Path -Path $ExportHTMLPath -ChildPath "Compare-FolderStructure-$($Now.ToString("yyyyMMdd_HHmmss")).html") -ErrorAction Continue -ErrorVariable ErrorEndOutFile
            }
            
            # Return the differences generated by the compare
            $Differences
        
        }#TRY
        CATCH{
            Write-Warning -Message "[END] Something wrong happened!"
            IF($ErrorEndOutFile){Write-Warning -Message "[END] Error while outputting the HTML report in $ExportHTMLPath"}
            $error[0]
        }
    }
}


Function Restore-FolderStructure {
<#
        .SYNOPSIS
                Restores the ACLs of a given Folder Structure according to a CLI XML
        .DESCRIPTION
                Restores the ACLs of a given Folder Structure according to a CLI XML
        .PARAMETER  Path
                Specifies the Path to the Root of the Folder Structure
        .PARAMETER  XMLConfiguration
                Specifies the CLI XML which contains the correct ACLs
        .PARAMETER  Depth
                Determine the maximum depth
                
        .EXAMPLE
                Restore-FolderStructure -Path C:\ps\Finance -XMLConfiguration C:\ps\New-FolderStructure-20140208_204021.xml
                C:\ps\Finance\RECEIPTS
                C:\ps\Finance\RECEIPTS\Private
                
                This function restore the correct folder structure ACL and Inheritance. 
                In this example only the two folders RECEIPTS and Private were not compliant.
                
        .EXAMPLE
                Restore-FolderStructure -Path C:\ps\Finance -XMLConfiguration C:\ps\New-FolderStructure-20140208_204021.xml -Depth 2
                C:\ps\Finance\RECEIPTS
                
                This function restore the correct folder structure ACL and Inheritance. 
                In this example only the folders RECEIPTS was not compliant. The parameter Depth was used to specify how deep the function have to work.
                
        .NOTES
                Winter Scripting Games 2014 - Event 3
#>
    [CmdletBinding()]
    PARAM(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path -Path $_})]
        [String]$Path,
        
        [ValidateScript({Test-Path -Path $_})]
        [String]$XMLConfiguration,
        
        [int]$Depth=-1
    )#PARAM
    BEGIN {
        Write-Verbose -Message "[BEGIN] Function Restore-FolderStructure is Starting ..."
        
        TRY{
            # Declare Function Restore-FolderContent
            Write-Verbose -Message "[BEGIN] Load Function Restore-FolderContent"
            Function Restore-FolderContent {
            <#
                .SYNOPSIS
                        This function will restore the ACLs of a Given folder from the CLI XML if available
                .DESCRIPTION
                        This function will restore the ACLs of a Given folder from the CLI XML if available
                .PARAMETER Path
                        Specifies the Path that we want to start the restoration from
                .PARAMETER CliXML
                        Specifies the XML file which contains the correct ACLs
                .PARAMETER ParentValidACL
                        Specifies the last known correct XML ACL
                .PARAMETER Depth
                        Determines the maximum depth
                .NOTES
                        Winter Scripting Games 2014 - Event 3
            #>
                [CmdletBinding()]
                PARAM(
                    [Parameter(Mandatory,
                        ValueFromPipeline,
                        ValueFromPipelineByPropertyName)]
                    [ValidateScript({Test-Path -Path $_})]
                    [String]$Path,
                    
                    [Parameter(Mandatory)]
                    [String]$CliXML,
                        
                    $ParentValidACL,
                    [int]$Depth
                )#PARAM Block
                
                BEGIN {
                    Write-Verbose -Message "[BEGIN] Function Restore-FolderContent Starting..."
                    $Output = @()
                    IF ($Depth -ne -1) { $Depth -= 1 }#IF
                }#BEGIN Block
                
                PROCESS {
                    TRY{
                        Write-Verbose -Message "[PROCESS] Analysing Folder: $Path"
                        
                        $Acl = Get-Acl -Path $Path -ErrorAction Stop -ErrorVariable ErrorProcessGetAcl
                        
                        If (-not $ParentValidACL)
                        {
                            $ParentValidACL = $Acl
                        }
                        
                        $Acl = $Acl | Select-Object Access, AreAccessRulesProtected
                        
                        $XMLMatch = $CliXML | Where-Object { $_.Folder -eq $Path } | Select-Object -ExpandProperty ACL
                        $InheritChanged = $false
                        $Parent = $ParentValidACL
                        $UseParent = $false
                        
                        IF (-not($XMLMatch)) {
                            Write-Verbose -Message "[PROCESS] No match, using parent ACL"
                            $UseParent = $true
                            # Create a new object to prevent overwritting the parent's one
                            $XMLMatch = New-Object PSObject -Property @{
                                Access = $ParentValidACL.Access
                                AreAccessRulesProtected = $ParentValidACL.AreAccessRulesProtected
                            }#New-Object
                            
                            IF ($XMLMatch.AreAccessRulesProtected -and -not($Acl.AreAccessRulesProtected)) {
                                Write-Verbose -Message "[PROCESS] Parent ACL are protected, child inherits normally"
                                # We correct the ACL with what it should be according to the parent
                                $XMLMatch.AreAccessRulesProtected = $false
                            }#IF ($XMLMatch.AreAccessRulesProtected -and -not($Acl.AreAccessRulesProtected))
                            
                            IF ($XMLMatch.AreAccessRulesProtected -and $Acl.AreAccessRulesProtected) {
                                Write-Verbose -Message "[PROCESS] The inheritance has been changed at this level!"
                                $InheritChanged = $true
                                # We correct the ACL with what it should be according to the parent
                                $XMLMatch.AreAccessRulesProtected = $false
                            }#IF ($XMLMatch.AreAccessRulesProtected -and $Acl.AreAccessRulesProtected)
                            
                        } ELSE {
                            $Parent = $Acl
                            Write-Verbose -Message "[PROCESS] Found a Match"
                        }#ELSE
                        
                        #Compare-Object -DifferenceObject $Acl -ReferenceObject $XMLMatch -Property Access, AreAccessRulesProtected
                        IF ((Compare-SecurityACL -ACLa $Acl -ACLb $XMLMatch) -or $InheritChanged) {
                            Write-Verbose -Message "[PROCESS] ACL Difference found!"
                            
                            $RemediateAcl = Get-Acl -Path $Path -ErrorAction Stop -ErrorVariable ErrorProcessGetAcl2
                            # Determine what differs and fix it
                            IF (Compare-Object -DifferenceObject $Acl.AreAccessRulesProtected -ReferenceObject $XMLMatch.AreAccessRulesProtected -ErrorAction Stop -ErrorVariable ErrorProcessCompareObject) {
                                Write-Verbose -Message "[PROCESS] Proceeding to Access Rules Protection remediation"
                                
                                # Simply remove what doesn't belong here
                                $Remediation = $RemediateAcl.Access | Where-Object { -not $_.IsInherited } | ForEach-Object { $RemediateAcl.RemoveAccessRule($_) }#FOREACH
                                
                                $RemediateAcl.SetAccessRuleProtection($XMLMatch.AreAccessRulesProtected, $false)
                            }#IF
                            IF (Compare-SecurityACL -ACLa $Acl -ACLb $XMLMatch) {
                                Write-Verbose -Message "[PROCESS] Proceeding to Security Access remediation"
                                
                                # Simply remove what doesn't belong here
                                $Remediation = $RemediateAcl.Access | Where-Object { -not $_.IsInherited } | ForEach-Object { $RemediateAcl.RemoveAccessRule($_) }#FOREACH
                                
                                IF (-not $UseParent) {
                                    # We recompose the potential deserialized ACLs
                                    $Remediation = $XMLMatch.Access | Where-Object { -not $_.IsInherited } | ForEach-Object { 
                                        $Rule = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList $_.IdentityReference.ToString(), $_.FileSystemRights, $_.InheritanceFlags, $_.PropagationFlags, $_.AccessControlType
                                        $RemediateAcl.AddAccessRule($Rule)
                                    }#ForEach-Object
                                }#If (-not $UseParent)
                            }#If (Compare-SecurityACL -ACLa $Acl -ACLb $XMLMatch)
                            
                            Set-Acl -Path $Path -AclObject $RemediateAcl -ErrorAction Stop -ErrorVariable ErrorProcessSetAcl
                            $Path
                        }#IF ((Compare-SecurityACL -ACLa $Acl -ACLb $XMLMatch) -or $InheritChanged)
                        
                        IF (($Depth -gt 0) -or ($Depth -eq -1)) {
                            $Path | Get-AllFolders | Restore-FolderContent -CliXML $CliXML -ParentValidACL $Parent -Depth $Depth
                        }#IF
                    }#TRY
                    CATCH{
                        Write-Warning -Message "[PROCESS] Something wrong happened"
                        IF($ErrorProcessGetAcl -or $ErrorProcessGetAcl2){Write-Warning -Message "[PROCESS] Error while getting the ACL of $PATH"}
                        IF($ErrorProcessSetAcl){Write-Warning -Message "[PROCESS] Error while setting the ACL of $PATH"}
                        IF($ErrorProcessCompareObject){Write-Warning -Message "[PROCESS] Error while comparing the two ACL"}
                        $Error[0]
                    }
                    
                }#PROCESS Block
                
                END {
                    Write-Verbose -Message "[END] Function Restore-FolderContent Completed!"
                }#END Block
            }#Function Restore-FolderContent
            
            
            Write-Verbose -Message "[BEGIN] Starting a remediation on path: $Path from CLI XML: $XMLConfiguration"
            $PreviousACL = Import-Clixml -Path $XMLConfiguration -ErrorAction Stop -ErrorVariable ErrorBeginImportCliXML
        }#TRY Block
        CATCH{
            Write-Warning -Message "[BEGIN] Something wrong happened"
            IF($ErrorBeginImportCliXML){Write-Warning -Message "[BEGIN] Error while importing the XML file: $XMLConfiguration"}
            $Error[0]
        }#CATCH Block
        
    }#BEGIN Block
    
    PROCESS {
        Restore-FolderContent -Path $Path -CliXML $PreviousACL -Depth $Depth
    }#PROCESS Block
    
    END {
        Write-Verbose -Message "[END] Function Restore-FolderContent Completed!"
    }#END Block
    
}#Function Restore-FolderContent


# Exporting the module members
Export-ModuleMember -Function * -Alias *
