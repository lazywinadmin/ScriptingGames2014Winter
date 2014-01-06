#TO DO:
# Function Get-ValidIPAddressinRange -- returns all possible IP address in the Range specified
# Leverage Workflow to Scan the generated list of IP's

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
                        {# if the specified IP format is -- 10.10.10.0 (along with this argument to Mask is also provided)
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
        Write-Verbose "Function Starting"
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
            [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
            [Net.IPAddress]$IPAddress
          )
 
          Process 
          {
            $i = 3; $DecimalIP = 0;
            $IPAddress.GetAddressBytes() | ForEach-Object { $DecimalIP += $_ * [Math]::Pow(256, $i); $i-- }
 
            Write-Output $([UInt32]$DecimalIP)
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
            [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
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
        
                Write-Output $([ipaddress]([String]::Join('.', $DottedIP)))
              }

              default 
              {
                Write-Error "Cannot convert this format"
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
                Write-Verbose "Inside CIDR Parameter Set"
                $temp = $ip.Split("/")
                $ip = $temp[0]
                 #The validation attribute on the parameter takes care if this is empty
                $mask = ConvertTo-DottedDecimalIP ([Convert]::ToUInt32($(("1" * $temp[1]).PadRight(32, "0")), 2))                            
            }

            "Non-CIDR"
            {
                Write-Verbose "Inside Non-CIDR Parameter Set"
                If (!$Mask.Contains("."))
                  {
                    $mask = ConvertTo-DottedDecimalIP ([Convert]::ToUInt32($(("1" * $mask).PadRight(32, "0")), 2))
                  }

            }
        }
        #now we have appropraite dotted decimal ip's in the $ip and $mask
        $DecimalIP = ConvertTo-DecimalIP -IPAddress $ip
        $DecimalMask = ConvertTo-DecimalIP $Mask

        $Network = $DecimalIP -BAnd $DecimalMask
        $Broadcast = $DecimalIP -BOr ((-BNot $DecimalMask) -BAnd [UInt32]::MaxValue)

        For ($i = $($Network + 1); $i -lt $Broadcast; $i++) {
            ConvertTo-DottedDecimalIP $i
          }
                       
            
    }
    End
    {
        Write-Verbose "Function Ending"
    }
}


### Tentative Workflow
Workflow Get-OSInfo 
{
    Param
    (
        [ipaddress[]]$Ip
    )
    foreach -parallel ($i in $ip)
    {
        if (Test-Connection -ComputerName $i -Count 2 -Quiet)
        {
            Get-WmiObject -Namespace root\cimv2 -Class Win32_OperatingSystem -PSComputerName $i 

        }
    }

}

   