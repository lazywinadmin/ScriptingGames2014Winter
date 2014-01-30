# Put all the functions in this file
#Region Stephane
Function Get-XMlDifferences {
	#Not Finalized yet
    [CmdletBinding()]
    Param(
        [Parameter(mandatory=$true)]
        [ValidateScript({
            test-path $_
        
        })]
        $ReferenceObject,
        [Parameter(mandatory=$true)]
        [ValidateScript({
            test-path $_
        
        })]
        $differenceObject
    )

    Begin{}
    Process{
        
        #Getting the XML content to compare
            $ContentReference = Get-Content -Path $ReferenceObject
            $contentDifference = Get-Content -path $differenceObject
        #Getting differences
            $Differences = Compare-Object -ReferenceObject $ContentReference -DifferenceObject $contentDifference -CaseSensitive | Where-Object {$_.sideIndicator -eq "=>"} | select Inputobject
        #Retrieving line informations
            #write-host "$($Differences.Inputobject)"
            $String = select-string -SimpleMatch -CaseSensitive '$($Differences.Inputobject)' -Path $ReferenceObject
            
            $Return = [pscustomobject]@{"LineContent"=$Differences.Inputobject; "LineNumber"=$String.LineNumber}

    }
    End{
        
        return $Return
    }

}

$ReferenceObject = "C:\Users\gulicst1\SkyDrive\Scripting\Githhub\WinterScriptingGames2014\WinterScriptingGames2014\Event 2 - Security Footprint\Reference.config"
$differenceObject = "C:\Users\gulicst1\SkyDrive\Scripting\Githhub\WinterScriptingGames2014\WinterScriptingGames2014\Event 2 - Security Footprint\Difference.config"

Get-XMlDifferences -ReferenceObject $ReferenceObject -differenceObject $differenceObject
#Not finished yet
#EndRegion