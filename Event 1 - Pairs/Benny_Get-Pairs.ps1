[array]$names = "Syed", "Kim", "Sam", "Hazem", "Pilar", "Terry", "Amy", "Greg", "Pamela", "Julie", "David", "Robert", "Shai", "Ann", "Mason", "Sharon", "Jil"

Function Get-Pairs {
	[cmdletbinding()]
	Param(
		[Parameter(
			Mandatory=$true,
			Position=0)]
		$Pairs
	)
	DynamicParam {
		# We add the secret pals parameter if our pairs are odd
		if ($Pairs.Count % 2 -ne 0) {
			# We create the parameter attribute
			$Parameter = New-Object System.Management.Automation.ParameterAttribute
			$Parameter.ParameterSetName = '__AllParameterSets'
			$Parameter.ValueFromRemainingArguments = $true
			$Parameter.Position = 1
			$Parameter.Mandatory = $false
			
			# The special pal's name need to be among the pair names
			$ParameterOption = New-Object System.Management.Automation.ValidateSetAttribute($Pairs)
			
			# We create the parameter itself
			$DefaultParam = New-Object System.Management.Automation.RuntimeDefinedParameter
			$DefaultParam.Name = 'OddPal'
			$DefaultParam.ParameterType = 'String'
			$DefaultParam.Attributes.Add($Parameter)
			$DefaultParam.Attributes.Add($ParameterOption)
			
			# We add the parameter to the Dictionnary
			$Dictionnary = New-Object Management.Automation.RuntimeDefinedParameterDictionary
			$Dictionnary.Add('OddPal', $DefaultParam)
			$Dictionnary
		}
	}
	
	BEGIN {
		If ($Pairs.Count -lt 2) {
			Write-Error -Message "How do you want to make pairs with less than 2 persons?!"
			return
		}
		
		# First we check if the Pairs count is odd or not
		If (($Pairs.Count % 2) -ne 0) {
			Write-Warning -Message "The Pairing is odd"
		}
		
		# Next, we check if a secret pal was specified or not
		$SpecialPal = ""
		If ($PSBoundParameters.ContainsKey('OddPal')) {
			$SpecialPal = $PSCmdlet.MyInvocation.BoundParameters['OddPal']
			Write-Verbose -Message "$SpecialPal will have two secret pals!"
		}
	}
	
	PROCESS {
		# If a special pal is specified, then we remove him from the pair's array
		if ($SpecialPal -ne "") {
			# Here we don't bother with mutliple identical values since we're dealing with names, bob and bob would probably be hard to distinguish!
			$Pairs = $Pairs | Where-Object {$_ -ne $SpecialPal}
		}
		
		# Mix it a bit by default, some people may be bored to have the same pal all the time :D
		$Pairs = $Pairs | Get-Random -Count $Pairs.Count
		
		# Assign the pairs
		For ($i = 0; $i -lt $Pairs.Count; $i = $i + 2) {
			$pair = New-Object PSObject -Property @{
				Person = $Pairs[$i]
				Pal = $Pairs[$i+1]
			}
			
			Write-Output $pair
		}
		
		# Our special pal is set?
		if ($SpecialPal -ne "") {
			$pair = New-Object PSObject -Property @{
				Person = $SpecialPal
				Pal = $Pairs | Get-Random -Count 2
			}
			
			Write-Output $pair
		}
	}
	
	END { }
}

Get-Pairs -Pairs $names -OddPal "Ann" -Verbose
