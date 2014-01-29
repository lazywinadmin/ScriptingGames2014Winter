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
        $GetRemoteInstalledProduct = {
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

                $RemoteProducts = Invoke-Command -Computer $Computer -ScriptBlock $GetRemoteInstalledProduct -Credential $Credential | Select-Object Name, Label | Sort-Object Label
                
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
