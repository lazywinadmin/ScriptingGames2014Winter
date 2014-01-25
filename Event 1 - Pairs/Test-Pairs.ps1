#requires -version 3
Function Get-Pair {
<#
    .SYNOPSIS
            This function Get-Pair will return pairs of people.

    .DESCRIPTION
            This function Get-Pair will return pairs of people.

    .PARAMETER Pairs
            Specifies the list of people

    .PARAMETER Path
            Specifies the path to export the output

    .EXAMPLE
            Get-Pair -Pairs "Syed", "Kim", "Sam", "Hazem", "Pilar", "Terry", "Amy", "Greg", "Pamela", "Julie", "David", "Robert", "Shai", "Ann", "Mason", "Sharon"
            
            Person                                     Pal                                      
            ------                                     ---                                      
            Terry                                      Julie                                    
            Hazem                                      David                                    
            Shai                                       Ann                                      
            Pamela                                     Syed                                     
            Kim                                        Sharon                                   
            Pilar                                      Mason                                    
            Robert                                     Greg                                     
            Amy                                        Sam 

    .EXAMPLE
            Get-Pair -Pairs "Syed", "Kim", "Sam", "Hazem", "Pilar", "Terry", "Amy", "Greg", "Pamela", "Julie", "David", "Robert", "Shai", "Ann", "Mason", "Sharon" -Verbose
            
	Person                                  Pal                                    
	------                                  ---                                    
	VERBOSE: [PROCESS] Created a pair between Pilar and Amy
	Pilar                                   Amy                                    
	VERBOSE: [PROCESS] Created a pair between Mason and Robert
	Mason                                   Robert                                 
	VERBOSE: [PROCESS] Created a pair between Shai and Greg
	Shai                                    Greg                                   
	VERBOSE: [PROCESS] Created a pair between Julie and Terry
	Julie                                   Terry                                  
	VERBOSE: [PROCESS] Created a pair between Sam and Ann
	Sam                                     Ann                                    
	VERBOSE: [PROCESS] Created a pair between Kim and Syed
	Kim                                     Syed                                   
	VERBOSE: [PROCESS] Created a pair between Pamela and Hazem
	Pamela                                  Hazem                                  
	VERBOSE: [PROCESS] Created a pair between David and Sharon
	David                                   Sharon                 

#>
    [CmdletBinding()]
    PARAM(
        [Parameter(
            Mandatory,
            HelpMessage="You have to specify the list of person to add in the pairs",
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            Position=0)]
        [Array]$Pairs,
        
        [ValidateScript(
            {Test-Path -path $_})]
        [String]$Path
    )#PARAM Block
	
    BEGIN {
        $SpecialPal = ""
        IF ($Pairs.Count -lt 2) {
            Write-Error -Message "[BEGIN] How do you want to make pairs with less than 2 persons?!"
            return
        }#IF
        
        # Counting Pairs and check if it is a off number
        IF (($Pairs.Count % 2) -ne 0) {
            Write-Warning -Message "[BEGIN] The Pairing is odd"
	        DO
			{
				Write-Verbose  -Message "[BEGIN] Prompting to select one special pal"
				$specialpal = $Pairs | Out-GridView  -OutputMode Single -Title "select the Special Pal"
			}#DO
	        UNTIL ($SpecialPal)
        }#IF(($Pairs.Count % 2) -ne 0)
    }#BEGIN Block
    
    PROCESS {
		TRY{
	        
	            #add the special pal twice to the list to make it even number of names
	            $Pairs += $SpecialPal 
	            
	            Write-Verbose -Message "[PROCESS] $SpecialPal Will have two secret pals"
	        
	        # Mixing the pairs to avoid people being with the same pairs
	        $Pairs = $Pairs | Get-Random -Count $Pairs.Count
	        
	        # Assign the pairs
	        FOR ($i = 0; $i -lt $Pairs.Count; $i = $i + 2) {
	            Write-Verbose -Message "[PROCESS] Created a pair between $($Pairs[$i]) and $($Pairs[$i+1])"
	            if ($pair[$i] -ne $pair[$i +1])
	            {
	            	$pair = New-Object -TypeName PSObject -Property @{
	                				Person = $Pairs[$i]
	                				Pal = $Pairs[$i+1]
	            				}#New-Object PSObject
	            }
	            else
	            {
	            	#there might be a case where the Get-Random puts the Special pal and added Special Pal cosecutively
	            	#this takes care of it and prompts user to run the Function again
			        Throw "couldn't randomize properly ..run the script again"
	            }
            	
	            
	           Write-Output -inputobject $pair #Write the Output to the pipeline
	           # Array will be created automatically using Indirection
	        }#FOR
		}#TRY
		CATCH{
			Write-Warning -Message "[PROCESS] Something wrong happened !"
			Write-Warning -Message $Error[0].Exception
		}#CATCH
    }#PROCESS Block
	
    END {
        TRY{
			# Exporting the document
			IF ($PSBoundParameters.ContainsKey('Path')) {
				$Now = Get-Date -Format "yyyyMMdd_HHmmss"
				Write-Verbose -Message "[END] Exporting to XML"
				$Output | Export-CliXML -Path (Join-Path -Path $Path -ChildPath "Export-Pairs_$($Now).xml") -ErrorAction Stop -ErrorVariable ErrorEndExportXML
			}#IF
			return $Output
			Write-Verbose -Message "[END] Function Get-Pair Completed !"
		}#TRY
		CATCH{
			Write-Warning -Message "[END] Something wrong happened !"
			IF($ErrorEndExportXML){Write-Warning -message "[END] "}
			Write-Warning -Message $Error[0].Exception
		}#CATCH
    }#END Block
}#Function Get-Pair


Function Get-DevPair {
<#
	.SYNOPSIS
			The function Get-DevPair will associate a list of people in paired groups.
			The information will be saved in the Path specified (XML File)

	.DESCRIPTION
			The function Get-DevPair will associate a list of people in paired groups.
			The information will be saved in the Path specified (XML File)
			You can optionally specify one or more primary for each pairs and send an email to the persons assigned to the project.

	.PARAMETER  Path
			Export path that is used in order to expor the history of pairs.

	.PARAMETER  List
			Specifies the list of persons to add in the pairs
			
	.PARAMETER Email
			Enable to Parameters to send email to the pairs

	.PARAMETER EmailTo
			Specifies the destination email address(es)

	.PARAMETER EmailFrom
			Specifies the sender email address

	.PARAMETER EmailSubject
			Specifies the subject of the email

	.PARAMETER EmailServer
			Specifies the SMTP server to use

	.PARAMETER EmailCc
			Specifies the person Email Address to carbon copy

	.PARAMETER EmailServer
			Specifies the SMTP server that will be used in order to send the email message.

	.EXAMPLE
			Get-DevPair -List "Michelou","Syed", "Kim", "Sam", "Hazem", "Pilar", "Terry", "Amy", "Greg", "Pamela", "Julie", "David", "Robert", "Shai", "Ann", "Mason", "Sharon" -Primaries "Loulou","phiphi","picsou" -Path "C:\ps" -Verbose
			
			Person                     Pal                        Primary                  
			------                     ---                        -------                  
			Shai                       Hazem                      Loulou                   
			Pamela                     Amy                        phiphi                   
			Sam                        Sharon                     picsou                   
			Kim                        Mason                                               
			Ann                        Robert                                              
			Pilar                      Terry                                               
			Greg                       Syed                                                
			Julie                      David                                               
			ben                        Michelou                          
			
	.EXAMPLE
			

#>
    [CmdletBinding()]
    PARAM(
        [Parameter(
            Mandatory,
            HelpMessage="Specify the list of people to assign in pairs",
            Position=0)]
        [Array]$List,
        
        [ValidateCount(0,5)]    
        [Parameter(
            Mandatory,
            HelpMessage="You have to specify the list of primaries",
            Position=1)]
        [Array]$Primaries,
    
        [ValidateScript(
            {Test-Path -path $_})]
        [Parameter(
            Mandatory,
            HelpMessage="You have to specify the Path where the file(s) will be saved"
            )]
        [String]$Path,
        
        [Parameter(ParameterSetName="Email")]
        [switch]$Email,
        
        [Parameter(
        	Mandatory,
        	HelpMessage="You have to specify the destination email(s) address",
        	ParameterSetName="Email")]
        [string[]]$EmailTo,
        
        [Parameter(ParameterSetName="Email")]
        [mailaddress]$EmailCc = "ProjectManager@PoshMonk.org",
        
        [Parameter(ParameterSetName="Email")]
        [mailaddress]$EmailFrom = "Event1@PoshMonk.org",
        
        [Parameter(ParameterSetName="Email")]
        [string]$EmailServer = "smtp.poshmonk.org",
        
        [Parameter(ParameterSetName="Email")]
        [string]$EmailSubject = "PoshMonk Project"
        
    )#PARAM Block
    
    BEGIN {
		# Create function to handle Pairs History
		Function Get-PairWithHistory {
		<#
		        .SYNOPSIS
		                The Function generates unique pairs

		        .DESCRIPTION
		                The Function goes through the ProjectPairs-History.xml to track previous pairs and generates the unique pair from last time .

		        .PARAMETER  Pairs
		                Specify the list of person to add in the pairs.

		        .PARAMETER  Path
		                Specify the path where the file(s) will saved.

				.PARAMETER MaxAssignment
						Specify the maximum no of assignment before the pairs repeat.

		        .EXAMPLE
						Get-PairsWithHistory -Pairs "Benny","Stephane","FX","Dexter","Allister","Guido" -Path C:\Temp\ProjectPairs-History.xml -verbose

		        .EXAMPLE
		                $names = "Benny","Stephane","FX","Dexter","Allister","Guido"
		                Get-PairsWithHistory -Pairs $name -path C:\ProjectPairs-History.xml -verbose 

		        .INPUTS
		                None

		        .OUTPUTS
		                System.Management.Automation.PSCustomObject

		        .NOTES
						Tried not to use += operator as it creates a new array. Used Arraylist as they have Add() and Removeat() methods.
						Just write the object to pipeline the indirection takes care of wrapping them up into arrays.

		        .LINK
		                http://mjolinor.wordpress.com/2014/01/18/another-take-on-using-the-operator/

		        .LINK
		                http://powershell.org/wp/2013/09/16/powershell-performance-the-operator-and-when-to-avoid-it/

		#>
		    [CmdletBinding()]
		    PARAM(
		        [Parameter(
		            Mandatory,
		            HelpMessage="You have to specify the list of person to add in the pairs",
		            Position=0)]
		        [Array]$Pairs,
		    
		        [ValidateScript(
		            {Test-Path -path $_})]
		        [Parameter(
		            Mandatory,
		            HelpMessage="You need to specify the path where the file(s) will saved",
		            Position=1)]
		        [String]$Path,
		        
		        [Int]$MaxAssignment = 4
		    )#PARAM
		    
		    BEGIN {
		        # type cast again to get the Generic List back
		        [System.Collections.Generic.List[pscustomobject]]$History = Import-Clixml -Path $Path -ErrorAction Stop -ErrorVariable XMLDoesnotExist
		        
		        $Processed = New-Object -TypeName System.Collections.ArrayList
		    }#BEGIN Block
		    
		    PROCESS {
		        TRY{
		        #have to use the property to iterate because when primaries are changed then a new pscustomobject is added to $history 
		        # if we use -- foreach ($person in $history) -- then  it would fail saying cannot enumerate as the collection changed
		        FOREACH ($Personname in $History.person) 
		        {
		            Write-Verbose -Message "[PROCESS] Processing $Personname"
		            $person = $History | Where-Object -Property person -eq "$Personname"
		            $Who = $Person.Person
		            $Previous = $Person.Previous
		            
		            IF (($Processed -notcontains $Who) -and ($Pairs -contains $Personname)) 
		            {
		                IF ($Previous.Count -ge $MaxAssignment)
		                    {
		                        #Remove the first element from the array and the Object itself
		                        $Previous.removeat(0)
		                    }
		                
		                $Eligible = $Pairs | Where-Object {$_ -ne $Who}
		                
		                FOREACH ($Candidate in $Eligible) 
		                {
		                    IF (($Previous -notcontains $Candidate) -and ($Processed -notcontains $Candidate)) 
		                        {
		                        Write-Verbose -Message "[PROCESS] Created a pair between $Who and $Candidate"
		                        
	                            [pscustomobject]@{Person = $Who;Pal = $Candidate} 
	                            #write this object to pipeline..using indirection it will give the array
		                                                                
		                        [void]$Processed.Add("$Who")  
		                        [void]$Processed.Add("$Candidate") 
		                        [void]$Person.Previous.add("$Candidate") 
		                        
		                        # Reverse Update
		                        
		                        IF (!($Pal = $History | Where-Object {$_.Person -eq $Candidate}))
		                        {
		                            #The pal can be empty if the Primaries are changed afetr each stage
		                            [void]$History.Add($(New-Object PSObject -Property @{Person = $Candidate; Previous = $(New-Object -TypeName System.Collections.ArrayList)}))
		                            #after adding an empty property for a Dev which was primary in earlier run.
		                            #Above will make sure that below doesn't give any error
		                            $Pal = $History | Where-Object {$_.Person -eq $Candidate}
										
		                        }#IF (!($Pal = $History | Where-Object {$_.Person -eq $Candidate})
		                        
		                        $PalPrevious = $Pal.Previous
		                        IF ($PalPrevious.Count -ge $MaxAssignment) 
		                        {
		                            $PalPrevious.removeat(0)
		                        }#IF ($PalPrevious.Count -ge $MaxAssignment)
		                                               
		                        [void]$Pal.Previous.add("$Who")
		                        break
		                    }#if (($Previous -notcontains $Candidate)
		                }#ForEach ($Candidate in $Eligible)
		            }#if ($Processed -notcontains $Who)
		        }#ForEach ($Personname in $History.person)
		        }
		        CATCH{
		            Write-Warning -Message "Something Wrong happened"
		            Write-Warning -Message $Error[0].Exception
				}#CATCH
		    }#PROCESS Block
		    
		    END {
				TRY{
					$History | Export-Clixml -Path $Path -ErrorAction Stop -ErrorVariable ErrorEndExportXML
					Write-Verbose -Message "[END] Function Get-PairsWithHistory Completed !"
				}#TRY
				CATCH{
					Write-Warning -Message "[END] Something Wrong happened"
					IF ($ErrorEndExportXML){Write-Warning -Message "[END] Error while exporting to XML file"}
					Write-Warning -Message $Error[0].Exception
				}#CATCH
			}#END Block
		}#Function Get-PairWithHistory

        TRY{
	        $Candidates = $List | Where-Object {$Primaries -notcontains $_}
	        $Candidates = $Candidates | Get-Random -Count $Candidates.Count
	        
	        # Pre, we check get/create the history XML
	        IF (Test-Path -Path (Join-Path -Path $path -ChildPath "ProjectPairs-History.xml")) {
	            # Exists, we check the content to prevent identical assignments
	            $Pairs = Get-PairWithHistory -Pairs $Candidates -Path "$path\ProjectPairs-History.xml"
	        } ELSE {
	            # First run, we create it
	            Write-Verbose -Message "[BEGIN] Creating ProjectPairs-History.xml to track the previous assignments"
	            
	            $history = New-Object -TypeName System.Collections.Generic.list[pscustomobject]
	            $history = FOREACH ($Candidate in $Candidates) {
					New-Object PSObject -Property @{
	                    Person = $Candidate
	                    Previous = New-Object -TypeName System.Collections.ArrayList
					}#New-Object
	            }#FOREACH
	            
	            Write-Verbose -Message "[BEGIN] Exporting History to XML File"
	            $history | Export-Clixml -Path (Join-Path -Path $path -ChildPath "ProjectPairs-History.xml") -ErrorAction Stop -ErrorVariable ErrorBeginExportCliXML
	            $Pairs = Get-PairWithHistory -Pairs $Candidates -Path "$path\ProjectPairs-History.xml"
	        }#ELSE
		}#TRY Block
		CATCH{
			Write-Warning -Message "[BEGIN] Something wrong happened !"
			IF ($ErrorBeginExportCliXML) {Write-Warning -Message "[BEGIN] Error while Exporting XML"}
			Write-Warning -Message $Error[0].Exception
		}#CATCH
    }#BEGIN Block
    
    PROCESS {
        TRY{
			# Assigning Primaries
			IF ($Primaries.count -gt 0) {
			    Write-Verbose -Message "[PROCESS] Assigning Primaries to pairs"
			    $i = 0
			    FOREACH ($Pair in $Pairs) {
			        IF ($i -lt $Primaries.Count) {
			            $Primary = $Primaries[$i]
			            Write-Verbose -Message "[PROCESS] Primary $Primary has been assigned to pair $Pair"
			            $Pair | Add-Member -MemberType NoteProperty -Name Primary -Value $Primary
			            $i++
			        } ELSE {
			            break;
			        }#ELSE
			    }#FOREACH
			}#IF ($Primaries.count -gt 0)

			# Sending Mail
			IF ($Email) {
				Write-Verbose -Message "[PROCESS] Sending email message "
				Send-MailMessage -From $EmailFrom -To $EmailTo -Cc $EmailCc -Subject $EmailSubject -Body "Hello dear fellow scripter ! Find here the fantastic list of pairs that has been generated by the PoshMonks. $($pairs)" -BodyAsHtml -SmtpServer $EmailServer -ErrorAction Continue -ErrorVariable ErrorProcessSendMailMessage
			}
		}#TRY
		CATCH {
			Write-Warning -Message "[PROCESS] Something wrong happened !"
			IF ($ErrorProcessSendMailMessage){Write-Warning -Message "[PROCESS] Error while sending the email"}
			Write-Warning -Message $Error[0].Exception
		}#CATCH
		
    }#PROCESS Block
    
    END {
		TRY{
			#Exporting DevPairs information
			$Now = Get-Date -Format "yyyyMMdd_HHmmss"
			$Pairs | Export-CliXML -Path (Join-Path -Path $Path -ChildPath "Export-DevPairs_$($Now).xml") -ErrorAction Stop -ErrorVariable  ErrorEndExportCliXml
			return $Pairs
			Write-Verbose -Message "[END] Function Get-DevPair Completed !"
		}#TRY Block
		CATCH {
			Write-Warning -Message "[END] Something Wrong happened"
			IF ($ErrorEndExportCliXml){Write-Warning -Message "[END] Error while exporting the XML"}
			Write-Warning -Message $Error[0].Exception
		}#CATCH Block
	}#END Block
}#Function Get-DevPairs

[array]$names = "Syed", "Kim", "Sam", "Hazem", "Pilar", "Terry", "Amy", "Greg", "Pamela", "Julie", "David", "Robert", "Shai", "Ann", "Mason", "Sharon"
[array]$primaries = "Pilar","Ann","Kim"
Get-DevPair -List $names -Primaries $primaries -Path "C:\ps" -Verbose
# Get-Pair -Pairs $names -Verbose #-Path "c:\ps\"
