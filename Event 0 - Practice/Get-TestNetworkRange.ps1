
function Get-TESTNetworkRange
{
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
    [CmdletBinding(DefaultParameterSetName='CIDR', 
                  SupportsShouldProcess=$true, 
                  PositionalBinding=$false,
                  HelpUri = 'http://www.microsoft.com/',
                  ConfirmImpact='Medium')]
    [OutputType([String[]])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0 )]
        [ValidateScript({
                        if ($_.contains("/"))
                            { # if the specified IP format is -- 10.10.10.0/24
                                $temp = $_.split('/')   
                                If (([ValidateRange(0,32)][int]$mask = $temp[1]) -and ($temp[0] -as [ipaddress]))
                                {
                                    Return $true
                                }
                            }                           
                        else
                        {# if the specified IP format is -- 10.10.10.0 (along with this Mask is also provided)
                            if ($_ -as [ipaddress])
                            {
                                return $true
                            }
                            else
                            {
                                throw "IP validation failed"
                            }
                        }
                        })]
        [Alias("IPAddress")] 
        [string]$IP,

        # Param2 help description
        [Parameter(ParameterSetName='Non-CIDR')]
        [ipaddress]$mask
    )

    Begin
    {
    }
    Process
    {
        if ($pscmdlet.ShouldProcess("Target", "Operation"))
        {
            $IP
        }
    }
    End
    {
    }
}