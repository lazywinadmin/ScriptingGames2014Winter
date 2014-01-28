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
                #Invoke-command -Computer $Computer {Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\run} -Credential $Credential
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
