# Reusing some of FX's work :)

Function Get-SensitiveInformation {
    [cmdletbinding()]
    Param(
        [Parameter(
                  Mandatory,
                  ValueFromPipeline,
                  ValueFromPipelineByPropertyName)]
                [Array]$ComputerInput,
        
        [Parameter()]
        [ValidateSet("WSMAN","DCOM")]
        [String]$Protocol,

        [Alias("RunAs")]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        Write-Verbose -Message "[BEGIN] Sensitive Information processing has started"

        # No specified protocols?
        If (-not($PSBoundParameters['Protocol'])){
            $SelectedProtocol = "WSMAN", "DCOM"
        } else {
            $SelectedProtocol = $Protocol
        }

        # Expression to get some registry values
        $GetRemoteRegistryValues = {
            $item = Get-Item HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\run

            $item | Select-Object -ExpandProperty Property | ForEach-Object {
                Write-Output (New-Object -TypeName PSCustomObject -Property @{ Name = $_; Value = $item.GetValue($_)})
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

            $Path | ForEach-Object {
                if (!($Found -contains $_.PSChildName)) {
                    if ($_.Property -contains "DisplayName") { $ProductLabel = $_.GetValue("DisplayName") } else { $ProductLabel = $_.PSChildName }
                    Write-Output (New-Object -TypeName PSCustomObject -Property @{ Name = $_.PSChildName; Label = $ProductLabel })
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

                If (Test-Path $Folder) {
                    # We retrieve the content of the given folder
                    $Content = Get-ChildItem $Folder -Recurse -ErrorAction SilentlyContinue

                    # We retrieve the size of that folder - TODO try catch on empty folders, if only folders -> 0mb
                    $Size = $Content | Measure-Object -Property Length -Sum
                    $Size = "{0:N2}" -f ($Size.Sum / 1MB) + " MB"

                    # We retrieve the amount of Files present within the root folder
                    $FilesCount = $Content.Length

                    $Scan.Size = $Size
                    $Scan.FilesCount = $FilesCount

                    # Deep scan?
                    If ($DeepScan) {
                        $Content | Where-Object {-not $_.PSIsContainer} | ForEach-Object {
                            $File = $_ | Select FullName, Length, LastWriteTime
                            $Hash = ""

                            If ($HashFiles) {
                                $Crypto = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider

                                #todo: try catch for file in use-->Exception calling "Open" with "3" argument(s): "The process cannot access the file 'C
                                Try {
                                    $Hash = [System.BitConverter]::ToString($Crypto.ComputeHash([System.IO.File]::Open($File.FullName,[System.IO.Filemode]::Open, [System.IO.FileAccess]::Read))) | Out-Null
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

                    Write-Output $Scan
                } else {
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

                Write-Output (New-Object -TypeName PSCustomObject -Property @{ 
                    Computer = $Computer; 
                    EnvironmentVars = $RemoteEnv;
                    Services = $RemoteServices;
                    Process = $RemoteProcess;
                    Shares = $RemoteShares;
                    RegistryRun = $RemoteRegistry;
                    Products = $RemoteProducts;
                    Folders = $RemoteFolders })
            } Catch {
                If ($ProcessErrorTestConnection){ Write-Warning -Message "[PROCESS] Computer Unreachable: $Computer" }
                write-host $error[0] # debug
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
