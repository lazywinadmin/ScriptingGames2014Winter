#TO DO:
# Function Get-ValidIPAddressinRange -- returns all possible IP address in the Range specified
# Leverage Split-Job Function to speed-up performance
# Used the Split-Job ....trying to understand how it works and probably improve it with verbose messages
# How to use ??
#Get-ValidIPAddressinRange -IP 10.1.1.1 -mask 255.255.255.0 | split-job -MaxPipelines 50 { ForEach-Object -Process { Get-OSInfo -IPAddress $_ -Verbose }} -Function Get-OSInfo

#Using the Below Function from poshcode.org
function Split-Job
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

function Get-ValidIPAddressinRange
{
<#
.Synopsis
   Takes the IP Address and the Mask value as input and returns all possible IP
.DESCRIPTION
   The Function takes the IPAddress and the Subnet mask value to generate list of all possible IP addresses in the Network.
   
.EXAMPLE
    Specify the IPaddress in the CIDR notation
    PS C:\> Get-IPAddressinNetwork -IP 10.10.10.0/24
.EXAMPLE
   Specify the IPaddress and mask separately (Non-CIDR notation)
    PS C:\> Get-IPAddressinNetwork -IP 10.10.10.0 -Mask 24
.EXAMPLE
   Specify the IPaddress and mask separately (Non-CIDR notation)
    PS C:\> Get-IPAddressinNetwork -IP 10.10.10.0 -Mask 255.255.255.0
.INPUTS
   System.String
.OUTPUTS
   [System.Net.IPAddress[]]
.NOTES
   General notes
.LINK
    http://www.indented.co.uk/index.php/2010/01/23/powershell-subnet-math/

#>
    [CmdletBinding(DefaultParameterSetName='CIDR', 
                  SupportsShouldProcess=$true, 
                  ConfirmImpact='low')]
    [OutputType([ipaddress[]])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false 
                    )]
        [ValidateScript({
                        if ($_.contains("/"))
                            { # if the specified IP format is -- 10.10.10.0/24
                                $temp = $_.split('/')   
                                If (([ValidateRange(0,32)][int]$subnetmask = $temp[1]) -and ([bool]($temp[0] -as [ipaddress])))
                                {
                                    Return $true
                                }
                            }                           
                        else
                        {# if the specified IP format is -- 10.10.10.0 (along with this argument to Mask parameter is also provided)
                            if ( [bool]($_ -as [ipaddress]))
                            {
                                return $true
                            }
                            else
                            {
                                throw "IP validation failed"
                            }
                        }
                        })]
        [Alias("IPAddress","NetworkRange")] 
        [string]$IP,

        # Param2 help description
        [Parameter(ParameterSetName='Non-CIDR')]
        [ValidateScript({
                        if ($_.contains("."))
                        { #the mask is in the dotted decimal 255.255.255.0 format
                            if (! [bool]($_ -as [ipaddress]))
                            {
                                throw "Subnet Mask Validation Failed"
                            }
                            else
                            {
                                return $true 
                            }
                        }
                        else
                        { #the mask is an integer value so must fall inside range [0,32]
                           # use the validate range attribute to verify it falls under the range
                            if ([ValidateRange(0,32)][int]$subnetmask = $_ )
                            {
                                return $true
                            }
                            else
                            {
                                throw "Invalid Mask Value"
                            }
                        }
                        
                         })]
        [string]$mask
    )

    Begin
    {
        Write-Verbose -message "Get-ValidIPAddressinRange : Function Starting"
        #region Function Definitions
        
        Function ConvertTo-DecimalIP {
          <#
            .Synopsis
              Converts a Decimal IP address into a 32-bit unsigned integer.
            .Description
              ConvertTo-DecimalIP takes a decimal IP, uses a shift-like operation on each octet and returns a single UInt32 value.
            .Parameter IPAddress
              An IP Address to convert.
          #>
   
          [CmdLetBinding()]
          [OutputType([UInt32])]
          Param(
            [Parameter(Mandatory,ValueFromPipeline)]
            [Net.IPAddress]$IPAddress
          )
 
          Process 
          {
            $i = 3; $DecimalIP = 0;
            $IPAddress.GetAddressBytes() | ForEach-Object { $DecimalIP += $_ * [Math]::Pow(256, $i); $i-- }
 
            Write-Output -inputobject $([UInt32]$DecimalIP)
          }
        }

        Function ConvertTo-DottedDecimalIP {
          <#
            .Synopsis
              Returns a dotted decimal IP address from either an unsigned 32-bit integer or a dotted binary string.
            .Description
              ConvertTo-DottedDecimalIP uses a regular expression match on the input string to convert to an IP address.
            .Parameter IPAddress
              A string representation of an IP address from either UInt32 or dotted binary.
          #>
 
          [CmdLetBinding()]
          [OutputType([ipaddress])]
          Param(
            [Parameter(Mandatory, ValueFromPipeline)]
            [String]$IPAddress
          )
   
          Process {
            Switch -RegEx ($IPAddress) 
            {
              "([01]{8}\.){3}[01]{8}" 
              {
                Return [String]::Join('.', $( $IPAddress.Split('.') | ForEach-Object { [Convert]::ToUInt32($_, 2) } ))
              }

              "\d" 
              {
                $IPAddress = [UInt32]$IPAddress
                $DottedIP = $( For ($i = 3; $i -gt -1; $i--) {
                  $Remainder = $IPAddress % [Math]::Pow(256, $i)
                  ($IPAddress - $Remainder) / [Math]::Pow(256, $i)
                  $IPAddress = $Remainder
                 } )
        
                Write-Output -inputobject $([ipaddress]([String]::Join('.', $DottedIP)))
              }

              default 
              {
                Write-Error -Message "Cannot convert this format"
              }
            }
          }
    }
         #endregion Function Definitions
    }

    Process
    {
        Switch($PSCmdlet.ParameterSetName)
        {
            "CIDR"
            {
                Write-Verbose -message "Get-ValidIPAddressinRange : Get-ValidIPAddressinRange : Inside CIDR Parameter Set"
                $temp = $ip.Split("/")
                $ip = $temp[0]
                 #The validation attribute on the parameter takes care if this is empty
                $mask = ConvertTo-DottedDecimalIP ([Convert]::ToUInt32($(("1" * $temp[1]).PadRight(32, "0")), 2))                            
            }

            "Non-CIDR"
            {
                Write-Verbose -message "Get-ValidIPAddressinRange : Inside Non-CIDR Parameter Set"
                If (!$Mask.Contains("."))
                  {
                    $mask = ConvertTo-DottedDecimalIP ([Convert]::ToUInt32($(("1" * $mask).PadRight(32, "0")), 2))
                  }

            }
        }
        #now we have appropraite dotted decimal ip's in the $ip and $mask
        $DecimalIP = ConvertTo-DecimalIP -IPAddress $ip
        $DecimalMask = ConvertTo-DecimalIP $Mask

        #Do a Binary AND to get the Network ID and 
        $Network = $DecimalIP -BAnd $DecimalMask
        $Broadcast = $DecimalIP -BOr ((-BNot $DecimalMask) -BAnd [UInt32]::MaxValue)

        For ($i = $($Network + 1); $i -lt $Broadcast; $i++) {
            ConvertTo-DottedDecimalIP $i
          }
                       
            
    }
    End
    {
        Write-Verbose -message "Get-ValidIPAddressinRange : Function Ending"
    }
}

function Get-OSInfo
{
	<#
		.SYNOPSIS
			Gets the OS and SP Info for an IP Address.

		.DESCRIPTION
			The Function takes an IP Address as a Input and then queries the DNS Server.
            It uses GetHostEntry() static method in [system.net.dns] class to resolve an IP address to Hostname.
            It records both positive and negative of the above method.
            If the machine resolves to a hostname it checks if the machine is online/offline recording both states.
            If the machine is online it uses the 

		.PARAMETER  IPAddress
			Takes the IPAddress Object as input. Designed to work with the Get-ValidIPAddress output

		.PARAMETER  Credential
			Specify the Credentials to use to query Remote machines (using WMI)

		.EXAMPLE
			Gets the ComputerName, OS and SP info for the IP Address 10.1.1.1
            PS C:\> Get-OSInfo -IPAddress 10.1.1.1

		.EXAMPLE
			You can pipe the IP Address to the Function.
            PS C:\> "10.1.1.1","10.1.1.2" | Get-OSInfo


            IPAddress    : 10.1.1.1
            ComputerName : dex.com
            OS           : Microsoft Windows Server 2012 R2 Datacenter Preview
            ServicePack  : 
            Online       : True

            IPAddress    : 10.1.1.2
            ComputerName : dexsccm
            OS           : 
            ServicePack  : 
            Online       : False


		.INPUTS
			System.Net.IPAddress[]

		.OUTPUTS
			System.Management.Automation.PSObject[]

		.NOTES
			Designed to work with IP Address only.

	#>
	[CmdletBinding()]
	[OutputType([PSObject])]
	param(
		[Parameter(Position=0, Mandatory,
                    ValueFromPipeline,
                    ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[System.net.IPAddress[]]
		[Alias("IP")]
		$IPAddress,

        [Alias("RunAs")]
		[System.Management.Automation.Credential()]
		$Credential = [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter()]
		[ValidateSet("WSMAN","DCOM")]
		[String]$Protocol
		
	)
	Begin
	{
		Write-Verbose -Message "Get-OSInfo : Starting the Function"
		Write-Verbose -Message "Get-OSInfo : Loading Function Resolve-IPAddress definition"
		Function Resolve-IPAddress
	    {
	      [CmdLetBinding()]
	          [OutputType([bool])]
	          Param(
	            [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
	            [ipaddress]$IPAddress
	          )
	        #try to resolve the IPAddress to a host name...return true if it resolves otherwise false
	        try 
	        {
				# Add a note property to the IPAddress object if the machine name resolves..
                $hostname = ([System.Net.Dns]::GetHostEntry("$IPAddress")).HostName
	            Add-Member -MemberType NoteProperty -Name ComputerName -Value $hostname  -InputObject $IPAddress -Force
	 			Write-Output $true 
	        }
	        catch
	        {
	            Write-Warning "$IPAddress not resolving to a hostname"
	            Write-Output $false
	        }

	    }
	
	}
	Process
	{
		foreach ($Ip in $IPAddress)
        {
            Write-Verbose -Message "Get-OSInfo : Working with IP Address - $IP"
            
			
		    if (Resolve-IPAddress -IPAddress $IP)
		    {
			    #IP Address resolves to a Hostname
                Write-Verbose -Message "Get-OSInfo : $IP is resolving to a hostname $IP.ComputerName"
			    Write-Verbose -Message "Get-OSInfo : Testing if the $IP.Computername is online"
                
                
                # Define Splatting
			    $CIMSessionParams = @{
				    ComputerName 	= $IP.Computername 
				    ErrorAction 	= 'Stop'
				    ErrorVariable	= 'ProcessErrorCIM'
			    }
			
			    
                TRY {
				    # Prepare Output Variable
			        $Output = @{
				        IPAddress = $IP.IPAddressToString
                        ComputerName = $IP.ComputerName
				        Connectivity = 'Online'
			        }

				    # Connectivity
                    Write-Verbose -Message "Get-OSInfo : $IP.Computername - Testing Connection..."
                    Test-Connection -ComputerName $IP.ComputerName -count 1 -ErrorAction Stop -ErrorVariable ProcessErrorTestConnection | Out-Null
				
                				
				    # Credential
				    IF ($PSBoundParameters['Credential']) {$CIMSessionParams.credential = $Credential}
				
				    # Protocol not specified
				    IF (-not($PSBoundParameters['Protocol'])){
					    # Trying with WsMan protocol
					    Write-Verbose -Message "Get-OSInfo : $IP.ComputerName - Trying to connect via WSMAN protocol"
					    IF ((Test-WSMan -ComputerName $IP.ComputerName -ErrorAction SilentlyContinue).productversion -match 'Stack: 3.0'){
						    Write-Verbose -Message "Get-OSInfo : $IP.ComputerName - WSMAN is responsive"
            			    $CimSession = New-CimSession @CIMSessionParams
            			    $CimProtocol = $CimSession.protocol
            			    Write-Verbose -message "Get-OSInfo : $IP.ComputerName - [$CimProtocol] CIM SESSION - Opened"
					    }#IF
					    ELSE{
						    # Trying with DCOM protocol
						    Write-Verbose -message "Get-OSInfo : $IP.ComputerName - WSMAN protocol does not work, failing back to DCOM"
            			    Write-Verbose -Message "Get-OSInfo : $IP.ComputerName - Trying to connect via DCOM protocol"
	            		    $CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
	            		    $CimSession = New-CimSession @CIMSessionParams
	            		    $CimProtocol = $CimSession.protocol
	            		    Write-Verbose -message "Get-OSInfo : $IP.ComputerName - [$CimProtocol] CIM SESSION - Opened"
					    }#ELSE
				    }#IF Block
				
				
				    # Protocol Specified
				    IF ($PSBoundParameters['Protocol']){
					    SWITCH ($protocol) {
						    "WSMAN" {
							    Write-Verbose -Message "Get-OSInfo : $IP.ComputerName - Trying to connect via WSMAN protocol"
							    IF ((Test-WSMan -ComputerName $IP.ComputerName -ErrorAction Stop -ErrorVariable ProcessErrorTestWsMan).productversion -match 'Stack: 3.0') {
								    Write-Verbose -Message "Get-OSInfo : $IP.ComputerName - WSMAN is responsive"
		            			    $CimSession = New-CimSession @CIMSessionParams
		            			    $CimProtocol = $CimSession.protocol
		            			    Write-Verbose -message "Get-OSInfo : $IP.ComputerName - [$CimProtocol] CIM SESSION - Opened"
							    }
						    }
						    "DCOM" {
							    Write-Verbose -Message "Get-OSInfo : $IP.ComputerName - Trying to connect via DCOM protocol"
		            		    $CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
		            		    $CimSession = New-CimSession @CIMSessionParams
		            		    $CimProtocol = $CimSession.protocol
		            		    Write-Verbose -message "Get-OSInfo : $IP.ComputerName - [$CimProtocol] CIM SESSION - Opened"
						    }
					    }
				    }
				
                
                    #get the Information from Win32_OperatingSystem
                    $OSInfo = Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem

                    $Output.Protocol = $CimProtocol
                    $Output.OS = $OSInfo.Caption
                    $Output.ServicePack = $OSInfo.CSDversion

                    Write-Verbose -Message "Get-OSInfo : $IP.Computername - Output information"
                    [pscustomobject]$Output
                }
                
			    CATCH {
				    IF ($ProcessErrorTestConnection)
                    {
                        #Machine name resolves but Machine is offline
                        Write-Warning -Message "Get-OSInfo : $IP.ComputerName - Can't Reach"
                        $Output.Connectivity = "Offline"
                        
                        Write-Verbose -Message "Get-OSInfo : $IP.Computername - Output information"
                        [pscustomobject]$Output
                    }
				    IF ($ProcessErrorCIM)
                    {
                        #Machine name resolved and machine is online but Not able to Query it
                        Write-Warning -Message "Get-OSInfo : $IP.ComputerName - Can't Connect - $protocol"
                        
                        Write-Verbose -Message "Get-OSInfo : $IP.Computername - Output information"
                        [pscustomobject]$Output
                    }
				    IF ($ProcessErrorTestWsMan){Write-Warning -Message "Get-OSInfo : $IP.ComputerName - Can't Connect - $protocol"}
				    #IF ($ProcessErrorExportCLIXML){Write-Warning -Message "$IP.ComputerName - Can't Export the XML file $fileformat in $Path"}
			    }#CATCH Block
			
			    FINALLY{
				    Write-Verbose "Get-OSInfo : Removing CIM 3.0 Session from $IP.ComputerName"
                    IF ($CimSession) {Remove-CimSession $CimSession}
			    }#FINALLY Block

	}
	        
            else
            {
                Write-Verbose -Message "Get-OSInfo : $IP not resolving"
                [pscustomobject]@{IPAddress=$Ip.IPAddressToString} 
            }
	
    }
    
    }
    End
	{
        Write-Verbose -Message "Get-OSInfo : Ending the Function"
	       
    }
}
