<#

CIM
http://blogs.msdn.com/b/powershell/archive/2012/08/24/introduction-to-cim-cmdlets.aspx

WORKFLOW
http://blogs.technet.com/b/heyscriptingguy/archive/2012/12/26/powershell-workflows-the-basics.aspx
http://technet.microsoft.com/en-us/library/jj574157.aspx
http://stackoverflow.com/questions/11567920/catching-errors-in-workflows
http://technet.microsoft.com/en-us/library/jj134257.aspx

http://technet.microsoft.com/en-us/library/jj574123.aspx

http://blogs.technet.com/b/heyscriptingguy/archive/2012/11/20/use-powershell-workflow-to-ping-computers-in-parallel.aspx
#>


workflow Get-ComputerDetails {
param(
    [string[]]$computers,
    [System.Management.Automation.PSCredential]$Credential,
    [switch]$HardwareInformation,
    [string]$Protocol
    )
    ForEach -parallel ($computer in $computers) {
    InlineScript {
        Try {
            $CIMSessionParams = @{
                ComputerName 	= $using:Computer
                ErrorAction 	= 'Stop'
                ErrorVariable	= 'ProcessErrorCIM'
                }
            # Connectivity
            Write-Verbose -Message "$using:Computer - Testing Connection..."

            Test-Connection -ComputerName $using:Computer -count 1 -Quiet -ErrorAction Stop -ErrorVariable ProcessErrorTestConnection | Out-Null

            Write-Verbose -Message "$using:Computer - Testing Connection..."
            # Credential
            IF ($Credential) {$CIMSessionParams.credential = $Credential}
            
            # Protocol not specified
            IF (-not($protocol)){
				# Trying with WsMan protocol
				Write-Verbose -Message "$using:Computer - Trying to connect via WSMAN protocol"
				IF ((Test-WSMan -ComputerName $using:Computer -ErrorAction SilentlyContinue).productversion -match 'Stack: 3.0'){
					Write-Verbose -Message "$using:Computer - WSMAN is responsive"
            		$CimSession = New-CimSession @CIMSessionParams
            		$CimProtocol = $CimSession.protocol
            		Write-Verbose -message "$using:Computer - [$CimProtocol] CIM SESSION - Opened"
				} #IF
				ELSE{
					# Trying with DCOM protocol
					Write-Verbose -message "$using:Computer - WSMAN protocol does not work, failing back to DCOM"
            		Write-Verbose -Message "$using:Computer - Trying to connect via DCOM protocol"
	            	$CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
	            	$CimSession = New-CimSession @CIMSessionParams
	            	$CimProtocol = $CimSession.protocol
	            	Write-Verbose -message "$using:Computer - [$CimProtocol] CIM SESSION - Opened"
				}#ELSE
			}#IF Block
				
				
			# Protocol Specified
			IF ($using:Protocol){
				SWITCH ($using:protocol) {
					"WSMAN" {
						Write-Verbose -Message "$using:Computer - Trying to connect via WSMAN protocol"
						IF ((Test-WSMan -ComputerName $using:Computer -ErrorAction Stop -ErrorVariable ProcessErrorTestWsMan).productversion -match 'Stack: 3.0') {
							Write-Verbose -Message "$using:Computer - WSMAN is responsive"
		            		$CimSession = New-CimSession @CIMSessionParams
		            		$CimProtocol = $CimSession.protocol
		            		Write-Verbose -message "$Computer - [$CimProtocol] CIM SESSION - Opened"
						}
					}
					"DCOM" {
						Write-Verbose -Message "$using:Computer - Trying to connect via DCOM protocol"
		            	$CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
		            	$CimSession = New-CimSession @CIMSessionParams
		            	$CimProtocol = $CimSession.protocol
		            	Write-Verbose -message "$using:Computer - [$CimProtocol] CIM SESSION - Opened"
					}
				}
			}
			# Prepare Output Variable
			$Inventory = @{
				ComputerName = $using:Computer
				Connectivity = 'Online'
			}

			# HardwareInformation Switch Parameter
			IF ($using:HardwareInformation) {
				Write-Verbose -Message "$using:Computer - Gather Hardware Information"	
				
				# Get the information from Win32_ComputerSystem
				$ComputerSystem = Get-CimInstance -CimSession $CimSession -ClassName win32_ComputerSystem #-Property Manufacturer,Model,TotalPhysicalMemory,NumberOfProcessors
					
				# Get the information from Win32_diskdrive
				$DiskDrive = Get-CimInstance -CimSession $CimSession -ClassName win32_diskdrive # -Property Size
					
				# Send the Information to the $Inventory object
				$Inventory.Manufacturer = $ComputerSystem.Manufacturer
				$Inventory.Model = $ComputerSystem.Model
				$Inventory.MemoryGB = "{0:N2}" -f ($ComputerSystem.TotalPhysicalMemory/1GB)
				$Inventory.NumberOfProcessors = $ComputerSystem.NumberOfProcessors
				$Inventory.LocalDisks = $DiskDrive | Select-Object -Property DeviceID,@{Label="SizeGB";Expression={"{0:N2}" -f ($_.Size/1GB)}},SerialNumber,Model,Manufacturer,InterfaceType
												
			}#IF ($HardwareInformation)
        # Output to the console
		Write-Verbose -Message "$using:Computer - Output information"
		[pscustomobject]$Inventory

        }
        Catch {
            $errorMessage = $Error[0].Exception
            IF ($ProcessErrorTestConnection){Write-Warning -Message "$using:Computer - Can't Reach"}
			IF ($ProcessErrorCIM){Write-Warning -Message "$using:Computer - Can't Connect - $protocol"}
			IF ($ProcessErrorTestWsMan){Write-Warning -Message "$using:Computer - Can't Connect - $protocol"}
			IF ($ProcessErrorExportCLIXML){Write-Warning -Message "$using:Computer - Can't Export the XML file $fileformat in $Path"}

        }
        Finally {

        }
        <#
        $output = [PSCustomObject]@{
            Name = $using:computer
            User = $response.UserName
            Error = $errorMessage
        }
        $output
        #>
    }
}#foreach
}#workflow

Get-ComputerDetails -computers 127.0.0.1,localhost,xavierdesktop -Verbose -HardwareInformation