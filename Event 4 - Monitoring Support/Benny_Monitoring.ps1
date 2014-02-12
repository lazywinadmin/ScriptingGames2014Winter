Function New-MonitoringConfiguration {
	[CmdletBinding()]
	PARAM(
		[Parameter(Mandatory)]
		[ValidateScript({Test-Path -Path $_ -PathType Leaf})]
		$List,
        
		[ValidateScript({Test-Path -Path $_})]
		$Output=$PSScriptRoot
    )

    BEGIN {
        Write-Verbose -Message "[BEGIN - New-MonitoringConfiguration] Attempting to generate a New Configuration"
    }

    PROCESS {
        TRY {
            # Browse each lines within the CSV
            Import-Csv -Path $List -ErrorAction Stop -ErrorVariable ErrCsv | ForEach-Object {
                Write-Verbose -Message "[PROCESS - New-MonitoringConfiguration] Generating a new XML Config for server $($_.Server)"

                # Generate dynamically what we want to monitor
                $CsvLine = $_
                $Monitoring = ""
                "CPU", "RAM", "Disk", "Network" | ForEach-Object {
                    IF ($($CsvLine.$_)) {
                        $Monitoring += "`n    <Monitor$($_)>$($CsvLine.$_)</Monitor$($_)>"
                    }
                }

                # Create the XML Configuration file
                $ConfigFile = @"
<?xml version="1.0" encoding="utf-8"?>
<DRSmonitoring xmlns="http://schemas.drsmonitoring.org/metadata/2013/11">
  <Server Name="$($CsvLine.Server)" IPAddress="$($CsvLine.IP)"> 
  </Server>
  <Monitoring>$Monitoring
  </Monitoring>
</DRSmonitoring>
"@
                
                $OutFile = Join-Path -Path $Output -ChildPath "Configuration_$($_.Server).xml"
                Write-Verbose -Message "[PROCESS - New-MonitoringConfiguration] Creating an XML Configuration File: Configuration_$($_.Server).xml"
                $ConfigFile | Out-File $OutFile

                # We create a quick output
                New-Object PSObject -Property @{
                    Properties = $CsvLine
                    ConfigurationFile = $OutFile
                }
            }
        } CATCH {
            IF ($ErrCSV) {Write-Error -Message "[PROCESS - New-MonitoringConfiguration] Something went wrong within the Input File"}
            Write-Error -Message $Error[0]
        }
    }

    END {
        
    }
}

New-MonitoringConfiguration -List 'C:\ps\Event 4\servers.csv' -Output 'C:\ps\Event 4' -Verbose
