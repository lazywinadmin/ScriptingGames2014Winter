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
}

$computers = @($cp1, $cp2, $cp3)
#### Test data - END

#--- Function: Create a chart
Function Create-PSChart {
    [cmdletbinding()]
    Param(
        [Parameter(
		  Mandatory=$true,
		  Position=0)]
		[object]$Object,
			
        [Parameter(
		  Mandatory=$true,
		  Position=1)]
		[ValidateScript({Test-Path -path $_})]
		[string]$Path,
		
		[switch]$Roles,
		
		[switch]$Hardware,
		
		[switch]$OS
    )
	
	#--- Code: TODO: Check for .NET framework here
	
	#--- Code: Load the MS Chart assemblies
	[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
	[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
	
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
		[void]$chart.Series.Add("Role")
		$chart.Series["Role"].BorderColor = "#1062ba"
		$chart.Series["Role"].BorderDashStyle="Solid"
		$chart.Series["Role"].BorderWidth = 1
		$chart.Series["Role"].ChartArea = "ChartArea1"
		$chart.Series["Role"].ChartType = "Column"
		$chart.Series["Role"].Color = "#6aaef7"
		$chart.Series["Role"].IsValueShownAsLabel = $true
		$chart.Series["Role"].IsVisibleInLegend = $true
		
		$computers | Group-Object -Property IISInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
			[void]$chart.Series["Role"].Points.AddXY("IIS", $_.Count) 
		}
		$computers | Group-Object -Property SQLInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
			[void]$chart.Series["Role"].Points.AddXY("SQL", $_.Count) 
		}
		$computers | Group-Object -Property ExchangeInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
			[void]$chart.Series["Role"].Points.AddXY("Exchange", $_.Count) 
		}
		$computers | Group-Object -Property SharepointInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
			[void]$chart.Series["Role"].Points.AddXY("Sharepoint", $_.Count) 
		}
		
		#--- Code: We save the chart now
		$today = (Get-Date).ToString("yyyy-MM-dd")
		$chart.SaveImage("$Path\Chart-Roles-$today.png","png")
	}
		
	#--- Code: In this other case we deal with the hardware information (CPU, RAM, Manufacturer...)
	if ($Hardware) {
		#--- Code: Nested array (Object property name, Chart title, X Axis label)
		$properties = @(
			New-Object PSObject -Property @{PropertyName = "CPU"; ChartTitle = "CPU Sockets Found"; TitleXAxis = "CPU Sockets"}
			New-Object PSObject -Property @{PropertyName = "MemoryGB"; ChartTitle = "Memory Found"; TitleXAxis = "Memory (GB)"}
			New-Object PSObject -Property @{PropertyName = "Manufacturer"; ChartTitle = "Manufacturer Found"; TitleXAxis = "Manufacturer Name"}
			New-Object PSObject -Property @{PropertyName = "Model"; ChartTitle = "Model Found"; TitleXAxis = "Model Name"}
		)
		
		ForEach ($data in $properties) {
			Try {
				#--- Code: Check if the property exists first.
				If (($computers | Get-Member | Select -ExpandProperty Name) -Contains $data.PropertyName) {
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
					
					$computers | Group-Object -Property $data.PropertyName | ForEach-Object {
						[void]$chart.Series["Role"].Points.AddXY($_.Name, $_.Count) 
					}
					
					#--- Code: We save the chart now
					$today = (Get-Date).ToString("yyyy-MM-dd")
					$chart.SaveImage("$Path\Chart-$($data.PropertyName)-$today.png","png")
				} Else {
					Write-Warning -Message "The property '$($data.PropertyName)' does not exist in the given object"
				}
			} Catch {
				
			}
		}
	}
}

$ScriptExecutionPath = Split-Path $MyInvocation.mycommand.path -Parent

Create-PSChart -Object $computers -Path $ScriptExecutionPath -Hardware -Roles
