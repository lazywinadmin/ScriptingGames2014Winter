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


WorkFlow Get-ComputerInventory {
	
	#.ExternalHelp Get-ComputerInventory.xml
	[CmdletBinding()]
	PARAM(
	    [Alias("__SERVER","CN","ServerName")]
		[Parameter(
			Position=0,
			ValueFromPipeline,
			ValueFromPipelineByPropertyName,
			Mandatory,
			HelpMessage="Specify one or more ComputerName(s) (Netbios name, FQDN, or IP Address)")]
		#[ValidatePattern('^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$')]
		[String[]]$ComputerName,

		# Some Credential Help
		[Alias("RunAs")]
	    [System.Management.Automation.PSCredential]$Credential,
		
		[ValidateSet("WSMAN","DCOM")]
		[string]$Protocol,
	
		[ValidateScript(
			# Validate the Path specified by the user
			{Test-Path -path $_ })]
		[string]$Path,
	    [switch]$HardwareInformation,
		[Switch]$LastPatchInstalled,
		[Switch]$LastReboot,
		[Switch]$ApplicationsInstalled,
		[Switch]$WindowsComponents
    )#PARAM Block
	
    FOREACH -Parallel ($Computer in $ComputerName) {
	    INLINESCRIPT {
	        TRY {
	            # Splatting CIM Parameters
				$CIMSessionParams = @{
	                ComputerName 	= $using:Computer
	                ErrorAction 	= 'Stop'
	                ErrorVariable	= 'ProcessErrorCIM'
	                }
	            
				# Connectivity
	            Write-Verbose -Message "$using:Computer - Testing Connection..."
	            Test-Connection -ComputerName $using:Computer -count 1 -Quiet -ErrorAction Stop -ErrorVariable ProcessErrorTestConnection | Out-Null
	            
				# Credential
	            IF ($Credential) {$CIMSessionParams.credential = $Credential}
	            
	            # Protocol
	            IF (-not($using:Protocol)){
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
				IF ($using:Protocol){
					SWITCH ($using:Protocol) {
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
				
				
				# LastPatchInstalled Switch Parameter
				IF ($using:LastPatchInstalled) {
					Write-Verbose -Message "$using:Computer - Gather Last Patch Installed"
					
					# Get the information from win32_quickfixengineering
					$LastPatchesInstalled = Get-CimInstance -CimSession $CimSession -ClassName Win32_QuickFixEngineering #-Property InstalledOn
					
					# Send the Information to the $Inventory object
					$Inventory.LastPatchInstalled = $LastPatchesInstalled | Sort-Object -Property InstalledOn -Descending | Select-Object -Property HotFixID,Caption,Description -first 1
				}#IF ($LastPatchInstalled)
				
				
				# LastReboot Switch Parameter
				IF ($using:LastReboot) {
					Write-Verbose -Message "$using:Computer - Gather Last Reboot DateTime"
					
					# Get the information from Win32_OperatingSystem
					$OperatingSystem = Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem -Property LastBootUpTime
					# Send the information to the array
					$Inventory.LastReboot = $OperatingSystem.LastBootUpTime
				}#IF ($LastReboot)
				
				
				# ApplicationInstalled Switch Parameter
				
				IF ($using:ApplicationsInstalled) {
					Write-Verbose -Message "$using:Computer - Gather Application Installed"
					
					# Get the information from Win32_OperatingSystem
					$Services = Get-CimInstance -CimSession $CimSession -ClassName Win32_Service
					
					# Send the Information to the $Inventory object for each application
					Write-Verbose -Message "Verifiying if SQL is present"
					$Inventory.SQLInstalled = IF ($Services | Where-Object {$_.name -like 'mssqlserver*' | Out-Null }){$true} ELSE {$false} # SQL Service Check
					Write-Verbose -Message "Verifying if IIS is present"
					$Inventory.IISInstalled = IF ($Services | Where-Object {$_.name -like 'iisadmin*' | Out-Null }){$true} ELSE {$false} # IIS Service Check
					Write-Verbose -Message "Verifying if Sharepoint is Present"
					$Inventory.SharepointInstalled = IF ($Services | Where-Object {$_.name -like '*sharepoint*' | Out-Null }){$true} ELSE {$false}# Sharepoint Service Check
					Write-Verbose -Message "Verifying if Exchange is Present"
					$Inventory.ExchangeInstalled = IF ($Services | Where-Object {$_.name -like '*msexchange*' | Out-Null }){$true} ELSE {$false}# Exchange Service Check
				}#IF ($ApplicationInstalled)
			
				
				# WindowsComponents Switch Parameter
				IF ($using:WindowsComponents) {
					Write-Verbose -Message "$using:Computer - Gather Windows Components Installed"
					
					# Get the information from Win32_OptionalFeature
					$WindowsFeatures = Get-CimInstance -CimSession $CimSession -ClassName Win32_OptionalFeature #-Property Caption
					
					# Send the Information to the $Inventory object
					$Inventory.WindowsComponents = $WindowsFeatures | Select-Object -Property Name,Caption
				}#IF ($WindowsComponents)
				

		        # Output to the console
				Write-Verbose -Message "$using:Computer - Output information"
				[pscustomobject]$Inventory
				
				
				# Output to a XML file
				IF ($using:Path){
					Write-Verbose -Message "$using:Computer - Saving output to file"
					$DateFormat = Get-Date -Format 'yyyyMMdd_HHmmss'
					$FileFormat = "Inventory-$using:Computer-$DateFormat.xml"
					Write-Verbose -Message "$using:Computer - Output Data to a XML file: $((Join-Path -Path $using:Path -ChildPath $FileFormat))"
					[pscustomobject]$Inventory | Export-Clixml -Path (Join-Path -Path $using:Path -ChildPath $FileFormat) -ErrorAction 'Stop' -ErrorVariable ProcessErrorExportCLIXML
				}#IF ($PSBoundParameters['Path'])
				
				

	        }#TRY Block
	        CATCH {
	            $errorMessage = $Error[0].Exception
	            IF ($ProcessErrorTestConnection){Write-Warning -Message "$using:Computer - Can't Reach"}
				IF ($ProcessErrorCIM){Write-Warning -Message "$using:Computer - Can't Connect - $protocol"}
				IF ($ProcessErrorTestWsMan){Write-Warning -Message "$using:Computer - Can't Connect - $protocol"}
				IF ($ProcessErrorExportCLIXML){Write-Warning -Message "$using:Computer - Can't Export the XML file $fileformat in $Path"}
	        }#CATCH Block
	        FINALLY {

	        }#FINALLY Block
	    }#INLINESCRIPT
	}#FOREACH -Parallel ($Computer in $ComputerName)
}#WorkFlow Get-ComputerDetails

Get-ComputerInventory -ComputerName localhost -Verbose -HardwareInformation -ApplicationsInstalled -LastPatchInstalled -LastReboot
