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

function Get-SensitiveInformation {
    [CmdletBinding()]
    Param(
        [Parameter(
                  Mandatory,
                  ValueFromPipeline,
                  ValueFromPipelineByPropertyName)]
                [Array]$ComputerInput,
        
        [Alias("Destination","DestinationPath")]
        [Parameter(
                  Mandatory)]
        [ValidateScript({Test-Path -Path $_ })]
                [Array]$Path,

        [Parameter()]
        [ValidateSet("WSMAN","DCOM")]
        [String]$Protocol,

        [Alias("RunAs")]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        Write-Verbose -Message "[BEGIN] Sensitive Information processing has started"

        $ExecutionTime = Get-Date -Format 'yyyyMMdd_HHmmss'

        # No specified protocols?
        If (-not($PSBoundParameters['Protocol'])){
            $SelectedProtocol = "WSMAN", "DCOM"
        } else {
            $SelectedProtocol = $Protocol
        }

        # Expression to get some registry values
        $GetRemoteRegistryValues = {
            $RegistryItems=	"HKLM:\\Software\Microsoft\Windows\CurrentVersion\Run",
							"HKLM:\\Software\Microsoft\Windows\CurrentVersion\RunOnce",
							"HKLM:\\Software\Microsoft\Windows\CurrentVersion\RunOnceEx",
							"HKLM:\\Software\Microsoft\Windows\CurrentVersion\RunServices",
							"HKLM:\\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce",
							"HKLM:\\Software\Microsoft\WindowsNT\CurrentVersion\Winlogon",
							"HKCU:\\Software\Microsoft\Windows\CurrentVersion\Run",
							"HKCU:\\Software\Microsoft\Windows\CurrentVersion\RunOnce",
							"HKCU:\\Software\Microsoft\Windows\CurrentVersion\RunOnceEx",
							"HKCU:\\Software\Microsoft\Windows\CurrentVersion\RunServices",
							"HKCU:\\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce",
							"HKCU:\\Software\Microsoft\WindowsNT\CurrentVersion\Winlogon"
							
            Get-Item -Path $Registryitems -ErrorAction 'SilentlyContinue' | Select-Object -ExpandProperty Property | ForEach-Object -Process {
                Write-Output -InputObject (New-Object -TypeName PSCustomObject -Property @{ Name = $_; Value = $item.GetValue($_)})
            }
        }

        # Expression to get the installed product, we do not use Win32_Product due to it's odd behaviour (check and repair) and due to it's speed
        $GetRemoteInstalledProducts = {
            $Uninstallx86 = "\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
            $Uninstallx64 = "\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
            
            $Found = @()

            $Path = @(
                if (Test-Path "HKLM:$Uninstallx86" ) { Get-ChildItem "HKLM:$Uninstallx86"}
                if (Test-Path "HKLM:$Uninstallx64" ) { Get-ChildItem "HKLM:$Uninstallx64"}
                if (Test-Path "HKCU:$Uninstallx86" ) { Get-ChildItem "HKCU:$Uninstallx86"}
                if (Test-Path "HKCU:$Uninstallx64" ) { Get-ChildItem "HKCU:$Uninstallx64"}
            )

            $Path | ForEach-Object -Process {
                IF (!($Found -contains $_.PSChildName)) {
                    IF ($_.Property -contains "DisplayName") { $ProductLabel = $_.GetValue("DisplayName") } ELSE { $ProductLabel = $_.PSChildName }
                    Write-Output -InputObject (New-Object -TypeName PSCustomObject -Property @{ Name = $_.PSChildName; Label = $ProductLabel })
                    $Found += $_.PSChildName
                }
            }
        }

        # Expression to get the given folder's content along with their properties
        $GetRemoteFoldersProperties = {
            # http://blogs.technet.com/b/heyscriptingguy/archive/2012/05/31/use-powershell-to-compute-md5-hashes-and-find-changed-files.aspx
            Param(
                $Folders
            )
            
            $DeepScan = $true
            $HashFiles = $true

            ForEach ($Folder in $Folders) {
                $Scan = New-Object -TypeName PSCustomObject -Property @{
                    Folder = $Folder
                    Size = 0
                    FilesCount = 0
                    Details = @()
                }

                If (Test-Path -Path $Folder) {
                    # We retrieve the content of the given folder
                    $Content = Get-ChildItem -Path $Folder -Recurse -ErrorAction SilentlyContinue

                    # We retrieve the size of that folder - TODO try catch on empty folders, if only folders -> 0mb
                    $Size = Measure-Object -Property Length -Sum -InputObject $Content
                    $Size = "{0:N2}" -f ($Size.Sum / 1MB) + " MB"

                    # We retrieve the amount of Files present within the root folder
                    $FilesCount = $Content.Length

                    $Scan.Size = $Size
                    $Scan.FilesCount = $FilesCount

                    # Deep scan?
                    If ($DeepScan) {
                        $Content | Where-Object {-not $_.PSIsContainer} | ForEach-Object -Process {
                            $File = $_ | Select-Object -Property FullName, Length, LastWriteTime
                            $Hash = ""

                            If ($HashFiles) {
                                $Crypto = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider

                                #todo: try catch for file in use-->Exception calling "Open" with "3" argument(s): "The process cannot access the file 'C
                                Try {
                                    $Hash = [System.BitConverter]::ToString($Crypto.ComputeHash([System.IO.File]::Open($File.FullName,[System.IO.Filemode]::Open, [System.IO.FileAccess]::Read)))
                                } Catch {
                                    Write-Warning -Message "[PROCESS] Unable to hash File: $($File.FullName)"
                                }
                            }
                            
                            $Scan.Details += New-Object -TypeName PSCustomObject -Property @{
                                File = $File.FullName
                                Size = "{0:N8}" -f ($File.Length / 1MB) + " MB"
                                LastModified = $File.LastWriteTime
                                Hash = $Hash
                            }
                        }
                    }

                    Write-Output -InputObject $Scan
                } ELSE {
                    Write-Warning -Message "[PROCESS] Folder $Folder does not exist on the current system"
                }
            }
        }

        # The folders that we want to scan
        #$Folders = "C:\WINDOWS\System32"

        $Folders = "C:\applics"
    }

    PROCESS {
        # Iterate through all given computers
        ForEach ($Computer in $ComputerInput) {
            Try {
                Write-Verbose -Message "[PROCESS] Processing Computer: $Computer"

                $CIMSessionParams = @{
                    ComputerName = $Computer
                    ErrorAction = 'Stop'
                    ErrorVariable = 'ProcessErrorCIM'
                }
                
                # Try to connect to the computer first
                Test-Connection -ComputerName $Computer -count 1 -ErrorAction Stop -ErrorVariable ProcessErrorTestConnection | Out-Null

                # Credentials were specified?
                If ($PSBoundParameters['Credential']) {$CIMSessionParams.credential = $Credential}
                
                # WSMAN connection
                If ($SelectedProtocol -contains "WSMAN") {
                    Write-Verbose -Message "[PROCESS] Attempting to connect with protocol: WSMAN"

                    If ((Test-WSMan -ComputerName $Computer -ErrorAction SilentlyContinue).ProductVersion -match 'Stack: 3.0'){
                        Write-Verbose -Message "[PROCESS] WSMAN is responsive"
                        $CimSession = New-CimSession @CIMSessionParams
                        $CimProtocol = $CimSession.protocol
                        Write-Verbose -Message "[PROCESS] [$CimProtocol] CIM SESSION - Opened"
                    } else {
                        Write-Warning -Message "[PROCESS] The WSMAN stack does not match the minimum stack version"
                    }
                }

                # DCOM connection
                If (($SelectedProtocol -contains "DCOM") -and !($CimSession)) {
                    Write-Verbose -Message "[PROCESS] Attempting to connect with protocol: DCOM"
                    $CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
                    $CimSession = New-CimSession @CIMSessionParams
                    $CimProtocol = $CimSession.protocol

                    Write-Verbose -Message "[PROCESS] [$CimProtocol] CIM SESSION - Opened"
                }

                # Information - Environment variables
                Write-Verbose -Message "[PROCESS] Attempting to retrieve: Environment Variables"

                $RemoteEnv = Get-CimInstance -CimSession $CimSession -ClassName Win32_Environment -Property Name, UserName, VariableValue | Select-Object Name, UserName, VariableValue

                # Information - Running Services
                Write-Verbose -Message "[PROCESS] Attempting to retrieve: Running Services"

                $RemoteServices = Get-CimInstance -CimSession $CimSession -ClassName Win32_Service -Filter "State='Running'" -Property Name | Select-Object Name

                # Information - Process
                Write-Verbose -Message "[PROCESS] Attempting to retrieve: Running Process"

                $RemoteProcess = Get-CimInstance -CimSession $CimSession -ClassName Win32_Process -Property Name | Select-Object Name

                # Information - SMB Shares
                Write-Verbose -Message "[PROCESS] Attempting to retrieve: Shares"

                $RemoteShares = Get-CimInstance -CimSession $CimSession -ClassName Win32_Share -Property Name, Path, Description | Select-Object Name, Path, Description

                # Information - Registry
                Write-Verbose -Message "[PROCESS] Attempting to retrieve: Registry Values"

                $RemoteRegistry = Invoke-Command -Computer $Computer -ScriptBlock $GetRemoteRegistryValues -Credential $Credential | Select-Object Name, Value

                # Information - Installed Products
                Write-Verbose -Message "[PROCESS] Attempting to retrieve: Installed Products"

                $RemoteProducts = Invoke-Command -Computer $Computer -ScriptBlock $GetRemoteInstalledProducts -Credential $Credential | Select-Object Name, Label | Sort-Object Label

                # Information - Folders
                Write-Verbose -Message "[PROCESS] Attempting to retrieve: Folders... this may take a while"
                
                $RemoteFolders = Invoke-Command -Computer $Computer -ScriptBlock $GetRemoteFoldersProperties -Credential $Credential -ArgumentList (,$Folders)
                #$RemoteFolders


                # Finally we export the object as an XML
                $FileOutput = "$($Path)\SensitiveInfo_$($Computer)_$($ExecutionTime).xml"

                New-Object -TypeName PSCustomObject -Property @{ 
                    Computer = $Computer; 
                    EnvironmentVars = $RemoteEnv;
                    Services = $RemoteServices;
                    Process = $RemoteProcess;
                    Shares = $RemoteShares;
                    RegistryRun = $RemoteRegistry;
                    Products = $RemoteProducts;
                    Folders = $RemoteFolders 
                } | Export-Clixml -Path $FileOutput

            } Catch {
				Write-Warning -Message "[PROCESS] Something went wrong"
                If ($ProcessErrorTestConnection){ Write-Warning -Message "[PROCESS] Computer Unreachable: $Computer" }
                Write-Warning -Message $error[0] # debug
            } Finally {
                If ($CimSession) {
                    Write-Verbose "[PROCESS] Removing CIM Session from: $Computer"
                    Remove-CimSession $CimSession
                }
            }
        }
    }

    END {
        Write-Verbose -Message "[END] Sensitive Information processing has ended"
    }
}

# "10.246.41.8", "10.246.41.9" | Get-SensitiveInformation -Verbose -Protocol DCOM -Credential $credentials
#Get-SensitiveInformation -Computer "10.246.41.8" -Verbose -Protocol DCOM -Credential $credentials
