# **********************************************************
#    Make a graphic using Powershell & MS Charts
# **********************************************************

[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

$cp1 = New-Object PSObject -Property @{
	ComputerName		= "SRV001"
	IISInstalled		= $true
	SQLInstalled		= $true
	ExchangeInstalled	= $false
	SharepointInstalled	= $false
}

$cp2 = New-Object PSObject -Property @{
	ComputerName		= "SRV002"
	IISInstalled		= $true
	SQLInstalled		= $true
	ExchangeInstalled	= $false
	SharepointInstalled	= $true
}

$cp3 = New-Object PSObject -Property @{
	ComputerName		= "SRV003"
	IISInstalled		= $false
	SQLInstalled		= $false
	ExchangeInstalled	= $true
	SharepointInstalled	= $false
}

$computers = @($cp1, $cp2, $cp3)

# Create the chart object
$chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
$chart1.BackColor = "White"
$chart1.Width = 500
$chart1.Height = 500

# Name our chart
[void]$chart1.Titles.Add("Detected Roles")
$chart1.Titles[0].Alignment = "topLeft"
$chart1.Titles[0].Font = "Tahoma,13pt"

# Create the chart area
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
$chartarea.BackSecondaryColor = "#e8f3ff"
$chart1.ChartAreas.Add($chartarea)

# Create the legend
# $legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
# $legend.Name = "Legend1"
# $chart1.Legends.Add($legend)

# Add the data to the chart
[void]$chart1.Series.Add("Role")
$chart1.Series["Role"].BorderColor = "#1062ba"
$chart1.Series["Role"].BorderDashStyle="Solid"
$chart1.Series["Role"].BorderWidth = 1
$chart1.Series["Role"].ChartArea = "ChartArea1"
$chart1.Series["Role"].ChartType = "Column"
$chart1.Series["Role"].Color = "#6aaef7"
$chart1.Series["Role"].IsValueShownAsLabel = $true
$chart1.Series["Role"].IsVisibleInLegend = $true
# $chart1.Series["Role"].Legend = "Legend1"
$computers | Group-Object -Property IISInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
	$chart1.Series["Role"].Points.AddXY( "IIS" , $_.Count) 
}
$computers | Group-Object -Property SQLInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
	$chart1.Series["Role"].Points.AddXY( "SQL" , $_.Count) 
}
$computers | Group-Object -Property ExchangeInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
	$chart1.Series["Role"].Points.AddXY( "Exchange" , $_.Count) 
}
$computers | Group-Object -Property SharepointInstalled | Where-Object { $_.Name -eq $true } | ForEach-Object {
	$chart1.Series["Role"].Points.AddXY( "Sharepoint" , $_.Count) 
}

# Save the chart as a picture
$chart1.SaveImage("c:\ps\graph.png","png")
