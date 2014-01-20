function Get-Pair{
    [CmdletBinding()]
	PARAM(
		[Parameter(Mandatory,HelpMessage="You need to specify a list of participants")]
		[System.Collections.ArrayList]$List,
		$NumberPerPair,
		[ValidateScript({Test-Path -Path $_})]
		$Path
	)
	BEGIN{
		# Set variables
		$ListCount = $List.Count
		$Quotient = $ListCount / $numberPerPair
        $Remainder = $ListCount % $numberPerPair
		$DateFormat = Get-Date -Format "yyyyMMdd_hhmmss"
		
		# Odd Number
		IF($Remainder){Write-Warning -Message "An Odd number of participants was specified, You will be ask to assign the remaining persons with differents Pals"}
		
	}#BEGIN block
	PROCESS{
		1..$Quotient | 
            ForEach-Object -Process {	
                # Creating Array
		        $Output = @{}
            	
			    #Pick a Pair
                $Pairs = Get-Random -Count $NumberPerPair -InputObject $List
			
			    # Add info to output variable
			    $Output.PairNumber = $_
			    $Output.Pair = $Pairs

                # Remove the entries selected by Get-Random
                $Pairs | ForEach-Object {$List.Remove($_)}

                # Creating PSobject and outputting the data
                New-Object -TypeName PSObject -Property $output
		    }#ForEach-Object

        IF ($Remainder){
            # Define how many I need for my new pair
            $PersonToSelect = $numberPerPair - $Remainder
            Write-Warning -Message "You have $Remainder left: $list"
            Write-Verbose -Message "You need to select $PersonToSelect person(s) to have a full pair"
            
            # Creating Array
            $Output = @{}
            
            # Add info to output variable
            $Output.PairNumber = [int]$Quotient + 1
            $Output.Pair = $list

            # Prompt the user for name(s) to have a full pair
            While ($PersonToSelect -ne 0){
                $Person = Read-Host -Prompt "Enter the name of the person to add in the new pair"
                
                # Add the name entered in the Pair
                $output.Pair += $Person

                # Decrease the value of $PersonToSelect
                $PersonToSelect--
            }

            # Creating PSobject and outputting the data
            New-Object -TypeName PSObject -Property $output
        }#IF ($Remainder){
	}#PROCESS block
	END{}#END block
}


function Get-ProjectPair{
	PARAM(
		[ValidateRange(0,5)]
        $Primary,
		$List,
		$NumberPerPair,
        #[Parameter(Mandatory,HelpMessage="You must save the result, please specify a path")]
		$Path
	)	
	BEGIN{
        $Pairs = Get-Pair -List $List -NumberPerPair $NumberPerPair
    }#BEGIN Block
    PROCESS{
        
    }#Process Block
    END{}#End Block
	
	
}


Get-Pair -NumberPerPair 4 -List "Syed","Kim","Sam","Hazem","Pilar","Terry","Amy","Greg","Pamela","Julie","David","Robert","Shai","Ann","Mason","Sharon","xavier","dexter"