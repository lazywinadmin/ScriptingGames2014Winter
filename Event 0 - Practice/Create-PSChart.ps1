# **********************************************************
#    Make a graphic using Powershell & MS Charts
# **********************************************************

<#
 todo: if the machine miss the .NET framework 4 then we prompt the user to download
	the mschart exe
#>

#### Test data - START
$cp1 = New-Object PSObject -Property @{
	ComputerName                = "SRV001"
	IISInstalled                = $true
	SQLInstalled                = $true
	ExchangeInstalled        = $false
	SharepointInstalled        = $false
	CPU				= 4
	MemoryGB		= 6
	Manufacturer	= "Allister Fisto Industries"
	Model			= "Fistron 2000"
	ServicePack		= "Microsoft Windows Server 2008 R2 Enterprise"
}

$cp2 = New-Object PSObject -Property @{
	ComputerName                = "SRV002"
	IISInstalled                = $true
	SQLInstalled                = $true
	ExchangeInstalled        = $false
	SharepointInstalled        = $true
	CPU				= 2
	MemoryGB		= 2
	Manufacturer	= "Allister Fisto Industries"
	Model			= "Fistron 3000"
	ServicePack		= "Microsoft Windows Server 2008 R2 Standard"
}

$cp3 = New-Object PSObject -Property @{
	ComputerName                = "SRV003"
	IISInstalled                = $false
	SQLInstalled                = $false
	ExchangeInstalled        = $true
	SharepointInstalled        = $false
	CPU				= 4
	MemoryGB		= 8
	Manufacturer	= "Allister Fisto Industries"
	Model			= "Fistron 2000"
	ServicePack		= "Microsoft Windows Server 2008 Standard"
}

$computers = @($cp1, $cp2, $cp3)
#### Test data - END

#--- Function: Create a chart
Function Create-PSChart {
<#
	.SYNOPSIS
			Create-PSChart

	.DESCRIPTION
			This function creates a Chart according to the given parameters.

	.PARAMETER  Computers
			This represents the computers object array which shall be analyzed.

	.PARAMETER  Path
			The Path define where the Charts shall be saved to.

	.PARAMETER  Roles
			Create a chart about the computers Roles like IIS, SQL, Sharepoint or Exchange.

	.PARAMETER  Hardware
			Create a chart about the computers Hardware such as the Manufacturer, the CPU...

	.PARAMETER  OS
			Create a chart about the computers OS and Service Pack.

	.EXAMPLE
			PS C:\> Create-PSChart -Computers $computers -Path C:\temp -Roles -OS -Hardware
			C:\ps\Chart-Roles-2014-01-06.png
			C:\ps\Chart-CPU-2014-01-06.png
			C:\ps\Chart-MemoryGB-2014-01-06.png
			C:\ps\Chart-Manufacturer-2014-01-06.pn
			...
			This example shows how to call the Create-PSChart function with named parameters.

	.INPUTS
			TODO: Determine if object or object[]

	.OUTPUTS
			System.String[]

	.NOTES
			This function rely on the .NET Framework version 4.0 or higher, MS Charts need to be installed
			for versions which are below 4.0 such as 3.5

	.LINK
			MS Charts: http://www.microsoft.com/en-us/download/details.aspx?id=14422

	.LINK
			about_functions_advanced

	.LINK
			about_comment_based_help

	.LINK
			about_functions_advanced_parameters

	.LINK
			about_functions_advanced_methods
#>
    [cmdletbinding()]
    Param(
        [Parameter(
		  Mandatory=$true,
		  Position=0)]
		[object]$Computers,
			
        [Parameter(
		  Mandatory=$true,
		  Position=1)]
		[ValidateScript({Test-Path -path $_})]
		[string]$Path,
		
		[switch]$Roles,
		
		[switch]$Hardware,
		
		[switch]$OS
    )
	
	BEGIN {
		#--- Code: TODO: Check for .NET framework here
		
		#--- Code: Load the MS Chart assemblies
		[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
		[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
	}
	
	PROCESS {
		#--- Code: The roles need to be graphed
		if ($Roles) {
			#--- Code: First, we create the chart object
			$chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
			$chart.BackColor = "White"
			$chart.Width = 500
			$chart.Height = 500
			
			#--- Code: We name our chart
			[void]$chart.Titles.Add("Detected Roles")
			$chart.Titles[0].Alignment = "topLeft"
			$chart.Titles[0].Font = "Tahoma,13pt"
			
			#--- Code: We create the chart area
			$chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
			$chartarea.Name = "ChartArea1"
			# $chartarea.Area3DStyle.Enable3D = $true
			$chartarea.AxisX.Interval = 1
			$chartarea.AxisX.MajorGrid.LineColor = "#d1d1d1"
			$chartarea.AxisX.Title = "Role"
			$chartarea.AxisY.Interval = 5
			$chartarea.AxisY.MajorGrid.LineColor = "#d1d1d1"
			$chartarea.AxisY.Title = "Count"
			$chartarea.BackColor = "White"
			$chartarea.BackGradientStyle = "DiagonalRight"
			$chartarea.BackSecondaryColor = "#d3e6ff"
			$chart.ChartAreas.Add($chartarea)
			
			#--- Code: We create the serie now
			[void]$chart.Series.Add("Data")
			$chart.Series["Data"].BorderColor = "#1062ba"
			$chart.Series["Data"].BorderDashStyle="Solid"
			$chart.Series["Data"].BorderWidth = 1
			$chart.Series["Data"].ChartArea = "ChartArea1"
			$chart.Series["Data"].ChartType = "Column"
			$chart.Series["Data"].Color = "#6aaef7"
			$chart.Series["Data"].IsValueShownAsLabel = $true
			$chart.Series["Data"].IsVisibleInLegend = $true
			
			$Computers | Group-Object -Property IISInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
				[void]$chart.Series["Data"].Points.AddXY("IIS", $_.Count) 
			}
			$Computers | Group-Object -Property SQLInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
				[void]$chart.Series["Data"].Points.AddXY("SQL", $_.Count) 
			}
			$Computers | Group-Object -Property ExchangeInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
				[void]$chart.Series["Data"].Points.AddXY("Exchange", $_.Count) 
			}
			$Computers | Group-Object -Property SharepointInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
				[void]$chart.Series["Data"].Points.AddXY("Sharepoint", $_.Count) 
			}
			
			#--- Code: We save the chart now
			$today = (Get-Date).ToString("yyyy-MM-dd")
			$chart.SaveImage("$Path\Chart-Roles-$today.png","png")
			Write-Output "$Path\Chart-Roles-$today.png"
		}
			
		#--- Code: Either the Hardware or the OS shall be shown
		if ($Hardware -or $OS) {
			#--- Code: Nested array (Object property name, Chart title, X Axis label)
			if ($Hardware) {
				$properties = @(
					New-Object PSObject -Property @{PropertyName = "CPU"; ChartTitle = "CPU Sockets Found"; TitleXAxis = "CPU Sockets"}
					New-Object PSObject -Property @{PropertyName = "MemoryGB"; ChartTitle = "Memory Found"; TitleXAxis = "Memory (GB)"}
					New-Object PSObject -Property @{PropertyName = "Manufacturer"; ChartTitle = "Manufacturer Found"; TitleXAxis = "Manufacturer Name"}
					New-Object PSObject -Property @{PropertyName = "Model"; ChartTitle = "Model Found"; TitleXAxis = "Model Name"}
				)
			}
			
			if ($OS -and !$Hardware) {
				$properties = @(
					New-Object PSObject -Property @{PropertyName = "OS"; ChartTitle = "OS Found"; TitleXAxis = "OS"}
					New-Object PSObject -Property @{PropertyName = "ServicePack"; ChartTitle = "Service Pack Found"; TitleXAxis = "Service Pack Name"}
				)
			}
			
			if ($OS -and $Hardware) {
				$properties += @(
					New-Object PSObject -Property @{PropertyName = "OS"; ChartTitle = "OS Found"; TitleXAxis = "OS"}
					New-Object PSObject -Property @{PropertyName = "ServicePack"; ChartTitle = "Service Pack Found"; TitleXAxis = "Service Pack Name"}
				)
			}
			
			ForEach ($data in $properties) {
				Try {
					#--- Code: Check if the property exists first.
					If (($Computers | Get-Member | Select -ExpandProperty Name) -Contains $data.PropertyName) {
						#--- Code: First, we create the chart object
						$chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
						$chart.BackColor = "White"
						$chart.Width = 500
						$chart.Height = 500
						
						#--- Code: We name our chart
						[void]$chart.Titles.Add($data.ChartTitle)
						$chart.Titles[0].Alignment = "topLeft"
						$chart.Titles[0].Font = "Tahoma,13pt"
						
						#--- Code: We create the chart area
						$chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
						$chartarea.Name = "ChartArea1"
						$chartarea.AxisX.Interval = 1
						$chartarea.AxisX.MajorGrid.LineColor = "#d1d1d1"
						$chartarea.AxisX.Title = $data.TitleXAxis
						$chartarea.AxisY.Interval = 5
						$chartarea.AxisY.MajorGrid.LineColor = "#d1d1d1"
						$chartarea.AxisY.Title = "Count"
						$chartarea.BackColor = "White"
						$chartarea.BackGradientStyle = "DiagonalRight"
						$chartarea.BackSecondaryColor = "#d3e6ff"
						$chart.ChartAreas.Add($chartarea)
						
						#--- Code: We create the serie now
						[void]$chart.Series.Add("Role")
						$chart.Series["Role"].BorderColor = "#1062ba"
						$chart.Series["Role"].BorderDashStyle="Solid"
						$chart.Series["Role"].BorderWidth = 1
						$chart.Series["Role"].ChartArea = "ChartArea1"
						$chart.Series["Role"].ChartType = "Column"
						$chart.Series["Role"].Color = "#6aaef7"
						$chart.Series["Role"].IsValueShownAsLabel = $true
						$chart.Series["Role"].IsVisibleInLegend = $true
						
						$Computers | Group-Object -Property $data.PropertyName | ForEach-Object {
							[void]$chart.Series["Role"].Points.AddXY($_.Name, $_.Count) 
						}
						
						#--- Code: We save the chart now
						$today = (Get-Date).ToString("yyyy-MM-dd")
						$chart.SaveImage("$Path\Chart-$($data.PropertyName)-$today.png","png")
						Write-Output "$Path\Chart-$($data.PropertyName)-$today.png"
					} Else {
						Write-Warning -Message "The property '$($data.PropertyName)' does not exist in the given object"
					}
				} Catch {
					
				}
			}
		}
	}
	
	END {
	
	}
}

$ScriptExecutionPath = Split-Path $MyInvocation.mycommand.path -Parent

Create-PSChart -Computers $computers -Path $ScriptExecutionPath -Roles -OS -Hardware
