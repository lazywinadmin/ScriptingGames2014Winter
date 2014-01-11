##########################
# SCAN IP RANGE
##########################
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
    SYNOPSIS
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

                Write-Verbose -Message "Get-OSInfo : $IP is resolving to a hostname $($IP.ComputerName)"

			    Write-Verbose -Message "Get-OSInfo : Testing if the $($IP.ComputerName) is online"

                

                

                # Define Splatting

			    $CIMSessionParams = @{

				    ComputerName 	= $($IP.ComputerName) 

				    ErrorAction 	= 'Stop'

				    ErrorVariable	= 'ProcessErrorCIM'

			    }

			

			    

                TRY {

				    # Prepare Output Variable

			        $Output = @{

				        IPAddress = $($IP.IPAddressToString)

                        ComputerName = $($IP.ComputerName)

				        Connectivity = 'Online'

			        }



				    # Connectivity

                    Write-Verbose -Message "Get-OSInfo : $($IP.ComputerName) - Testing Connection..."

                    Test-Connection -ComputerName $($IP.ComputerName) -count 1 -Quiet -ErrorAction Stop -ErrorVariable ProcessErrorTestConnection | Out-Null

				

                				

				    # Credential

				    IF ($PSBoundParameters['Credential']) {$CIMSessionParams.credential = $Credential}

				

				    # Protocol not specified

				    IF (-not($PSBoundParameters['Protocol'])){

					    # Trying with WsMan protocol

					    Write-Verbose -Message "Get-OSInfo : $($IP.ComputerName) - Trying to connect via WSMAN protocol"

					    IF ((Test-WSMan -ComputerName $($IP.ComputerName) -ErrorAction SilentlyContinue).productversion -match 'Stack: 3.0'){

						    Write-Verbose -Message "Get-OSInfo : $($IP.ComputerName) - WSMAN is responsive"

            			    $CimSession = New-CimSession @CIMSessionParams

            			    $CimProtocol = $CimSession.protocol

            			    Write-Verbose -message "Get-OSInfo : $($IP.ComputerName) - [$CimProtocol] CIM SESSION - Opened"

					    }#IF

					    ELSE{

						    # Trying with DCOM protocol

						    Write-Verbose -message "Get-OSInfo : $($IP.ComputerName) - WSMAN protocol does not work, failing back to DCOM"

            			    Write-Verbose -Message "Get-OSInfo : $($IP.ComputerName) - Trying to connect via DCOM protocol"

	            		    $CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom

	            		    $CimSession = New-CimSession @CIMSessionParams

	            		    $CimProtocol = $CimSession.protocol

	            		    Write-Verbose -message "Get-OSInfo : $($IP.ComputerName) - [$CimProtocol] CIM SESSION - Opened"

					    }#ELSE

				    }#IF Block

				

				

				    # Protocol Specified

				    IF ($PSBoundParameters['Protocol']){

					    SWITCH ($protocol) {

						    "WSMAN" {

							    Write-Verbose -Message "Get-OSInfo : $($IP.ComputerName) - Trying to connect via WSMAN protocol"

							    IF ((Test-WSMan -ComputerName $($IP.ComputerName) -ErrorAction Stop -ErrorVariable ProcessErrorTestWsMan).productversion -match 'Stack: 3.0') {

								    Write-Verbose -Message "Get-OSInfo : $($IP.ComputerName) - WSMAN is responsive"

		            			    $CimSession = New-CimSession @CIMSessionParams

		            			    $CimProtocol = $CimSession.protocol

		            			    Write-Verbose -message "Get-OSInfo : $($IP.ComputerName) - [$CimProtocol] CIM SESSION - Opened"

							    }

						    }

						    "DCOM" {

							    Write-Verbose -Message "Get-OSInfo : $($IP.ComputerName) - Trying to connect via DCOM protocol"

		            		    $CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom

		            		    $CimSession = New-CimSession @CIMSessionParams

		            		    $CimProtocol = $CimSession.protocol

		            		    Write-Verbose -message "Get-OSInfo : $($IP.ComputerName) - [$CimProtocol] CIM SESSION - Opened"

						    }

					    }

				    }

				

                

                    #get the Information from Win32_OperatingSystem

                    $OSInfo = Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem



                    $Output.Protocol = $CimProtocol

                    $Output.OS = $OSInfo.Caption

                    $Output.ServicePack = $OSInfo.CSDversion



                    Write-Verbose -Message "Get-OSInfo : $($IP.ComputerName) - Output information"

                    [pscustomobject]$Output

                }

                

			    CATCH {

				    IF ($ProcessErrorTestConnection)

                    {

                        #Machine name resolves but Machine is offline

                        Write-Warning -Message "Get-OSInfo : $($IP.ComputerName) - Can't Reach"

                        $Output.Connectivity = "Offline"

                        

                        Write-Verbose -Message "Get-OSInfo : $($IP.ComputerName) - Output information"

                        [pscustomobject]$Output

                    }

				    IF ($ProcessErrorCIM)

                    {

                        #Machine name resolved and machine is online but Not able to Query it

                        Write-Warning -Message "Get-OSInfo : $($IP.ComputerName) - Can't Connect - $protocol"

                        

                        Write-Verbose -Message "Get-OSInfo : $($IP.ComputerName) - Output information"

                        [pscustomobject]$Output

                    }

				    IF ($ProcessErrorTestWsMan){Write-Warning -Message "Get-OSInfo : $($IP.ComputerName) - Can't Connect - $protocol"}

				    

			    }#CATCH Block

			

			    FINALLY{

				    Write-Verbose "Get-OSInfo : Removing CIM 3.0 Session from $($IP.ComputerName)"

                    IF ($CimSession) {Remove-CimSession $CimSession}

			    }#FINALLY Block



	}

	

	

    }

    

    }

    End

	{

        Write-Verbose -Message "Get-OSInfo : Ending the Function"

	}

}



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



#region Get-ComputerInventory


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
		
		This function will ...
#>

	[CmdletBinding()]
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
		
		[Switch]$HardwareInformation,
		
		[Switch]$LastPatchInstalled,
	
		[Switch]$LastReboot,
	
		[Switch]$ApplicationsInstalled,
	
		[Switch]$WindowsComponents
	)
	
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
                Test-Connection -ComputerName $Computer -count 1 -Quiet -ErrorAction Stop -ErrorVariable ProcessErrorTestConnection | Out-Null
								
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


#endregion Get-ComputerInventory





#region Chart

#========================================================================
# 
# Created on:   1/5/2014 1:08 PM
# Created by:   Administrator
# Organization: 
# Filename:     
#========================================================================



Function New-Chart {
<#
        .SYNOPSIS
                        New-Chart

        .DESCRIPTION
                        This function creates Charts according to the given parameters. Charts are available as a byte array in the output

        .PARAMETER  Computers
                        This represents the computers object array which shall be analyzed.

        .PARAMETER  Path
                        This represents the path where the charts shall be created at.

        .PARAMETER  Roles
                        Create a chart about the computers Roles like IIS, SQL, Sharepoint or Exchange.

        .PARAMETER  Hardware
                        Create a chart about the computers Hardware such as the Manufacturer, the CPU...

        .PARAMETER  OS
                        Create a chart about the computers OS and Service Pack.

        .EXAMPLE
                        PS C:\> New-Chart -Computers $computers -Path "C:\ps" -Roles -OS -Hardware
                        Path                                                        Title
                        ----                                                        -----
                        C:\ps\Chart-Roles.png                                       Roles
                        C:\ps\CPU.png                                               CPU
                        C:\ps\MemoryGB.png                                          MemoryGB
                        C:\ps\Manufacturer.png                                      Manufacturer
                        C:\ps\Model.png                                             Model
                        C:\ps\ServicePack.png                                       ServicePack
                        ...
                        This example shows how to call the New-Chart function with named parameters.

        .INPUTS
                        TODO: Determine if object or object[]

        .OUTPUTS
                        System.Array

        .NOTES
                        This function rely on the .NET Framework version 4.0 or higher to generate graphical charts, 
                        MS Charts need to be installed for .NET versions which are below 4.0 such as 3.5

        .LINK
                        MS Charts: http://www.microsoft.com/en-us/download/details.aspx?id=14422

        .LINK
                        about_functions_advanced

        .LINK
                        about_comment_based_help

        .LINK
                        about_functions_advanced_parameters

        .LINK
                        about_functions_advanced_methods
#>
    [cmdletbinding()]
    Param(
        [Parameter(
                  Mandatory=$true,
                  Position=0)]
                [object]$Computers,
                
        [Parameter(
                  Mandatory=$true,
                  Position=1)]
                [object]$Path,
                
                [switch]$Roles,
                
                [switch]$Hardware,
                
                [switch]$OS
    )
        
        BEGIN {
                #--- Code: TODO: Check for .NET framework here
                
                Write-Verbose -Message "Loading the Data Visualization assembly"
                #--- Code: TODO: replace with add-type, partialname is meh
                [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
                
                [array]$output = @()
        }
        
        PROCESS {
                #--- Code: The roles need to be graphed
                if ($Roles) {
                        Write-Verbose -Message "Generating a chart for the roles"
                        
                        #--- Code: First, we create the chart object
                        $chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
                        $chart.BackColor = "White"
                        $chart.Width = 500
                        $chart.Height = 500
                        
                        #--- Code: We name our chart
                        [void]$chart.Titles.Add("Detected Roles")
                        $chart.Titles[0].Alignment = "topLeft"
                        $chart.Titles[0].Font = "Tahoma,13pt"
                        
                        #--- Code: We create the chart area
                        $chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
                        $chartarea.Name = "ChartArea1"
                        # $chartarea.Area3DStyle.Enable3D = $true
                        $chartarea.AxisX.Interval = 1
                        $chartarea.AxisX.MajorGrid.LineColor = "#d1d1d1"
                        $chartarea.AxisX.Title = "Role"
                        $chartarea.AxisY.Interval = 5
                        $chartarea.AxisY.MajorGrid.LineColor = "#d1d1d1"
                        $chartarea.AxisY.Title = "Count"
                        $chartarea.BackColor = "White"
                        $chartarea.BackGradientStyle = "DiagonalRight"
                        $chartarea.BackSecondaryColor = "#d3e6ff"
                        $chart.ChartAreas.Add($chartarea)
                        
                        #--- Code: We create the serie now
                        [void]$chart.Series.Add("Data")
                        $chart.Series["Data"].BorderColor = "#1062ba"
                        $chart.Series["Data"].BorderDashStyle="Solid"
                        $chart.Series["Data"].BorderWidth = 1
                        $chart.Series["Data"].ChartArea = "ChartArea1"
                        $chart.Series["Data"].ChartType = "Column"
                        $chart.Series["Data"].Color = "#6aaef7"
                        $chart.Series["Data"].IsValueShownAsLabel = $true
                        $chart.Series["Data"].IsVisibleInLegend = $true
                        
                        #--- Code: As we're dealing with multiple objects, we're grouping the properties and check which ones are considered true
                        $Computers | Group-Object -Property IISInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
                                [void]$chart.Series["Data"].Points.AddXY("IIS", $_.Count) 
                        }
                        $Computers | Group-Object -Property SQLInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
                                [void]$chart.Series["Data"].Points.AddXY("SQL", $_.Count) 
                        }
                        $Computers | Group-Object -Property ExchangeInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
                                [void]$chart.Series["Data"].Points.AddXY("Exchange", $_.Count) 
                        }
                        $Computers | Group-Object -Property SharepointInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
                                [void]$chart.Series["Data"].Points.AddXY("Sharepoint", $_.Count) 
                        }
                        
                        #--- Code: We save the chart now
                        $stream = New-Object System.IO.MemoryStream
                        $chart.SaveImage($stream, "png")
                        
                        $chart.SaveImage("$Path\Chart-Roles.png","png")
                        # $output += New-Object PSObject -Property @{Label = "Roles"; Bytes = $stream.GetBuffer()}
                        $output += New-Object PSObject -Property @{Title = "Roles"; Path = "$Path\Chart-Roles.png"; Bytes = $stream.GetBuffer()}
                        
                        #$today = (Get-Date).ToString("yyyy-MM-dd")
                        # $chart.SaveImage("$Path\Chart-Roles.png","png")
                        #Write-Output "$Path\Chart-Roles-$today.png"
                }
                        
                #--- Code: Either the Hardware or the OS shall be shown
                if ($Hardware -or $OS) {
                        Write-Debug -Message "New object properties may be added below to generate additionals charts"
                        
                        #--- Code: Cast as an array to prevent single elements from showing as an object
                        [array]$properties = @()
                        
                        #--- Code: Nested array (Object property name, Chart title, X Axis label)
                        if ($Hardware) {
                                $properties += @(
                                        New-Object PSObject -Property @{PropertyName = "CPU"; ChartTitle = "CPU Sockets Found"; TitleXAxis = "CPU Sockets"}
                                        New-Object PSObject -Property @{PropertyName = "MemoryGB"; ChartTitle = "Memory Found"; TitleXAxis = "Memory (GB)"}
                                        New-Object PSObject -Property @{PropertyName = "Manufacturer"; ChartTitle = "Manufacturer Found"; TitleXAxis = "Manufacturer Name"}
                                        New-Object PSObject -Property @{PropertyName = "Model"; ChartTitle = "Model Found"; TitleXAxis = "Model Name"}
                                )
                        }
                        
                        if ($OS) {
                                $properties += @(
                                        New-Object PSObject -Property @{PropertyName = "OS"; ChartTitle = "OS Found"; TitleXAxis = "OS"}
                                        New-Object PSObject -Property @{PropertyName = "ServicePack"; ChartTitle = "Service Pack Found"; TitleXAxis = "Service Pack Name"}
                                )
                        }
                        
                        ForEach ($data in $properties) {
                                Try {
                                        #--- Code: Check if the property exists first.
                                        If (($Computers | Get-Member | Select -ExpandProperty Name) -Contains $data.PropertyName) {
                                                Write-Verbose -Message "Generating a chart for the property '$($data.PropertyName)'"
                                                
                                                #--- Code: First, we create the chart object
                                                $chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
                                                $chart.BackColor = "White"
                                                $chart.Width = 500
                                                $chart.Height = 500
                                                
                                                #--- Code: We name our chart
                                                [void]$chart.Titles.Add($data.ChartTitle)
                                                $chart.Titles[0].Alignment = "topLeft"
                                                $chart.Titles[0].Font = "Tahoma,13pt"
                                                
                                                #--- Code: We create the chart area
                                                $chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
                                                $chartarea.Name = "ChartArea1"
                                                $chartarea.AxisX.Interval = 1
                                                $chartarea.AxisX.MajorGrid.LineColor = "#d1d1d1"
                                                $chartarea.AxisX.Title = $data.TitleXAxis
                                                $chartarea.AxisY.Interval = 5
                                                $chartarea.AxisY.MajorGrid.LineColor = "#d1d1d1"
                                                $chartarea.AxisY.Title = "Count"
                                                $chartarea.BackColor = "White"
                                                $chartarea.BackGradientStyle = "DiagonalRight"
                                                $chartarea.BackSecondaryColor = "#d3e6ff"
                                                $chart.ChartAreas.Add($chartarea)
                                                
                                                #--- Code: We create the serie now
                                                [void]$chart.Series.Add("Role")
                                                $chart.Series["Role"].BorderColor = "#1062ba"
                                                $chart.Series["Role"].BorderDashStyle="Solid"
                                                $chart.Series["Role"].BorderWidth = 1
                                                $chart.Series["Role"].ChartArea = "ChartArea1"
                                                $chart.Series["Role"].ChartType = "Column"
                                                $chart.Series["Role"].Color = "#6aaef7"
                                                $chart.Series["Role"].IsValueShownAsLabel = $true
                                                $chart.Series["Role"].IsVisibleInLegend = $true
                                                
                                                $Computers | Group-Object -Property $data.PropertyName | ForEach-Object {
                                                        [void]$chart.Series["Role"].Points.AddXY($_.Name, $_.Count) 
                                                }
                                                
                                                #--- Code: We save the chart now
                                                $stream = New-Object System.IO.MemoryStream
                                                $chart.SaveImage($stream, "png")
                                                
                                                # $output += New-Object PSObject -Property @{Label = $data.PropertyName; Bytes = $stream.GetBuffer()}
                                                $chart.SaveImage("$Path\Chart-$($data.PropertyName).png","png")
                                                $output += New-Object PSObject -Property @{Title = $data.PropertyName; Path = "$Path\Chart-$($data.PropertyName).png"; Bytes = $stream.GetBuffer()}
                                                
                                                #$today = (Get-Date).ToString("yyyy-MM-dd")
                                                # $chart.SaveImage("$Path\Chart-$($data.PropertyName)-$today.png","png")
                                                #Write-Output "$Path\Chart-$($data.PropertyName)-$today.png"
                                        } Else {
                                                Write-Warning -Message "The property '$($data.PropertyName)' does not exist in the given object"
                                        }
                                } Catch {
                                        
                                }
                        }
                }
        }
        
        END {
                return $output
        }
}

function Export-PowerPoint {
		<#
	.SYNOPSIS
	Exports Charts to PowerPoint format

	.DESCRIPTION
	Export the Charts to a powerpoint presentation. The first page is a Title with a subtitle. Then one slide will be created for each graph together with a main title.
	
	.PARAMETER  <Path>
	Specifies de export path folder (must be a folder).
	
	.PARAMETER  <GraphInfos>
	This parameter must be an object with the following two headers : Path;Title.
	Path --> Represents the the path to the physical location of the chart.
	Title --> A short title of what the chart represent
	
	.PARAMETER  <Title>
	Title that will be used on all documents (Front page of the PowerPoint export, Header of Html file). 
	
	.PARAMETER  <Subtitle>
	SubTitle that will be used on all documents (Front page of the PowerPoint export, Header of Html file (Underneath the title)). 
	
	.PARAMETER  <Debug>
	This parameter is optional, and will if called, activate the deubbing mode wich can help to troubleshoot the script if needed. 

	.NOTES
	-Version 0.4
	-Author : Stéphane van Gulick
	-Creation date: 08/01/2014


	.EXAMPLE
	Export-powerPoint -title "PowerShell Winter Scripting Games 2014" -Subtitle "Posh Monks" -Path D:\Exports -GraphInfos $ArrayImage
	
	Exports the Images to a powerPoint format. The file name is Export-PowerShellMonks.pptx. On the first slide,
	The title : "PowerShell Winter Scripting Games 2014" and the subtitle "Power Monks" will be displayed.
	The file will be exported to D:\Export Folder.
	
	

#>
	
	[cmdletbinding()]
	
		Param(
		
		[Parameter(mandatory=$true)]$Path = $(throw "Path is mandatory, please provide a value."),
		[Parameter(mandatory=$true)]$GraphInfos,
		[Parameter(mandatory=$false)]$title,
		[Parameter(mandatory=$false)]$Subtitle
		
		)

	Begin {
		Add-type -AssemblyName office
		Add-Type -AssemblyName microsoft.office.interop.powerpoint
		#DEfining PowerPoints main variables
			$MSTrue=[Microsoft.Office.Core.MsoTriState]::msoTrue
			$MsFalse=[Microsoft.Office.Core.MsoTriState]::msoFalse
			$slideTypeTitle = [microsoft.office.interop.powerpoint.ppSlideLayout]::ppLayoutTitle
			$SlideTypeChart = [microsoft.office.interop.powerpoint.ppSlideLayout]::ppLayoutChart
			
		#Creating the ComObject
			$Application = New-Object -ComObject powerpoint.application
			#$application.visible = $MSTrue
	}
	Process{
		#Creating the presentation
			$Presentation = $Application.Presentations.add() 
		#Adding the first slide
			$Titleslide = $Presentation.Slides.add(1,$slideTypeTitle)
			$Titleslide.Shapes.Title.TextFrame.TextRange.Text = $Title
			$Titleslide.shapes.item(2).TextFrame.TextRange.Text = $Subtitle
			$Titleslide.BackgroundStyle = 11
			[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Titleslide)
		
		#Adding the charts
		foreach ($Graphinfo in $GraphInfos) {

			#Adding slide
			$slide = $Presentation.Slides.add($Presentation.Slides.count+1,$SlideTypeChart)

			#Defining slide type:
			#http://msdn.microsoft.com/en-us/library/microsoft.office.interop.powerpoint.ppslidelayout(v=office.14).aspx
					$slide.Layout = $SlideTypeChart
					$slide.BackgroundStyle = 11
					$slide.Shapes.Title.TextFrame.TextRange.Text = $Graphinfo.title
			#Adding picture (chart) to presentation:
				#http://msdn.microsoft.com/en-us/library/office/bb230700(v=office.12).aspx
					$slide.Shapes.AddPicture($Graphinfo.Path,$mstrue,$msTrue,300,100,350,400)
					[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($slide)
		}
	}
end {
		$presentation.Saveas($exportPath)
	 	$presentation.Close()
		[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($presentation)
		$Application.quit()
		[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Application)
		[gc]::collect()
		[gc]::WaitForPendingFinalizers()
		$Application =  $null
	}
	
}

Function Export-html {
	
	<#
	.SYNOPSIS
	Exports data to HTML format

	.DESCRIPTION
	ExportTo-HTML has a personalized CSS code which make the output nicer then the classical ConvertTo-Html and allows to add images / graphs in the HTML output
	
	.PARAMETER  <Debug>
	This parameter is optional, and will if called, activate the deubbing mode wich can help to troubleshoot the script if needed. 
	
	.NOTES
	-Version 0.1
	-Author : Stéphane van Gulick
	-Creation date: 01/06/2012
	-Creation date: 01/06/2012
	-Script revision history
	##0.1 : Initilisation
	##0.2 : First version
	##0.3 : Added Image possibilities

	
	
	.EXAMPLE
	Exportto-html -Data (Get-Process) -Path "d:\temp\export.html" -title "Data export"
	
	Exports data to a HTML file located in d:\temp\export.html with a title "Data export"
	
	.EXAMPLE
	In order to call the script in debugging mode
	Exportto-html  -Image $ByteImage -Data (Get-service) "d:\temp\export.html" -title "Data Service export"
	
	Exports data to a HTML file located in d:\temp\export.html with a title "Data export". Adds also an image in the HTML output.
	#Remark: -image must be  of Byte format.
#>
	
	[cmdletbinding()]
	
		Param(
		
		[Parameter(mandatory=$true)]$Path = $(throw "Path is mandatory, please provide a value."),
		[Parameter(mandatory=$false)]$GraphInfos,
		[Parameter(mandatory=$false)]$Data,
		[Parameter(mandatory=$false)]$title,
		[Parameter(mandatory=$false)]$Subtitle,
		[Parameter(mandatory=$false)]$Image
		
		)
	Begin{
	
		#Preparing HTML header:
		
		$html = @" 
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://
www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
		
<style type="text/css">
body {
    height: 100%;
    margin: 0px;
	background-color: #a0e1ff;
	background-image: -ms-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: -moz-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: -o-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: -webkit-gradient(linear, left top, right bottom, color-stop(0, #FFFFFF), color-stop(1, #00A3EF));
	background-image: -webkit-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: linear-gradient(to bottom right, #FFFFFF 0%, #00A3EF 100%);
    background-repeat: no-repeat;
    background-attachment: fixed;
	font-family:"Tahoma", "Lucida Sans Unicode", Verdana, Arial, Helvetica, sans-serif;
	font-size:12px;
}

#container {
	padding-top:50px;
	padding-bottom:50px;
}

#core {
	background-color: #efefef;
	-webkit-background-size: 50px 50px;
	-moz-background-size: 50px 50px;
	background-size: 50px 50px;
	-moz-box-shadow: 1px 1px 8px gray;
	-webkit-box-shadow: 1px 1px 8px gray;
	box-shadow: 1px 1px 8px gray;
	box-shadow: 0 0 5px #888;
	border: 1px solid #91938d;
	margin: 0 auto;
	width: 880px;
}

#header {
	background-color: #2d2d2d;
	border-bottom: 3px solid #666863;
	height: 35px;
	margin-bottom: 20px;
}

#title {
	color: #ffffff;
	font-family: Tahoma;
	font-size: 18px;
	line-height: 35px;
	font-variant: small-caps;
	font-weight: bold;
	padding-left: 25px;
	margin: 0 auto;
	/*text-shadow: 2px 1px 3px rgba(0, 0, 0, 0.47);*/
	text-transform: uppercase;
	vertical-align:middle;
}

#summary {
	border: 1px dashed #8aaa7b;
	background-color: #eaffe0;
	margin: 0 auto;
	padding: 5px;
	width: 800px;
}

#content_header {
	font-size: 14px;
	font-weight: bold;
}

#chart_container {
	background-color: #e0f3ff;
	border: 1px solid #b3c3cc;
	margin: 0px auto 15px;
	margin-top: 15px;
	padding: 5px;
	width: 800px;
}

#values_container {
	background-color: #fffced;
	border: 1px solid #bcb3cc;
	margin: 0px auto 15px;
	margin-top: 15px;
	padding: 5px;
	width: 800px;
}

#informations {
	border-collapse: collapse;
	border: 1px solid #888;
	margin: 5px;
}

#informations td {
	padding-left: 10px;
	padding-right: 20px;
}

#informations th {
	background-color: #ffee9b;
	border: 1px solid #000;
}

#informations tr {
	background-color: #fff8d8;
}

.title_chart {
	display: block;
	font-size: 12px;
	font-weight: bold;
	margin-bottom: 4px;
}

.chart {
	border: 1px solid #ddd;
	display: block;
	margin: 0px auto 5px;
}

a:visited { color: blue; }
a:link { color: blue; }
</style>
		
</head>
<body>
<div id="container">
	<div id="core">
		<div id="header"><span id="title">POSH Monks Report</span></div>
"@
		
	}
	Process {
        #If HTML view has been selected, the returned service status will be exported to a HTML file as well
        Write-Verbose "Exporting object to HTML $($path)"
		
		# Generate the table of contents
		$html += '
		<div id="summary">
			<span id="content_header">Table of contents:</span>
			<ul>'
		
		ForEach ($item in $GraphInfos) {
			$html += '
				<li><a href="#anch' + $item.Title + '">Chart: ' + $item.Title + '</a></li>'
		}
		
		$html += '
				<li><a href="#anchValues">Analyzed Computers</a></li>
			</ul>
		</div>
		'
		
		# Generate the graphs
		ForEach ($item in $GraphInfos) {
			$converted = [System.Convert]::ToBase64String($item.Bytes)
			$html += '<div id="chart_container">
				<span id="anch' + $item.Title + '" class="title_chart">Chart: ' + $item.Title + '</span><br />
				<img class="chart" src="data:image/jpg;base64,' + $converted + '" />
			</div>'
		}
		
		# Generate a table for the analyzed computers
		$html += '
			<div id="values_container">
				<span id="anchValues" class="title_chart">Analyzed Computers</span><br />
				<table id="informations">
				'
		
		# Todo: Add a label or a title to get a better visual of the given property
		ForEach ($item in $Data) {
			# We retrieve the NoteProperties from the given object, we don't need the methods, we skip the computername since it's our header
			$properties = ($item | Get-Member | Where-Object {($_.MemberType -eq "NoteProperty") -and ($_.Name -ne "ComputerName")} | Select -ExpandProperty Name)
			
			$tableset = '<tr><th>Computer Name:</th><th>' + $item.ComputerName + '</th></tr>'
			ForEach ($property in $properties) {
				$tableset += '<tr><td>' + $property + '</td><td>' + $($item.$property) + '</td></tr>'
			}
			
			$html += $tableset
			
			# $computerName = $item.ComputerName
			# $html += '
				# <tr>
					# <td>
				# </tr>
			# '
			write-host $computerName
		}
		# the line below retrieve the NoteProperties of an object by skipping the Method and other stuff. We need a label still.
		#($obj | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty"} | Select -ExpandProperty Name)
		
		#$html += $Data | ConvertTo-Html
		
		$html += '
				</table>
			</div>'
                  <#        
                       	$htmltitle = "<h2>$($title)</h2>"
						$htmlSubtitle = "<h3>$($Subtitle)</h3>"
                       	$HtmlItem = $Data | ConvertTo-Html -Fragment
                           	
                      	if ($Image){
					$ImageHTML = @"
<IMG class="Graphs" src="data:image/jpg;base64,$($Image)" style="left: 50%" alt="Image01">
"@
		
			}#>
                  
	}         
	End {
		$html += "</div></div></body></html>"
		$html | Out-File $Path
	}
}

Function Get-Base64Image {
		<#
	.SYNOPSIS
	Converts an image to Byte type
	
	.DESCRIPTION
	Usefull in oder to add an image byte into HTML code and make the HTML file independant from any other external file.
	
	.PARAMETER <Path>
	File path to the original image file.
	
	.PARAMETER  <Debug>
	This parameter is optional, and will if called, activate the deubbing mode wich can help to troubleshoot the script if needed.
	
	#>
	
	[cmdletbinding()]
		
		Param(
		
		[Parameter(mandatory=$true)]$Path = $(throw "Path is mandatory, please provide a value.")
	)
	begin{}
	process{
		$ImageBytes = [Convert]::ToBase64String((Get-Content $Path -Encoding Byte))
	}
	End{
		return $ImageBytes
	}
}

function New-export {
	
[cmdletbinding()]
	
		Param(
		
		[Parameter(mandatory=$true)]$Path = $(throw "Path is mandatory, please provide a value."), #Full  path ? Or folder path ?
		[Parameter(mandatory=$true)]$Data,
		[Parameter(mandatory=$false)][Validateset("csv", "html", "powerpoint")][String]$Exportype,
		[Parameter(mandatory=$false, ParameterSetName="ppt")]$ArrayImage,
		[Parameter(mandatory=$false)]$title,
		[Parameter(mandatory=$false)]$Subtitle,
		[Parameter(mandatory=$false)]$Image
		
		)
	Begin {
		
		
			switch ($Exportype){
				
					("csv"){
						$FileName = "Export-$($Title).Csv"
						$ExportPath = Join-Path -Path $Path -ChildPath $FileName
						Write-Verbose "exporting the file to $($exportPath)"	
						$Data | Export-Csv -Path $ExportPath -NoTypeInformation
					}
					("Html"){
						$FileName = "Export-$($Title).html"
						$ExportPath = Join-Path -Path $Path -ChildPath $FileName
						Write-Verbose "exporting the file to $($exportPath)"	
						Export-html -Data $Data -title $title -Subtitle $Subtitle -Path $ExportPath -GraphInfos $ArrayImage
					}
					("PowerPoint"){
						$FileName = "Export-$($Title).pptx"
						$ExportPath = Join-Path -Path $Path -ChildPath $FileName
						Write-Verbose "exporting the file to $($exportPath)"	
						Export-powerPoint -title $Title -Subtitle $SubTitle -Path $ExportPath -GraphInfos $ArrayImage
					
					}
					default {
						Write-Host "none"
					}

			}
	}
	Process{
	
		}
	End{
	}
}

########Testing#############

$cp1 = New-Object PSObject -Property @{
        ComputerName                = "SRV001"
        IISInstalled                = $true
        SQLInstalled                = $true
        ExchangeInstalled        = $false
        SharepointInstalled        = $false
        CPU                                = 4
        MemoryGB                = 6
        Manufacturer        = "Allister Fisto Industries"
        Model                        = "Fistron 2000"
        ServicePack                = "Microsoft Windows Server 2008 R2 Enterprise"
		OS = ""
}

$cp2 = New-Object PSObject -Property @{
        ComputerName                = "SRV002"
        IISInstalled                = $true
        SQLInstalled                = $true
        ExchangeInstalled        = $false
        SharepointInstalled        = $true
        CPU                                = 2
        MemoryGB                = 2
        Manufacturer        = "Allister Fisto Industries"
        Model                        = "Fistron 3000"
        ServicePack                = "Microsoft Windows Server 2008 R2 Standard"
}

$cp3 = New-Object PSObject -Property @{
        ComputerName                = "SRV003"
        IISInstalled                = $false
        SQLInstalled                = $false
        ExchangeInstalled        = $true
        SharepointInstalled        = $false
        CPU                                = 4
        MemoryGB                = 8
        Manufacturer        = "Allister Fisto Industries"
        Model                        = "Fistron 2000"
        ServicePack                = "Microsoft Windows Server 2008 Standard"
}

$computers = @($cp1, $cp2, $cp3)
#$ByteImage  = Get-Base64Image "E:\Users\Administrator\SkyDrive\Scripting\Githhub\WinterScriptingGames2014\Event 0 - Practice\Charts\Chart-CPU-2014-01-06.png"

######ENDTESTING#####################

$Title  = "Posh-Monks"
$SubTitle = "Winter Scripting Games 2014 - Event:00 (Practice)"


#ExportTo-PowerPoint -Path "D:\temp\plop.pptx" -GraphInfos $a -title $Title -Subtitle $SubTitle
#Exportto-html  -Image $ByteImage -Data (Get-Process) -Path "d:\temp\plop.html" -title $Title -Subtitle  $SubTitle

$Output = New-Chart -Computers $computers -Path "c:\ps" -Roles -OS -Hardware
#Export powerpoint
	#New-export -Path "c:\ps\" -Exportype "powerpoint"-title $Title -Subtitle $SubTitle -ArrayImage $output
#Export Html
	New-export -Path "c:\ps\" -Exportype "html" -title $Title -Subtitle $SubTitle -Data $computers -ArrayImage $output

#endregion Chart






function Get-Inventory {
	<#
	.SYNOPSIS
		A brief description of the Get-Something function.

	.DESCRIPTION
		A detailed description of the Get-Something function.

	.PARAMETER  ParameterA
		The description of a the ParameterA parameter.

	.PARAMETER  ParameterB
		The description of a the ParameterB parameter.

	.EXAMPLE
		PS C:\> Get-Something -ParameterA 'One value' -ParameterB 32
		'This is the output'
		This example shows how to call the Get-Something function with named parameters.

	.EXAMPLE
		PS C:\> Get-Something 'One value' 32
		'This is the output'
		This example shows how to call the Get-Something function with positional parameters.

	.INPUTS
		System.String,System.Int32

	.OUTPUTS
		System.String

	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.

	.LINK
		about_modules

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

	.LINK
		about_functions_advanced_parameters

	.LINK
		about_functions_advanced_methods
#>

	
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[System.String]
		$ParameterA,
		[Parameter(Position=1)]
		[System.Int32]
		$ParameterB
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			
		}
		catch {
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
Export-ModuleMember -Function Get-Something

# Optional commands to create a public alias for the function
New-Alias -Name gs -Value Get-Something
Export-ModuleMember -Alias gs
