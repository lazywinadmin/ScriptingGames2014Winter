function Get-Pair{
    [CmdletBinding()]
	PARAM(
		[Parameter(Mandatory,HelpMessage="You need to specify a list of participants")]
		[System.Collections.ArrayList]$List,
        [Parameter(Mandatory)]
		$NumberPerPair,
		[ValidateScript({Test-Path -Path $_})]
		$Path
	)
	BEGIN{
		# Set variables
		$Quotient = $List.Count / $numberPerPair
        $Remainder = $List.Count % $numberPerPair
		$DateFormat = Get-Date -Format "yyyyMMdd_hhmmss"
		
		# Odd Number
		IF($Remainder){Write-Warning -Message "An Odd number of participants was specified, You will be ask to assign the remaining persons with differents Pals"}
		
	}#BEGIN block
	PROCESS{
		1..$Quotient | 
            ForEach-Object -Process {	
                # Creating HashTable
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
            Write-Warning -Message "You have $Remainder person(s) left: $list"
            Write-Verbose -Message "You need to select $PersonToSelect person(s) to have a full pair"
            
            # Creating HashTable
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
    [CmdletBinding()]
	PARAM(
		[ValidateCount(0,5)]
        [System.Collections.ArrayList]$PrimaryList,
        [Parameter(Mandatory)]
		[System.Collections.ArrayList]$List,
        [Parameter(Mandatory)]
		$NumberPerPair,
        #[Parameter(Mandatory,HelpMessage="You must save the result, please specify a path")]
		$Path
	)	
	BEGIN{
        
        $Pairs = Get-Pair -List $List -NumberPerPair $NumberPerPair
    }#BEGIN Block
    PROCESS{
        IF ($PSBoundParameters["PrimaryList"]){
            IF ($PrimaryList.count -gt $Pairs.count){
                Write-Warning -Message "Too Much Primary specified, can assigned them all"
                Break
            }ELSE{
                Write-Verbose -Message "$($PrimaryList.count) Primary specified"
                WHILE ($PrimaryList.count -ne 0){
                    # For each Primary name listed
                    1..$($PrimaryList.count) | 
                        ForEach-Object -Process {
                            # Creating HashTable
                            $Output = @{}

                            # Get a Random Primary
                            $PrimarySelected = Get-Random -Count 1 -InputObject $PrimaryList
                            $PairSelected = Get-Random -Count 1 -InputObject $Pairs

                            # Add Primary to a Pair
                            $Output.PairNumber = $PairSelected.PairNumber
                            $Output.Pair = $PairSelected.pair
                            $Output.Pair += $PrimarySelected
                            
                            #Remove PrimarySelect from Primary List and the Selected Pair from $pairs
                            $PrimarySelected | ForEach-Object {$PrimaryList.Remove($_)}
                            #$Pairs | ForEach-Object {$Pairs.Remove($PairSelected)}
                            $Pairs.PSObject.Properties.Remove($PairSelected.pairNumber)

                            # Creating PSobject and outputting the data
                            Write-Verbose -Message "Output pair with a primary"
                            New-Object -TypeName PSObject -Property $output
                        }#ForEach-Object
  

                    Write-Verbose -Message "Output the rest of $pairs"
                    Write-output $pairs | Where-Object {$($_.Pair.count) -eq $NumberPerPair}
                } #WHILE ($Primary.count -ne 0)
            }#ELSE
        }#IF ($Primary)
        ELSE{
        $pairs
        }

    }#PROCESS Block
    END{}#END Block
}


#Get-Pair -NumberPerPair 4 -List "Syed","Kim","Sam","Hazem","Pilar","Terry","Amy","Greg","Pamela","Julie","David","Robert","Shai","Ann","Mason","Sharon","xavier","dexter"


Get-ProjectPair -NumberPerPair 2 -List "Syed","Kim","Sam","Hazem","Pilar","Terry","Amy","Greg","Pamela","Julie","David","Robert","Shai","Ann","Mason","Sharon","xavier","dexter" -PrimaryList "Vivian","Dominique" -Verbose | 
    Sort-Object PairNumber
