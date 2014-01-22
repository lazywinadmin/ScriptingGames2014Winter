Function Get-Pairs {
	[cmdletbinding()]
	Param(
		[Parameter(
			Mandatory=$true,
			Position=0)]
		[Array]$Pairs,
		
		[ValidateScript(
			{Test-Path -path $_})]
		[String]$Path
	)
	
	BEGIN {
		$SpecialPal = ""
		If ($Pairs.Count -lt 2) {
			Write-Error -Message "How do you want to make pairs with less than 2 persons?!"
			return
		}
		
		# First we check If the Pairs count is odd or not
		If (($Pairs.Count % 2) -ne 0) {
			Write-Warning -Message "The Pairing is odd"
			
			while ($true) {
				$SpecialPal = Read-Host "who will have TWO secret pals?"
				
				If ($SpecialPal -eq "") { break; }
				If ($Pairs -contains $SpecialPal) {
					break
				} else {
					Write-Warning -Message "$SpecialPal is not present among the pairs"	
				}
			}
			
			If ($SpecialPal -eq "") {
				Write-Warning -Message "There is no special pal specified!"	
			}
		}
		
		$Output = @()
	}
	
	PROCESS {
		# If a special pal is specIfied, then we remove him from the pair's array
		If ($SpecialPal -ne "") {
			# Here we don't bother with mutliple identical values since we're dealing with names, bob and bob would probably be hard to distinguish!
			$Pairs = $Pairs | Where-Object {$_ -ne $SpecialPal}
			
			Write-Verbose -Message "$SpecialPal Will have two secret pals"
		}
		
		# Mix it a bit by default, some people may be bored to have the same pal all the time :D
		$Pairs = $Pairs | Get-Random -Count $Pairs.Count
		
		# Assign the pairs
		For ($i = 0; $i -lt $Pairs.Count; $i = $i + 2) {
			$pair = New-Object PSObject -Property @{
				Person = $Pairs[$i]
				Pal = $Pairs[$i+1]
			}
			
			$Output += $pair
		}
		
		# Our special pal is set?
		If ($SpecialPal -ne "") {
			$pair = New-Object PSObject -Property @{
				Person = $SpecialPal
				Pal = $Pairs | Get-Random -Count 2
			}
			
			$Output += $pair
		}
	}
	
	END {
		# Finally, we may want to export it heh
		If ($PSBoundParameters.ContainsKey('Path')) {
			$Now = Get-Date -Format "yyyyMMdd_HHmmss"
			$Output | Export-CliXML -Path "$($Path)\Export-Pairs_$($Now).xml"
		}
		
		return $Output
	}
}

Function Get-PairsWithHistory {
	[cmdletbinding()]
	Param(
		[Parameter(
			Mandatory=$true,
			Position=0)]
		[Array]$Pairs,
	
		[ValidateScript(
			{Test-Path -path $_})]
		[Parameter(
			Mandatory=$true,
			Position=1)]
		[String]$Path,
		
		[Int]$MaxAssignment = 4
	)
	
	BEGIN {
		
		$History = Import-Clixml -Path $Path
		
		$Output = @()
		$Processed = @()
	}
	
	PROCESS {
		ForEach ($Person in $History) {
			$Who = $Person.Person
			$Previous = $Person.Previous
			
			if ($Processed -notcontains $Who) {
				if ($Previous.Count -ge $MaxAssignment) {
					# Trim the begining of the array!
					# TODO: trim up to $MaxAssignment, not just once.
					$Previous = $Previous | Where-Object {$_ -ne $Previous[0]}
					$Person.Previous = $Previous
				}
				
				$Eligible = $Pairs | Where-Object {$_ -ne $Who}
				
				ForEach ($Candidate in $Eligible) {
					if (($Previous -notcontains $Candidate) -and ($Processed -notcontains $Candidate)) {
						$Output += New-Object PSObject -Property @{
							Person = $Who
							Pal = $Candidate
						}
						
						$Processed += $Who, $Candidate
						$Person.Previous += $Candidate
						
						# Reverse Update
						$Pal = $History | Where-Object {$_.Person -eq $Candidate}
						
						$PalPrevious = $Pal.Previous
						if ($PalPrevious.Count -ge $MaxAssignment) {
							$PalPrevious = $PalPrevious | Where-Object {$_ -ne $PalPrevious[0]}
							$Pal.Previous = $PalPrevious
						}
						
						$Pal.Previous += $Who
						break
					}
				}
			}
		}
	}
	
	END {
		$History | Export-Clixml -Path $Path
		return $Output
	}
}

Function Get-DevPairs {
	[cmdletbinding()]
	Param(
		[Parameter(
			Mandatory=$true,
			Position=0)]
		[Array]$List,
		
		# We consider that primaries are people specIfied within the list -> "They should never pair with another primary"
		[ValidateCount(0,5)]	
		[Parameter(
			Mandatory=$true,
			Position=1)]
		[Array]$Primaries,
	
		[ValidateScript(
			{Test-Path -path $_})]
		[Parameter(
			Mandatory=$true)]
		[String]$Path,
		
		[switch]$Mailing
	)
	
	BEGIN {
		$Candidates = $List | Where-Object {$Primaries -notcontains $_}
		$Candidates = $Candidates | Get-Random -Count $Candidates.Count
		
		# Pre, we check get/create the history XML
		If (Test-Path -Path "$path\ProjectPairs-History.xml") {
			# Exists, we check the content to prevent identical assignments
			
			$Pairs = Get-PairsWithHistory -Pairs $Candidates -Path "$path\ProjectPairs-History.xml" -Verbose
		} else {
			# First run, we create it
			Write-Verbose -Message "Creating ProjectPairs-History.xml to track the previous assignments"
			
			[array]$history = @()
			Foreach ($Candidate in $Candidates) {
				$history += New-Object PSObject -Property @{
					Person = $Candidate
					Previous = @()
				}
			}
			
			$history | Export-Clixml -Path "$path\ProjectPairs-History.xml"
			
			
			$Pairs = Get-PairsWithHistory -Pairs $Candidates -Path "$path\ProjectPairs-History.xml" -Verbose
		}
	}
	
	PROCESS {
		# We assign the primaries
		If ($Primaries.count -gt 0) {
			Write-Verbose -Message "Assigning Primaries to pairs"
			$i = 0
			ForEach ($Pair in $Pairs) {
				If ($i -lt $Primaries.Count) {
					$Primary = $Primaries[$i]
					$Pair | Add-Member -MemberType NoteProperty -Name Primary -Value $Primary
					$i++
				} else {
					break;
				}
			}
		}
		
#		If ($Mailing) {
#			$message = new-object Net.Mail.MailMessage
#			$smtp = new-object Net.Mail.SmtpClient("smtp.mycompany.com")
#			
#			$message.From = "pairing@powershellevent1.org"
#			$message.To.Add("projectmanager@powershellevent1.org")
#			$message.Subject = ("VMware Guest Disk Report: " + (get-date).toString("dd-MM-yyyy HH:mm:ss"))
#			$message.IsBodyHTML = $true
#			$message.Body = $echo
#			
#			$smtp.Send($message)
#		}
	}
	
	END {
		$Now = Get-Date -Format "yyyyMMdd_HHmmss"
		$Pairs | Export-CliXML -Path "$($Path)\Export-DevPairs_$($Now).xml"
		return $Pairs
	}
}

[array]$names = "Syed", "Kim", "Sam", "Hazem", "Pilar", "Terry", "Amy", "Greg", "Pamela", "Julie", "David", "Robert", "Shai", "Ann", "Mason", "Sharon"
[array]$primaries = "Syed", "Terry", "David", "Sharon"

Get-DevPairs -List $names -Primaries $primaries -Path "c:\ps"
#Get-Pairs -Pairs $names -Path "c:\ps\" -Verbose
