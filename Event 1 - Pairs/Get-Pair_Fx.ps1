#requires -version 3

function Get-Pair{
    [CmdletBinding()]
	PARAM(
		[Parameter(
			Mandatory,
			HelpMessage="You need to specify a list of participants",
			Position = "1",
			ValueFromPipeline,
			ValueFromPipelineByPropertyName)]
		[System.Collections.ArrayList]$List,
	
        [Parameter(
			Mandatory,
			HelpMessage="You need to specify a number of person per pair")]
		#[ValidateScript({
		#	IF(-not($_ -gt 1)){
		#		throw "ERROR - You need at least 2 person per pair !"}})]
		[int]$NumberPerPair,
	
		[ValidateScript({Test-Path -Path $_})]
		$Path
	)
	BEGIN{
		# Set variables
		$Quotient = $List.Count / $numberPerPair
        $Remainder = $List.Count % $numberPerPair
		$DateFormat = Get-Date -Format "yyyyMMdd_hhmmss"
		
		# Odd Number
		IF($Remainder){Write-Warning -Message "An Odd number of participants was specified, You will be ask to pick someone who is already in pair so the script can create a new pair with the remaining person(s)"}
		
		# Export Variable
		$Export=@()
		
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
                $Output = New-Object -TypeName PSObject -Property $output
				Write-Output -InputObject $Output
				
				# Export
				IF($Path){$Export += $Output}
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
            $Output = New-Object -TypeName PSObject -Property $output
			Write-Output -InputObject $Output
			
			# Export
			IF($Path){$Export += $Output}
        }#IF ($Remainder){
	}#PROCESS block
	END{
		IF($Path){
			TRY{
				Write-Verbose -Message "Exporting Data to $Path"
				Export-Clixml -InputObject $Export -Path (Join-Path -Path $Path -ChildPath "Pair_Export-$DateFormat.xml") -ErrorAction 'Continue' -ErrorVariable EndErrorExportClixml
			}CATCH{
				Write-Warning -Message "END Block - Something wrong happened !"	
				IF($EndErrorExportClixml){Write-Warning -Message "END Block - Error while exporting the data in a XML file"}
			}#CATCH
		}#IF($Path)
		Write-Verbose -Message "Get-Pair - Script Completed"}#END block
}#function Get-Pair

function Get-PairProject{
    [CmdletBinding()]
	PARAM(
		[ValidateCount(0,5)]
        [System.Collections.ArrayList]$PrimaryList,
        [Parameter(Mandatory)]
		[System.Collections.ArrayList]$List,
        [Parameter(Mandatory)]
		$NumberPerPair,
		$Path,
		[Parameter(ParameterSetName="History")]
		[Switch]$History=$true,
		[Parameter(ParameterSetName="History")]
		[int]$Cycle = 4
	)	
	BEGIN{
		function Get-PairProjectHistory {
					[CmdletBinding()]	
					PARAM(
						[ValidateScript({Test-Path -Path $_})]
						$Path,
						$Cycle
					)
					BEGIN{}
					PROCESS{
						$XMLFile 	= Get-ChildItem "PairProject_Export-*.xml" -Path $path -File
						$Files 		= $XMLFile | Sort-Object -Property LastWriteTime -Descending | Select-Object -first $cycle
						[pscustomobject]$info = $Files | Import-Clixml
						
						# Create HashTable
				
						#Create a hashtable for each name
						FOREACH ($name in $info.pair){
								@{Name=$name;Previous=""} | Set-variable $name
						}

						# Process each XML file
						0..($files.count-1) |
							ForEach-Object {
								$FileNo = $_
								
								#Group of Pairs (within the file)
								0..($info[$_].count-1) | 
									ForEach-Object {
										$PairNo = $_
										
										# Pairs within the Group
										Foreach ($item in $($info[$FileNo][$_].pair)){
											#EACH MEMBER OF PAIR $info[$FileNo][$_].pair
											(Get-Variable $item).value.Previous += @($info[$FileNo][$_].pair -notlike $item)
											$PairNo++
										}#Foreach ($item
										$PairNo=0
									}#1..$($info[$_].count)
								$FileNo++
						}#1..$files.count
					}#PROCESS
					END{Write-Verbose -Message "Get-PairProjectHistory - Script Completed"}
				}#function Get-PairProjectHistory
		
		TRY{
        	[System.Collections.ArrayList]$Pairs = Get-Pair -List $List -NumberPerPair $NumberPerPair -ErrorAction Stop -ErrorVariable BeginErrorGetPair
			#Get-PairProjectHistory
		
			IF ($History){
				
			}#IF ($History)
			
			# Export Variable
			$Export=@()
			
		}CATCH {
			Write-Warning -Message "BEGIN Block - Something wrong happened"
			IF($BeginErrorGetPair){Write-Warning -Message "BEGIN Block - Error while getting the pairs"}
            $Error[0]
		}
    }#BEGIN Block
    PROCESS{
		TRY{
			
			#IF ($History){Get-Func}
			
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
	                            $PrimarySelected = Get-Random -Count 1 -InputObject $PrimaryList -ErrorAction Stop -ErrorVariable ProcessErrorPrimarySelected
	                            $PairSelected = Get-Random -Count 1 -InputObject $Pairs -ErrorAction Stop -ErrorVariable ProcessErrorPairSelected

	                            # Add the pair and Primary selected from the hashtable $Output
	                            $Output.PairNumber = $PairSelected.PairNumber
	                            $Output.Pair = $PairSelected.pair
	                            $Output.Pair += $PrimarySelected
	                            
	                            # Remove PrimarySelect from Primary List and the Selected Pair from $pairs
	                            $PrimarySelected | ForEach-Object -Process {$PrimaryList.Remove($_)}
								
								# Remove the Pair Selected from the list of Pairs
	                            $Pairs.Remove($PairSelected)

	                            # Creating PSobject and outputting the data
	                            Write-Verbose -Message "Output pair with a primary"
	                            $Output = New-Object -TypeName PSObject -Property $output -ErrorAction Stop -ErrorVariable ProcessErrorNewObject 
								Write-Output -InputObject $Output
								
								# Export
								IF($Path){$Export += $Output}
							
							}#ForEach-Object
						
	                    Write-Verbose -Message "Output the rest of $pairs"
	                    Write-output -InputObject $Pairs
						
						$Export += $Pairs
	                } #WHILE ($Primary.count -ne 0)
	            }#ELSE
	        }#IF ($Primary)
	        ELSE{
				# Output $pair
	        	Write-Output -InputObject $Pairs
				
				# Export
				IF($Path){$Export += $Pairs}
				
	        }#ELSE
			
		}CATCH{
			Write-Warning -Message "PROCESS BLOCK - Something horrible happened !"
			IF($ProcessErrorPrimarySelected) {Write-Warning -Message "PROCESS BLOCK - Error while getting Random Primary"}
			IF($ProcessErrorPairSelected) {Write-Warning -Message "PROCESS BLOCK - Error while getting Random Pair"}
			IF($ProcessErrorNewObject) {Write-Warning -Message "PROCESS BLOCK - Error Outputting the variable '$output'"}
            $Error[0]
		}
    }#PROCESS Block
    END{
		IF($Path){
			TRY{
				Write-Verbose -Message "END Block - Exporting Data to $Path"
				Export-Clixml -InputObject $Export -Path (Join-Path -Path $Path -ChildPath "PairProject_Export-$DateFormat.xml") -ErrorAction 'Continue' -ErrorVariable EndErrorExportClixml
				
			}CATCH{
				Write-Warning -Message "END Block - Something Wrong happened"
				IF ($EndErrorExportClixml){Write-Warning -Message "END Block - Error while exporting the data to $path"}
                $error[0]
			}
		}#IF($Path)
		Write-Verbose -Message "Get-ProjectPair - Script Completed"
	}#END Block
}


#Get-Pair -NumberPerPair 4 -List "Syed","xavier","Kim","Sam","Hazem","Pilar","Terry","Amy","Greg","Pamela","Julie","David","Robert","Shai","Ann","Mason","Sharon" -Verbose -Path $Home\desktop


Get-PairProject -NumberPerPair 2 -List "Syed","Kim","Sam","Hazem","Pilar","Terry","Amy","Greg","Pamela","Julie","David","Robert","Shai","Ann","Mason","Sharon","xavier","dexter" -PrimaryList "Vivian","Dominique" -Verbose -Path .
