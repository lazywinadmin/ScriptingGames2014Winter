# Put all the functions in this file

function Test-IsAdministrator
{ 
    <# 
    .SYNOPSIS 
        Tests if the user is an administrator 
    .DESCRIPTION
        Returns true if a user is an administrator, false if the user is not an administrator         
    .EXAMPLE
        Test-IsAdministrator
	
		This will return $true or $false
    #>
    (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

<#
  Requires -RunAsAdministrator
  Requires -Version 4
#>

Function Get-XMlDifference {
    [CmdletBinding()]
    PARAM(
        [Parameter(mandatory=$true,position=0)]
        [ValidateScript({Test-Path -Path $_})]
        $ReferenceObject,
	
        [Parameter(mandatory=$true,position=1)]
        [ValidateScript({Test-Path -Path $_})]
        $DifferenceObject
    )#PARAM

    BEGIN{}#BEGIN
    PROCESS{
		TRY
		{
	        #Getting the XML content to compare
	        $ContentReference = Get-Content -Path $ReferenceObject
	        $contentDifference = Get-Content -path $differenceObject
	        
			#Getting differences
	        $Differences = Compare-Object -ReferenceObject $ContentReference -DifferenceObject $contentDifference -CaseSensitive -ErrorAction Stop -ErrorVariable ErrorProcessCompare| Where-Object {$_.sideIndicator -eq "=>"} | Select-Object -Property Inputobject
	       
			#Retrieving line informations
	        $String = Select-String -SimpleMatch -CaseSensitive '$($Differences.Inputobject)' -Path $ReferenceObject
	        $Return = 	[pscustomobject]@{
							"LineContent"=$Differences.Inputobject;
							"LineNumber"=$String.LineNumber
						}#$Return
		}#TRY
		CATCH
		{
			Write-Warning -Message "[PROCESS] Something went wrong"
			IF ($ErrorProcessCompare) {Write-Warning -Message "[PROCESS] Error while comparing the 2 Objects"}
			Write-Warning -Message $Error[0]
		}#CATCH

    }#PROCESS
    END{
        Write-Output -InputObject $Return
    }#END
}#Get-XMlDifference

#$ReferenceObject = "C:\Users\gulicst1\SkyDrive\Scripting\Githhub\WinterScriptingGames2014\WinterScriptingGames2014\Event 2 - Security Footprint\Reference.config"
#$differenceObject = "C:\Users\gulicst1\SkyDrive\Scripting\Githhub\WinterScriptingGames2014\WinterScriptingGames2014\Event 2 - Security Footprint\Difference.config"

#Get-XMlDifference -ReferenceObject $ReferenceObject -differenceObject $differenceObject

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
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
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
		TRY{
	        Write-Verbose -Message "[PROCESS]"
	        IF ( $Force -or $pscmdlet.ShouldProcess("$Path", "Setting Restricted ACL"))
	        {
	            #Get-Acl - Store the ACL 
	            $acl = Get-Acl -Path $Path -ErrorAction Stop -ErrorVariable ErrorProcessGetAcl

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
	            IF ((Compare-Object -ReferenceObject (Get-Acl -Path $Path -ErrorAction Stop -ErrorVariable ErrorProcessGetAclRefObj).access  -DifferenceObject $acl.access) -or ($acl.Owner -ne (Get-acl -Path $Path -ErrorAction Stop -ErrorVariable ErrorProcessGetAclDifObj).owner ))
	            {
	                #set the ACL Now as it seems to be modified
	                Write-Verbose -Message "[PROCESS] Setting the modified ACL to the $Path"
	                Set-Acl @PSBoundParameters -AclObject $acl -ErrorAction 'Stop' -ErrorVariable ErrorProcessSetAcl
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
		}#TRY
		CATCH
		{
			Write-Warning -Message "[PROCESS] Something went wrong"
			IF($ErrorProcessGetAcl){Write-Warning -Message "[PROCESS] Error while getting the ACL"}
			IF($ErrorProcessGetAclRefObj){Write-Warning -Message "[PROCESS] Error while getting the ACL of the Reference Object"}
			IF($ErrorProcessGetAclDifObj){Write-Warning -Message "[PROCESS] Error while getting the ACL of the Difference Object"}
			IF($ErrorProcessSetAcl){Write-Warning -Message "[PROCESS] Error while setting the ACL"}
			Write-Warning -Message $Error[0]
		}
        
    }#End PROCESS
    END
    {
        Write-Verbose -Message "[END] Ending the Function Set-SecurityMeasure"
    }#END
}#Function Set-SecurityMeasure
