Function Get-IPAddressinRange
{	
<#
	.SYNOPSIS
		Scans the IP network range and gives some info.

	.DESCRIPTION
		The Function will first generate a list of valid IPAddresses in a Network range.
        Then if OSInfo switch is specified then it uses the Multi-threading to query the remote machines.
        
	.PARAMETER  IP
		Specify the IPAddress with Mask or IPAddress in CIDR format.

	.PARAMETER  Mask
		Specify the Mask to use with the IPAddress.
        
    .PARAMETER ThrottleLimit
        Specify the number of runspaces to run to speed up the OSINfo gathering.
        Works only when specified with OSInfo switch
    
    .PARAMETER OSInfo
        Specify this switch to get the OSInfo.

	.EXAMPLE
		Gets the list of IPAddresses in the CIDR Range 10.1.1.1/24
        PS C:\> Get-IPAddressinRange -IPAddress 10.1.1.1/24

	.EXAMPLE
		Gets the list of IPAddresses in the CIDR Range 10.1.1.1/24 along with the Computername, OS & SP info. 
        By default runs 10 runspaces to speed up the information gathering.
        PS C:\> Get-IPAddressinRange -IPAddress 10.1.1.1/24 -OSInfo

    .EXAMPLE
		Gets the list of IPAddresses in the Non_CIDR Range along with the Computername, OS & SP info.
        Specify the runspaces to use, depending on the configuration of the system script is running on.
        PS C:\> Get-IPAddressinRange -IPAddress 10.1.1.1 -Mask 255.255.255.0 -OSInfo -ThrottleLimit 50    
	.INPUTS
		System.string

	.OUTPUTS
		System.Management.Automation.PSObject[] [or System.Net.IPAddress

	.NOTES
		Wrapper function

#>
    [CmdletBinding()]
    [OutputType([object[]])]
    Param
    (
        # IPaddress input taken as string, Validation done by Get-ValidIPAddressinRange later
        [Parameter(Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true)]
        [Alias("Network")]
        [string]$IP,

        
        #Accept a separate mask value to in string..validation done by Get-ValidIPAddressinRange
        [string]$mask,

        #specify a throttle limit for how many Runspaces to run
        # [PSDefaultValue(Help = 'No of Runspaces to open.')]
        $ThrottleLimit = 10,

        #specify a switch to get the OSInfo
        [switch]$OSInfo
        
    )

    Begin
    {
        Write-Verbose -Message "Get-IPAddressinRange : Starting"
        #region Function definitions
        Function Get-ValidIPAddressinRange
        {
            <#
            .Synopsis
               Takes the IP Address and the Mask value as input and returns all possible IP
            .DESCRIPTION
               The Function takes the IPAddress and the Subnet mask value to generate list of all possible IP addresses in the Network.
            .PARAMETER IP
                Specify the IPAddress or the Network Range in CIDR format e.g 10.1.1.1/24
            .PARAMETER Mask
                Specify the mask when an IPAddress is passed as an argument.
                The mask value can be either an integer value in range [0,32] or in dotted decimal format e.g 255.255.255.0
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
            [CmdletBinding(DefaultParameterSetName='CIDR')] 
            [OutputType([ipaddress[]])]
            Param
            (
                
                [Parameter(Mandatory=$true, 
                           ValueFromPipeline=$true,
                           ValueFromPipelineByPropertyName=$true                  
                            )]
                [ValidateScript({
                                if ($_ -like "*/*")
                                    { # if the specified IP format is -- 10.10.10.0/24
                                        $temp = $_  -split '/'
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
                                if ($_ -like "*.*.*.*")
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
                    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
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
                    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
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
        } #end Function Get-ValidIPAddressinRange

        
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
        
                .PARAMETER Protocol
                    Specify the Protocol to be used to establish a CIM Session.

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
		        [Parameter(Position=0, Mandatory=$true,
                            ValueFromPipeline=$true,
                            ValueFromPipelineByPropertyName=$true)]
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
				[array]$out = @()
	        }
	        Process
	        {
		        foreach ($Ip in $IPAddress)
                {
                    Write-Verbose -Message "Get-OSInfo : Working with IP Address - $IP"
            
			
		            if (Resolve-IPAddress -IPAddress $IP)
		            {
			            #IP Address resolves to a Hostname
                        Write-Verbose -Message "Get-OSInfo : $IP is resolving to a hostname $Ip"
			            Write-Verbose -Message "Get-OSInfo : Testing if the $Ip is online"
                
						
                        # Define Splatting
			            $CIMSessionParams = @{
				            ComputerName 	= ([System.Net.Dns]::GetHostEntry("$Ip")).HostName 
				            ErrorAction 	= 'Stop'
				            ErrorVariable	= 'ProcessErrorCIM'
			            }
			
                        TRY {
				            # Prepare Output Variable
			                $Output = @{
				                IPAddress = $Ip
                                ComputerName = ([System.Net.Dns]::GetHostEntry("$Ip")).HostName
				                Connectivity = 'Online'
                                OS = $null
                                ServicePack = $null #adding this null values here to get the ouput in List format
			                }

				            # Connectivity
                            Write-Verbose -Message "Get-OSInfo : $Ip - Testing Connection..."
                            Test-Connection -ComputerName $Ip -count 1 -ErrorAction Stop -ErrorVariable ProcessErrorTestConnection | Out-Null
				
                				
				            # Credential
				            IF ($PSBoundParameters['Credential']) {$CIMSessionParams.credential = $Credential}
				
				            # Protocol not specified
				            IF (-not($PSBoundParameters['Protocol'])){
					            # Trying with WsMan protocol
					            Write-Verbose -Message "Get-OSInfo : $Ip - Trying to connect via WSMAN protocol"
					            IF ((Test-WSMan -ComputerName $Ip -ErrorAction SilentlyContinue).productversion -match 'Stack: 3.0'){
						            Write-Verbose -Message "Get-OSInfo : $Ip - WSMAN is responsive"
            			            $CimSession = New-CimSession @CIMSessionParams
            			            $CimProtocol = $CimSession.protocol
            			            Write-Verbose -message "Get-OSInfo : $Ip - [$CimProtocol] CIM SESSION - Opened"
					            }#IF
					            ELSE{
						            # Trying with DCOM protocol
						            Write-Verbose -message "Get-OSInfo : $Ip - WSMAN protocol does not work, failing back to DCOM"
            			            Write-Verbose -Message "Get-OSInfo : $Ip - Trying to connect via DCOM protocol"
	            		            $CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
	            		            $CimSession = New-CimSession @CIMSessionParams
	            		            $CimProtocol = $CimSession.protocol
	            		            Write-Verbose -message "Get-OSInfo : $Ip - [$CimProtocol] CIM SESSION - Opened"
					            }#ELSE
				            }#IF Block
				
				
				            # Protocol Specified
				            IF ($PSBoundParameters['Protocol']){
					            SWITCH ($protocol) {
						            "WSMAN" {
							            Write-Verbose -Message "Get-OSInfo : $Ip - Trying to connect via WSMAN protocol"
							            IF ((Test-WSMan -ComputerName -ErrorAction Stop -ErrorVariable ProcessErrorTestWsMan).productversion -match 'Stack: 3.0') {
								            Write-Verbose -Message "Get-OSInfo : $Ip - WSMAN is responsive"
		            			            $CimSession = New-CimSession @CIMSessionParams
		            			            $CimProtocol = $CimSession.protocol
		            			            Write-Verbose -message "Get-OSInfo : $Ip - [$CimProtocol] CIM SESSION - Opened"
							            }
						            }
						            "DCOM" {
							            Write-Verbose -Message "Get-OSInfo : $Ip - Trying to connect via DCOM protocol"
		            		            $CIMSessionParams.SessionOption = New-CimSessionOption -Protocol Dcom
		            		            $CimSession = New-CimSession @CIMSessionParams
		            		            $CimProtocol = $CimSession.protocol
		            		            Write-Verbose -message "Get-OSInfo : $Ip - [$CimProtocol] CIM SESSION - Opened"
						            }
					            }
				            }
				
                
                            #get the Information from Win32_OperatingSystem
                            $OSInfo = Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem

                            $Output.Protocol = $CimProtocol
                            $Output.OS = $OSInfo.Caption
                            $Output.ServicePack = $OSInfo.CSDversion

                            Write-Verbose -Message "Get-OSInfo : $Ip - Output information"
                            [pscustomobject]$Output
                        }
                
			            CATCH {
				            IF ($ProcessErrorTestConnection)
                            {
                                #Machine name resolves but Machine is offline
                                Write-Warning -Message "Get-OSInfo : $Ip - Can't Reach"
                                $Output.Connectivity = "Offline"
                        
                                Write-Verbose -Message "Get-OSInfo : $Ip - Output information"
                                [pscustomobject]$Output
                            }
				            IF ($ProcessErrorCIM)
                            {
                                #Machine name resolved and machine is online but Not able to Query it
                                Write-Warning -Message "Get-OSInfo : $Ip - Can't Connect - $protocol"
                        
                                Write-Verbose -Message "Get-OSInfo : $Ip - Output information"
                                [pscustomobject]$Output
                            }
				            IF ($ProcessErrorTestWsMan){Write-Warning -Message "Get-OSInfo : $Ip - Can't Connect - $protocol"}
				            
			            }#CATCH Block
			
			            FINALLY{
				            Write-Verbose "Get-OSInfo : Removing CIM 3.0 Session from $Ip"
                            IF ($CimSession) {Remove-CimSession $CimSession}
			            }#FINALLY Block

	        }
	        
                    else
                    {
                        Write-Verbose -Message "Get-OSInfo : $IP not resolving"
                        [pscustomobject]@{IPAddress=$Ip} 
                    }
				$out += $Output
            }
    
            }
            End
	        {
                Write-Verbose -Message "Get-OSInfo : Ending the Function"
				write-output $out
            }
        }#end Function Get-OSinfo


		function Get-IPOnline {
			param(
				[Parameter(Mandatory=$true,
							ValueFromPipeline=$true,
							ValueFromPipelineByPropertyName=$true)]
				$ip
			)
			
			begin {
				[array]$valid = @()
			}
			process {
				if (Test-Connection $ip.IPAddressToString -count 1 -erroraction silentlycontinue) {
					$valid += $ip.IPAddressToString
				}
			}
			end { return $valid }
		}
        #endregion

    }
    Process
    {
        if($OSInfo)
        {
            #User needs OSInfo
            Write-Verbose -Message "Get-IPAddressinRange : OSInfo Switch specified....OS & SP info will be returned"
            $PSBoundParameters.Remove("OSinfo") | Out-Null
            $PSBoundParameters.Remove("ThrottleLimit") | Out-Null
			$out = Get-ValidIPAddressinRange @PSBoundParameters
			Get-ValidIPAddressinRange @PSBoundParameters | Get-IPOnline | Get-OSInfo
        }
        else
        {
            Write-Verbose -Message "Get-IPAddressinRange : OSInfo Switch notspecified...will only return list of IPs in the Network Range"
            Get-ValidIPAddressinRange @PSBoundParameters | Get-IPOnline
            
        }
    }
    End
    {
         Write-Verbose -Message "Get-IPAddressinRange : Ending"
    }
}
