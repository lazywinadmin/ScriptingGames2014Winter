# Put all the functions in this file
#Region Stephane
Function Get-XMlDifferences {
	#Not Finalized yet
    [CmdletBinding()]
    PARAM(
        [Parameter(mandatory=$true,position=0)]
        [ValidateScript({
            test-path -Path $_
        })]
        $ReferenceObject,
	
        [Parameter(mandatory=$true,position=1)]
        [ValidateScript({
            test-path -Path $_    
        })]
        $DifferenceObject
    )#PARAM

    BEGIN{}#BEGIN
    PROCESS{
        #Getting the XML content to compare
        $ContentReference = Get-Content -Path $ReferenceObject
        $contentDifference = Get-Content -path $differenceObject
        
		#Getting differences
        $Differences = Compare-Object -ReferenceObject $ContentReference -DifferenceObject $contentDifference -CaseSensitive | Where-Object {$_.sideIndicator -eq "=>"} | Select-Object -Property Inputobject
       
		#Retrieving line informations
        $String = select-string -SimpleMatch -CaseSensitive '$($Differences.Inputobject)' -Path $ReferenceObject
        $Return = [pscustomobject]@{"LineContent"=$Differences.Inputobject; "LineNumber"=$String.LineNumber}

    }#PROCESS
    END{
        Write-Output -InputObject $Return
    }#END
}

$ReferenceObject = "C:\Users\gulicst1\SkyDrive\Scripting\Githhub\WinterScriptingGames2014\WinterScriptingGames2014\Event 2 - Security Footprint\Reference.config"
$differenceObject = "C:\Users\gulicst1\SkyDrive\Scripting\Githhub\WinterScriptingGames2014\WinterScriptingGames2014\Event 2 - Security Footprint\Difference.config"

Get-XMlDifferences -ReferenceObject $ReferenceObject -differenceObject $differenceObject
#Not finished yet
#EndRegion


#region Set-SecurityMeasure

function Set-SecurityMeasure
{
<#
.Synopsis
   Function Takes a Folder path and sets the restricted Folder permissions on it and gives an option to encrypt it
.DESCRIPTION
   This Function will take a path to a folder and block inheritance of ACL on it and then will set the Current User
    running the Function as the owner of that Folder. If the Script detects already the appropraite ACLs are set then
    no changes are made. It gives an option to Encrypt the folder.
.PARAMETER Path
    Specify the path of the folder where restrictive permissions are to be set.
.PARAMETER Encrypt
    Specify this Switch if you want to encrypt the Input Path Folder as well.
.PARAMETER Force
    Specify this Switch if you want to force the changes.
.PARAMETER PassThru
    Specify this switch to get the ACL Object back at the end.
.EXAMPLE
    Following example first create a Folder where sensitive data is stored.
    Then put the restrictive ACLs on the Folder to allow only the Script owner the access.
    PS> Mkdir Dexter1
    PS> Set-SecurityMeasure -Path .\Dexter1 -Verbose
.EXAMPLE
     One can pipe the String to the Folder path to the Function as well. 
     Specify Switch Passthru to get the new ACL back  on the folder.

     PS> "C:\Temp\Test1" | Set-SecurityMeasure -Verbose  -PassThru
        VERBOSE: [BEGIN] Starting the Function Set-SecurityMeasure
        VERBOSE: [PROCESS]
        VERBOSE: [PROCESS] Settting the Administrator as the Owner for the .\test1
        VERBOSE: [PROCESS] Setting the modified ACL to the .\test1
        VERBOSE: Performing the operation "Set-Acl" on target "C:\temp\test1".


            Directory: C:\temp


        Path                                                   Owner                                                  Access                                                
        ----                                                   -----                                                  ------                                                
        test1                                                  DEXTER\Administrator                                   DEXTER\Administrator Allow  FullControl               
        VERBOSE: [END] Ending the Function Set-SecurityMeasure
.INPUTS
   [System.String]
.OUTPUTS
   System.Security.AccessControl.DirectorySecurity

#>   
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    [OutputType([String])]
    PARAM
    (
        [Parameter(Mandatory, 
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [ValidateScript({Test-Path -Path $_ -PathType Container })]
        [Alias("Fullname")]
        [string]$Path,

        [switch]$Encrypt,

        [switch]$Force,

        [switch]$PassThru
    )#PARAM

    BEGIN
    {
        Write-Verbose -Message "[BEGIN] Starting the Function Set-SecurityMeasure"
        $PSBoundParameters.Remove('Force') | Out-Null
        $PSBoundParameters.Remove('Encrypt') | Out-Null
        $PSBoundParameters.Confirm = $False
    }#BEGIN
	
    PROCESS
    {
        Write-Verbose -Message "[PROCESS]"
        IF ( $Force -or $pscmdlet.ShouldProcess("$Path", "Setting Restricted ACL"))
        {
            #Get-Acl - Store the ACL 
            $acl = Get-Acl -Path $Path

            #Remove Inherited Rules and protect the rules from being changed by inheritance
            $acl.SetAccessRuleProtection($True, $False)
			
            #Purge all the exisiting ACEs inside the ACL 
            $acl.Access | ForEach-Object -Process {$acl.PurgeAccessRules($_.IdentityReference)}

            #set the User running the Script as the owner
            Write-Verbose -Message "[PROCESS] Setting the $env:Username as the Owner for the $Path"
            $acl.SetOwner([System.Security.Principal.NTAccount]"$env:username")

            #Give the Owner the Full access on the Folder
            $dirAce = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList "$env:Username","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow"
            $acl.AddAccessRule($dirAce)
            
            #now compare the Access on the Path to the Access we are giving...if there is a change then only set it
            IF ((Compare-Object -ReferenceObject (Get-Acl -Path $Path).access  -DifferenceObject $acl.access) -or ($acl.Owner -ne (Get-acl -Path $Path).owner ))
            {
                #set the ACL Now as it seems to be modified
                Write-Verbose -Message "[PROCESS] Setting the modified ACL to the $Path"
                Set-Acl @PSBoundParameters -AclObject $acl 
            }#END IF

            IF ($Encrypt)
            {
                Write-Verbose -Message "[PROCESS] Checkig if the folder $Path is encrypted now"
                IF ((Get-ItemProperty -Path $Path).attributes -match "Encrypted")
                {
                    Write-Verbose -Message "[PROCESS] The Folder $Path is already encrypted"
                } #End IF
                ELSE
                {
                   TRY
                   { 
                        Write-Verbose -Message "[PROCESS] Trying to Encrypt the $Path"
                        #Set ErrorActionPreference to Stop to catch exceptions from cipher.exe
                        $ErrorActionPreference = 'stop'
                        & cipher.exe /E $Path  
                        Write-Verbose -Message "[PROCESS] The folder $Path has been encrypted"
                   }#TRY
                   CATCH
                   {
                        Write-Warning -Message "[PROCESS] Something went wrong while trying to encrypt $path"
                        Write-Error -message  $($_.exception )
                   }#End Catch
                }#end Else
            }#End IF

        }#End IF
        
    }#End PROCESS
    END
    {
        Write-Verbose -Message "[END] Ending the Function Set-SecurityMeasure"
    }#END
}#Function Set-SecurityMeasure

#endregion Set-SecurityMeasure
