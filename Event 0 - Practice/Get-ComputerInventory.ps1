<#
# TO DO
-Should OS and SP being imported from the list of IP ?
-Validate Parameter
-Files: Validate Naming Convention accepted by Windows ([A-Z]|[a-z]|[0-9]|_|-|\.|\s)+
-if WSMAN (v3) fail, fall back on DCOM, fallback on pssession (wsman v2)
-LogPath parameter ?
-Save in CSV format, one file per computer COMPUTERNAME_Inventory_YYYYMMDD-HHMMSS.csv
-lastbootuptime does not seem accurate
-Job ? workflow (parallele work)?
-File format should include ? LR LP HW APP CMPNT
-win32_product
-localdisk: Where-Object {$_.InterfaceType -like "IDE"}	|
-Put the full cmdlet name + full parameter
#>


function Get-ComputerInventory {
<#
	.SYNOPSIS
		Get-ComputerInventory function retrieve inventory information from one or multiple computers.

	.DESCRIPTION
		Get-ComputerInventory function retrieve inventory information from one or multiple computers.

	.PARAMETER  ComputerName
		Specifies Defines the ComputerName

	.PARAMETER  Path
		Specifies the Path where to export the data from each computer
		The default filename used by the script is: Inventory-<COMPUTERNAME>-yyyyMMdd_hhmmss.xml
	
	.PARAMETER  Protocol
		Specifies the protocol to use to establish the connection with the remote computer(s)
		If not specified the script will try first with WSMAN then with DCOM
	
	.PARAMETER  AllInformation
		Gather all information related to the computer
		All information include: Hardware, Last Patch Installed, Last Reboot, Application Installed and Windows Components
	
	.PARAMETER  HardwareInformation
		Gather information related to the Hardware
	
	.PARAMETER  LastPatchInstalled
		Gather information on the last patch installed
	
	.PARAMETER  LastReboot
		Gather information of the last reboot
	
	.PARAMETER  ApplicationsInstalled
		Verify if IIS, SQL, Sharepoint or Exchange is installed
	
	.PARAMETER  WindowsComponents
		Gather the Windows Features installed on the computer
	
	.PARAMETER  Credential
		Specifies different credential to use

	.EXAMPLE
		Get-ComputerInventory -ComputerName LOCALHOST
	
		ComputerName                               Connectivity
		------------                               ------------
		LOCALHOST                                  Online
	
		This example shows what return the cmdlet using only the ComputerName parameter.
	
	.EXAMPLE
		Get-ComputerInventory -ComputerName SERVER01 -HardwareInformation
	
		Manufacturer       : System manufacturer
		LocalDisks         : @{DeviceID=\\.\PHYSICALDRIVE0; SizeGB=111.79}
		ComputerName       : SERVER01
		MemoryGB           : 4.00
		NumberOfProcessors : 1
		Model              : System Product Name
		Connectivity       : Online
	
		This example shows what return the cmdlet using the switch HardwareInformation.


	.OUTPUTS
		PsCustomObject
		CliXML file

	.NOTES
		Winter Scripting Games 2014
		Event 0 - Practice Event
		Title: Server Inventory
		Team: POSH Monks
#>

	[CmdletBinding(DefaultParameterSetName="AllInformation")]
	PARAM(
		[Alias("__SERVER","CN","ServerName")]
		[Parameter(
			Position=0,
			ValueFromPipeline,
			ValueFromPipelineByPropertyName,
			Mandatory,
			HelpMessage="Specify one or more ComputerName(s) (Netbios name, FQDN, or IP Address)")]
		[String[]]$ComputerName,
	
		[Alias("RunAs")]
		[System.Management.Automation.Credential()]
		$Credential = [System.Management.Automation.PSCredential]::Empty,
	
		[Alias("Destination","DestinationPath")]
		[ValidateScript(
			# Validate the Path specified by the user
			{Test-Path -path $_ })]
		[String]$Path,
	
		[Parameter()]
		[ValidateSet("WSMAN","DCOM")]
		[String]$Protocol,
	
		[Parameter(
			ParameterSetName="AllInformation")]
		[Switch]$AllInformation,
		
		[Parameter(
			ParameterSetName="Information")]
		[Switch]$HardwareInformation,
		
		[Parameter(
			ParameterSetName="Information")]
		[Switch]$LastPatchInstalled,
	
		[Parameter(
			ParameterSetName="Information")]
		[Switch]$LastReboot,
		
		[Parameter(
			ParameterSetName="Information")]
		[Switch]$ApplicationsInstalled,
	
		[Parameter(
			ParameterSetName="Information")]
		[Switch]$WindowsComponents
	)#PARAM
	
	BEGIN {
		TRY {
			# Verify CimCmdlets is loaded (CIM is loaded by default)
			#IF(-not(Get-Module -Name CimCmdlets -ErrorAction Stop | Out-Null)){Import-Module -Name CimCmdlets}
		}#TRY Block
		CATCH {
		}#CATCH Block
		
	}#BEGIN Block
	
	
	PROCESS {
		FOREACH ($Computer in $ComputerName){
			
			# Define Splatting
			$CIMSessionParams = @{
				ComputerName 	= $Computer
				ErrorAction 	= 'Stop'
				ErrorVariable	= 'ProcessErrorCIM'
			}
			
			TRY {
				
				# Connectivity
                Write-Verbose -Message "$Computer - Testing Connection..."
                Test-Connection -ComputerName $Computer -count 1 -ErrorAction Stop -ErrorVariable ProcessErrorTestConnection | Out-Null
								
				# Credential
				IF ($PSBoundParameters['Credential']) {$CIMSessionParams.credential = $Credential}
				
				# Protocol not specified
				IF (-not($PSBoundParameters['Protocol'])){
					# Trying with WsMan protocol
					Write-Verbose -Message "$Computer - Trying to connect via WSMAN protocol"
					IF ((Test-WSMan -ComputerName $Computer -ErrorAction SilentlyContinue).productversion -match 'Stack: 3.0'){
						Write-Verbose -Message "$Computer - WSMAN is responsive"
            			$CimSession = New-CimSession @CIMSessionParams
            			$CimProtocol = $CimSession.protocol
            			Write-Verbose -message "$Computer - [$CimProtocol] CIM SESSION - Opened"
					}#IF
					ELSE{
						# Trying with DCOM protocol
						Write-Verbose -message "$Computer - WSMAN protocol does not work, failing back to DCOM"
            			Write-Verbose -Message "$Computer - Trying to connect via DCOM protocol"
	            		$CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
	            		$CimSession = New-CimSession @CIMSessionParams
	            		$CimProtocol = $CimSession.protocol
	            		Write-Verbose -message "$Computer - [$CimProtocol] CIM SESSION - Opened"
					}#ELSE
				}#IF Block
				
				
				# Protocol Specified
				IF ($PSBoundParameters['Protocol']){
					SWITCH ($protocol) {
						"WSMAN" {
							Write-Verbose -Message "$Computer - Trying to connect via WSMAN protocol"
							IF ((Test-WSMan -ComputerName $Computer -ErrorAction Stop -ErrorVariable ProcessErrorTestWsMan).productversion -match 'Stack: 3.0') {
								Write-Verbose -Message "$Computer - WSMAN is responsive"
		            			$CimSession = New-CimSession @CIMSessionParams
		            			$CimProtocol = $CimSession.protocol
		            			Write-Verbose -message "$Computer - [$CimProtocol] CIM SESSION - Opened"
							}
						}
						"DCOM" {
							Write-Verbose -Message "$Computer - Trying to connect via DCOM protocol"
		            		$CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
		            		$CimSession = New-CimSession @CIMSessionParams
		            		$CimProtocol = $CimSession.protocol
		            		Write-Verbose -message "$Computer - [$CimProtocol] CIM SESSION - Opened"
						}
					}
				}
				
				# Prepare Output Variable
				$Inventory = @{
					ComputerName = $Computer
					Connectivity = 'Online'
				}
		
				# AllInformation Switch Parameter
				IF ($AllInformation){
					$HardwareInformation = $true
					$ApplicationsInstalled = $true
					$LastPatchInstalled = $true
					$LastReboot = $true
					$WindowsComponents = $true
				}
				
				# HardwareInformation Switch Parameter
				IF ($HardwareInformation) {
					Write-Verbose -Message "$Computer - Gather Hardware Information"	
				
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
				IF ($LastPatchInstalled) {
					Write-Verbose -Message "$Computer - Gather Last Patch Installed"
					
					# Get the information from win32_quickfixengineering
					$LastPatchesInstalled = Get-CimInstance -CimSession $CimSession -ClassName Win32_QuickFixEngineering #-Property InstalledOn
					
					# Send the Information to the $Inventory object
					$Inventory.LastPatchInstalled = $LastPatchesInstalled | Sort-Object -Property InstalledOn -Descending | Select-Object -Property HotFixID,Caption,Description -first 1
				}#IF ($LastPatchInstalled)
				
				
				# LastReboot Switch Parameter
				IF ($LastReboot) {
					Write-Verbose -Message "$Computer - Gather Last Reboot DateTime"
					
					# Get the information from Win32_OperatingSystem
					$OperatingSystem = Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem -Property LastBootUpTime
					# Send the information to the array
					$Inventory.LastReboot = $OperatingSystem.LastBootUpTime
				}#IF ($LastReboot)
				
				
				# ApplicationInstalled Switch Parameter
				IF ($ApplicationsInstalled) {
					Write-Verbose -Message "$Computer - Gather Application Installed"
					
					# Get the information from Win32_OperatingSystem
					#$Services = Get-CimInstance -CimSession $CimSession -ClassName win32_service
					$Services = Get-CimInstance -CimSession $CimSession -ClassName Win32_Service #-Property Name,State,Status
					
					# Send the Information to the $Inventory object for each application
					$Inventory.SQLInstalled = IF ($Services | Where-Object {$_.name -like 'sqlserver*'}){$true} ELSE {$false} # SQL Service Check
					$Inventory.IISInstalled = IF ($Services | Where-Object {$_.name -like 'iisadmin*'}){$true} ELSE {$false} # IIS Service Check
					$Inventory.SharepointInstalled = IF ($Services | Where-Object {$_.name -like '*sharepoint*'}){$true} ELSE {$false}# Sharepoint Service Check
					$Inventory.ExchangeInstalled = IF ($Services | Where-Object {$_.name -like '*msexchange*'}){$true} ELSE {$false}# Exchange Service Check
				}#IF ($ApplicationInstalled)
				
				
				# WindowsComponents Switch Parameter
				IF ($WindowsComponents) {
					Write-Verbose -Message "$Computer - Gather Windows Components Installed"
					
					# Get the information from Win32_OptionalFeature
					$WindowsFeatures = Get-CimInstance -CimSession $CimSession -ClassName Win32_OptionalFeature #-Property Caption
					
					# Send the Information to the $Inventory object
					$Inventory.WindowsComponents = $WindowsFeatures | Select-Object -Property Name,Caption
				}#IF ($WindowsComponents)
				
				
				# Output to the console
				Write-Verbose -Message "$Computer - Output information"
				[pscustomobject]$Inventory
				
				
				# Output to a XML file
				IF ($PSBoundParameters['Path']) {
					$DateFormat = Get-Date -Format 'yyyyMMdd_HHmmss'
					$FileFormat = "Inventory-$Computer-$DateFormat.xml"
					Write-Verbose -Message "$Computer - Output Data to a XML file: $fileformat"
					[pscustomobject]$Inventory | Export-Clixml -Path (Join-Path -Path $Path -ChildPath $FileFormat) -ErrorAction 'Stop' -ErrorVariable ProcessErrorExportCLIXML		
				}#IF ($PSBoundParameters['Path'])
				
			}#TRY Block
			
			CATCH {
				IF ($ProcessErrorTestConnection){Write-Warning -Message "$Computer - Can't Reach"}
				IF ($ProcessErrorCIM){Write-Warning -Message "$Computer - Can't Connect - $protocol"}
				IF ($ProcessErrorTestWsMan){Write-Warning -Message "$Computer - Can't Connect - $protocol"}
				IF ($ProcessErrorExportCLIXML){Write-Warning -Message "$Computer - Can't Export the XML file $fileformat in $Path"}
			}#CATCH Block
			
			FINALLY{
				Write-Verbose "Removing CIM 3.0 Session from $Computer"
                IF ($CimSession) {Remove-CimSession $CimSession}
			}#FINALLY Block
			
		}#FOREACH Block
	}#PROCESS Block
	
	
	
	END {
		TRY {
		}#TRY Block
		CATCH {
		}#CATCH Block
	}#END Block
}#Function Get-ComputerInventory
