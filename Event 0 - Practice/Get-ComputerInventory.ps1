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

#Using the Below Function from poshcode.org
Function Split-Job
{
    <#
    .Synopsis
       Run commands in multiple concurrent pipelines.
    .DESCRIPTION
       The Function takes a Command, Scriptblock or Function and splits and works by creating multiple runspaces.
       So that a single Command, Scriptblock or Function can be run against multiple computers in parallel without remoting enabled. 
       The MaxPipelines parameter controls the number of simultaneous runspaces
   
    .EXAMPLE
        Functions/Cmdlets that accept pipeline input with Split-Job
        PS C:\>  Get-Content hosts.txt | Split-Job {Test-MyFunction} 
    .EXAMPLE
       Functions/Cmdlets that don't accept a pipeline input
        PS C:\> Get-Content hosts.txt |% { .\MyScript.ps1 -ComputerName $_ }
    .EXAMPLE
       Specify the IPaddress and mask separately (Non-CIDR notation)
         function Test-Function ($ComputerName) {
               Get-WMIObject -Class Win32_Bios -Computername $Computername
         }
         Get-Content hosts.txt | Split-Job {%{Test-Function -Computername $_ }} -Function Test-Function
    .EXAMPLE
         Using Split-Job , When the ScriptBlock or Function requires cmdlet in a Module
         Get-Content Users.txt | Split-Job { % { Get-ADUser -Identity $_ } } -InitializeScript { Import-Module ActiveDirectory }
    .INPUTS
       System.object[]
    .OUTPUTS
       Depends on the Command, Function or Scriptblock executing using Split-Job
    .NOTES
       Author - Arnoud Jansveld
       Version History
         1.2    Changes by Stephen Mills - stephenmills at hotmail dot com
                Only works with PowerShell V2
                Modified error output to use ErrorRecord parameter of Write-Error - catches Category Info then.
                Works correctly in powershell_ise.  Previous version would let pipelines continue if ESC was pressed.  If Escape pressed, then it will do an async cancel of the pipelines and exit.
                Add seconds remaining to progress bar
                Parameters Added and related functionality:
                   InitializeScript - allows to have custom scripts to initilize ( Import-Module ...), parameter might be renamed Begin in the future.
                   MaxDuration - Cancel all pending and in process items in queue if the number of seconds is reached before all input is done.
                   ProgressInfo - Allows you to add additional text to progress bar
                   NoProgress - Hide Progress Bar
                   DisplayInterval - frequency to update Progress bar in milliseconds
                   InputObject - not yet used, planned to be used in future to support start processing the queue before pipeline isn't finished yet
                Added example for importing a module.
         1.0    First version posted on poshcode.org
                Additional runspace error checking and cleanup
         0.93   Improve error handling: errors originating in the Scriptblock now
                have more meaningful output
                Show additional info in the progress bar (thanks Stephen Mills)
                Add SnapIn parameter: imports (registered) PowerShell snapins
                Add Function parameter: imports functions
                Add SplitJobRunSpace variable; allows scripts to test if they are
                running in a runspace
         0.92   Add UseProfile switch: imports the PS profile
                Add Variable parameter: imports variables
                Add Alias parameter: imports aliases
                Restart pipeline if it stops due to an error
                Set the current path in each runspace to that of the calling process
         0.91   Revert to v 0.8 input syntax for the script block
                Add error handling for empty input queue
         0.9    Add logic to distinguish between scriptblocks and cmdlets or scripts:
                if a ScriptBlock is specified, a foreach {} wrapper is added
         0.8    Adds a progress bar
         0.7    Stop adding runspaces if the queue is already empty
         0.6    First version. Inspired by Gaurhoth's New-TaskPool script

    .LINK
        http://www.jansveld.net/powershell

    #>
	param (
		[Parameter(Position=0, Mandatory=$true)]$Scriptblock,
		[Parameter()][int]$MaxPipelines=10,
		[Parameter()][switch]$UseProfile,
		[Parameter()][string[]]$Variable,
		[Parameter()][string[]]$Function = @(),
		[Parameter()][string[]]$Alias = @(),
		[Parameter()][string[]]$SnapIn,
		[Parameter()][float]$MaxDuration = $( [Int]::MaxValue ),
		[Parameter()][string]$ProgressInfo ='',
		[Parameter()][int]$ProgressID = 0,
		[Parameter()][switch]$NoProgress,
		[Parameter()][int]$DisplayInterval = 300,
		[Parameter()][scriptblock]$InitializeScript,
		[Parameter(ValueFromPipeline=$true)][object[]]$InputObject
	)

	begin
	{
		$StartTime = Get-Date
		#$DisplayTime = $StartTime.AddMilliseconds( - $DisplayInterval )
		$ExitForced = $false


		 function Init ($InputQueue){
			# Create the shared thread-safe queue and fill it with the input objects
			$Queue = [Collections.Queue]::Synchronized([Collections.Queue]@($InputQueue))
			$QueueLength = $Queue.Count
			# Do not create more runspaces than input objects
			if ($MaxPipelines -gt $QueueLength) {$MaxPipelines = $QueueLength}
			# Create the script to be run by each runspace
			$Script  = "Set-Location '$PWD'; "
			$Script += {
				$SplitJobQueue = $($Input)
				& {
					trap {continue}
					while ($SplitJobQueue.Count) {$SplitJobQueue.Dequeue()}
				} }.ToString() + '|' + $Scriptblock

			# Create an array to keep track of the set of pipelines
			$Pipelines = New-Object System.Collections.ArrayList

			# Collect the functions and aliases to import
			$ImportItems = ($Function -replace '^','Function:') +
				($Alias -replace '^','Alias:') |
				Get-Item | select PSPath, Definition
			$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
		}

		 function Add-Pipeline {
			# This creates a new runspace and starts an asynchronous pipeline with our script.
			# It will automatically start processing objects from the shared queue.
			$Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($Host)
			$Runspace.Open()
			if (!$?) { throw "Could not open runspace!" }
			$Runspace.SessionStateProxy.SetVariable('SplitJobRunSpace', $True)

			function CreatePipeline
			{
				param ($Data, $Scriptblock)
				$Pipeline = $Runspace.CreatePipeline($Scriptblock)
				if ($Data)
				{
					$Null = $Pipeline.Input.Write($Data, $True)
					$Pipeline.Input.Close()
				}
				$Null = $Pipeline.Invoke()
				$Pipeline.Dispose()
			}

			# Optionally import profile, variables, functions and aliases from the main runspace
			
			if ($UseProfile)
			{
				CreatePipeline -Script "`$PROFILE = '$PROFILE'; . `$PROFILE"
			}

			if ($Variable)
			{
				foreach ($var in (Get-Variable $Variable))
				{
					trap {continue}
					$Runspace.SessionStateProxy.SetVariable($var.Name, $var.Value)
				}
			}
			if ($ImportItems)
			{
				CreatePipeline $ImportItems {
					foreach ($item in $Input) {New-Item -Path $item.PSPath -Value $item.Definition}
				}
			}
			if ($SnapIn)
			{
				CreatePipeline (Get-PSSnapin $Snapin -Registered) {$Input | Add-PSSnapin}
			}
			
			#Custom Initialization Script for startup of Pipeline - needs to be after other other items added.
			if ($InitializeScript -ne $null)
			{
				CreatePipeline -Scriptblock $InitializeScript
			}

			$Pipeline = $Runspace.CreatePipeline($Script)
			$Null = $Pipeline.Input.Write($Queue)
			$Pipeline.Input.Close()
			$Pipeline.InvokeAsync()
			$Null = $Pipelines.Add($Pipeline)
		}

		function Remove-Pipeline ($Pipeline)
		{
			# Remove a pipeline and runspace when it is done
			$Pipeline.RunSpace.CloseAsync()
			#Removed Dispose so that Split-Job can be quickly aborted even if currently running something waiting for a timeout.
			#Added call to [System.GC]::Collect() at end of script to free up what memory it can.
			#$Pipeline.Dispose()
			$Pipelines.Remove($Pipeline)
		}
	}

	end
	{
		
		# Main
		# Initialize the queue from the pipeline
		. Init $Input
		# Start the pipelines
		try
		{
			while ($Pipelines.Count -lt $MaxPipelines -and $Queue.Count) {Add-Pipeline}

			# Loop through the pipelines and pass their output to the pipeline until they are finished
			while ($Pipelines.Count)
			{
				# Only update the progress bar once per $DisplayInterval
				if (-not $NoProgress -and $Stopwatch.ElapsedMilliseconds -ge $DisplayInterval)
				{
					$Completed = $QueueLength - $Queue.Count - $Pipelines.count
					$Stopwatch.Reset()
					$Stopwatch.Start()
					#$LastUpdate = $stopwatch.ElapsedMilliseconds
					$PercentComplete = (100 - [Int]($Queue.Count)/$QueueLength*100)
					$Duration = (Get-Date) - $StartTime
					$DurationString = [timespan]::FromSeconds( [Math]::Floor($Duration.TotalSeconds)).ToString()
					$ItemsPerSecond = $Completed / $Duration.TotalSeconds
					$SecondsRemaining = [math]::Round(($QueueLength - $Completed)/ ( .{ if ($ItemsPerSecond -eq 0 ) { 0.001 } else { $ItemsPerSecond}}))
					
					Write-Progress -Activity "** Split-Job **  *Press Esc to exit*  Next item: $(trap {continue}; if ($Queue.Count) {$Queue.Peek()})" `
						-status "Queues: $($Pipelines.Count) QueueLength: $($QueueLength) StartTime: $($StartTime)  $($ProgressInfo)" `
						-currentOperation  "$( . { if ($ExitForced) { 'Aborting Job!   ' }})Completed: $($Completed) Pending: $($QueueLength- ($QueueLength-($Queue.Count + $Pipelines.Count))) RunTime: $($DurationString) ItemsPerSecond: $([math]::round($ItemsPerSecond, 3))"`
						-PercentComplete $PercentComplete `
						-Id $ProgressID `
						-SecondsRemaining $SecondsRemaining
				}	
				foreach ($Pipeline in @($Pipelines))
				{
					if ( -not $Pipeline.Output.EndOfPipeline -or -not $Pipeline.Error.EndOfPipeline)
					{
						$Pipeline.Output.NonBlockingRead()
						$Pipeline.Error.NonBlockingRead() | % { Write-Error -ErrorRecord $_ }

					} else
					{
						# Pipeline has stopped; if there was an error show info and restart it			
						if ($Pipeline.PipelineStateInfo.State -eq 'Failed')
						{
							Write-Error $Pipeline.PipelineStateInfo.Reason
							
							# Restart the runspace
							if ($Queue.Count -lt $QueueLength) {Add-Pipeline}
						}
						Remove-Pipeline $Pipeline
					}
					if ( ((Get-Date) - $StartTime).TotalSeconds -ge $MaxDuration -and -not $ExitForced)
					{
						Write-Warning "Aborting job! The MaxDuration of $MaxDuration seconds has been reached. Inputs that have not been processed will be skipped."
						$ExitForced=$true
					}
					
					if ($ExitForced) { $Pipeline.StopAsync(); Remove-Pipeline $Pipeline }
				}
				while ($Host.UI.RawUI.KeyAvailable)
				{
					if ($Host.ui.RawUI.ReadKey('NoEcho,IncludeKeyDown,IncludeKeyUp').VirtualKeyCode -eq 27 -and !$ExitForced)
					{
						$Queue.Clear();
						Write-Warning 'Aborting job! Escape pressed! Inputs that have not been processed will be skipped.'
						$ExitForced = $true;
						#foreach ($Pipeline in @($Pipelines))
						#{
						#	$Pipeline.StopAsync()
						#}
					}		
				}
				if ($Pipelines.Count) {Start-Sleep -Milliseconds 50}
			}

			#Clear the Progress bar so other apps don't have to keep seeing it.
			Write-Progress -Completed -Activity "`0" -Status "`0"

			# Since reference to Dispose was removed.  I added this to try to help with releasing resources as possible.
			# This might be a bad idea, but I'm leaving it in for now. (Stephen Mills)
			[GC]::Collect()
		}
		finally
		{
			foreach ($Pipeline in @($Pipelines))
			{
				if ( -not $Pipeline.Output.EndOfPipeline -or -not $Pipeline.Error.EndOfPipeline)
				{
					Write-Warning 'Pipeline still runinng.  Stopping Async.'
					$Pipeline.StopAsync()
					Remove-Pipeline $Pipeline
				}
			}
		}
	}
}




function Get-ComputerInventory {
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
		[Switch]$WindowsComponents,
	
        [PSDefaultValue(Help = 'No of Runspaces to open.')]
        $ThrottleLimit = 10
	)#PARAM
	BEGIN {
		TRY {
			Function Get-ComputerInformation {
			<#
				.SYNOPSIS
					Get-ComputerInformation function retrieve inventory information from one or multiple computers.

				.DESCRIPTION
					Get-ComputerInformation function retrieve inventory information from one or multiple computers.

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
					Get-ComputerInformation -ComputerName LOCALHOST
				
					ComputerName                               Connectivity
					------------                               ------------
					LOCALHOST                                  Online
				
					This example shows what return the cmdlet using only the ComputerName parameter.
				
				.EXAMPLE
					Get-ComputerInformation -ComputerName SERVER01 -HardwareInformation
				
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
			}#Function Get-ComputerInformation
		}
		CATCH {
			Write-Warning -Message "BEGIN BLOCK - Something Wrong happened"
			$Error[0]
		}
	}
	PROCESS {
		TRY {
			Split-Job -Scriptblock {Get-ComputerInformation @PSBoundParameters} -Function Get-ComputerInformation -MaxPipelines $ThrottleLimit -Variable $PSBoundParameters
		}
		CATCH {
			Write-Warning -Message "PROCESS BLOCK - Something Wrong happened"
			$Error[0]
		}
	}
	END {
		TRY {
		}
		CATCH {
			Write-Warning -Message "END BLOCK - Something Wrong happened"
			$Error[0]
		}
	}
}