#========================================================================
# 
# Created on:   1/5/2014 1:08 PM
# Created by:   Administrator
# Organization: 
# Filename:     
#========================================================================



Function New-Chart {
<#
        .SYNOPSIS
                        New-Chart

        .DESCRIPTION
                        This function creates Charts according to the given parameters. Charts are available as a byte array in the output

        .PARAMETER  Computers
                        This represents the computers object array which shall be analyzed.

        .PARAMETER  Path
                        This represents the path where the charts shall be created at.

        .PARAMETER  Roles
                        Create a chart about the computers Roles like IIS, SQL, Sharepoint or Exchange.

        .PARAMETER  Hardware
                        Create a chart about the computers Hardware such as the Manufacturer, the CPU...

        .PARAMETER  OS
                        Create a chart about the computers OS and Service Pack.

        .EXAMPLE
                        PS C:\> New-Chart -Computers $computers -Path "C:\ps" -Roles -OS -Hardware
                        Path                                                        Title
                        ----                                                        -----
                        C:\ps\Chart-Roles.png                                       Roles
                        C:\ps\CPU.png                                               CPU
                        C:\ps\MemoryGB.png                                          MemoryGB
                        C:\ps\Manufacturer.png                                      Manufacturer
                        C:\ps\Model.png                                             Model
                        C:\ps\ServicePack.png                                       ServicePack
                        ...
                        This example shows how to call the New-Chart function with named parameters.

        .INPUTS
                        TODO: Determine if object or object[]

        .OUTPUTS
                        System.Array

        .NOTES
                        This function rely on the .NET Framework version 4.0 or higher to generate graphical charts, 
                        MS Charts need to be installed for .NET versions which are below 4.0 such as 3.5

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
                [object]$Path,
                
                [switch]$Roles,
                
                [switch]$Hardware,
                
                [switch]$OS
    )
        
        BEGIN {
                #--- Code: TODO: Check for .NET framework here
                
                Write-Verbose -Message "Loading the Data Visualization assembly"
                #--- Code: TODO: replace with add-type, partialname is meh
                [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
                
                [array]$output = @()
        }
        
        PROCESS {
                #--- Code: The roles need to be graphed
                if ($Roles) {
                        Write-Verbose -Message "Generating a chart for the roles"
                        
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
                        
                        #--- Code: As we're dealing with multiple objects, we're grouping the properties and check which ones are considered true
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
                        $stream = New-Object System.IO.MemoryStream
                        $chart.SaveImage($stream, "png")
                        
                        $chart.SaveImage("$Path\Chart-Roles.png","png")
                        # $output += New-Object PSObject -Property @{Label = "Roles"; Bytes = $stream.GetBuffer()}
                        $output += New-Object PSObject -Property @{Title = "Roles"; Path = "$Path\Chart-Roles.png"; Bytes = $stream.GetBuffer()}
                        
                        #$today = (Get-Date).ToString("yyyy-MM-dd")
                        # $chart.SaveImage("$Path\Chart-Roles.png","png")
                        #Write-Output "$Path\Chart-Roles-$today.png"
                }
                        
                #--- Code: Either the Hardware or the OS shall be shown
                if ($Hardware -or $OS) {
                        Write-Debug -Message "New object properties may be added below to generate additionals charts"
                        
                        #--- Code: Cast as an array to prevent single elements from showing as an object
                        [array]$properties = @()
                        
                        #--- Code: Nested array (Object property name, Chart title, X Axis label)
                        if ($Hardware) {
                                $properties += @(
                                        New-Object PSObject -Property @{PropertyName = "CPU"; ChartTitle = "CPU Sockets Found"; TitleXAxis = "CPU Sockets"}
                                        New-Object PSObject -Property @{PropertyName = "MemoryGB"; ChartTitle = "Memory Found"; TitleXAxis = "Memory (GB)"}
                                        New-Object PSObject -Property @{PropertyName = "Manufacturer"; ChartTitle = "Manufacturer Found"; TitleXAxis = "Manufacturer Name"}
                                        New-Object PSObject -Property @{PropertyName = "Model"; ChartTitle = "Model Found"; TitleXAxis = "Model Name"}
                                )
                        }
                        
                        if ($OS) {
                                $properties += @(
                                        New-Object PSObject -Property @{PropertyName = "OS"; ChartTitle = "OS Found"; TitleXAxis = "OS"}
                                        New-Object PSObject -Property @{PropertyName = "ServicePack"; ChartTitle = "Service Pack Found"; TitleXAxis = "Service Pack Name"}
                                )
                        }
                        
                        ForEach ($data in $properties) {
                                Try {
                                        #--- Code: Check if the property exists first.
                                        If (($Computers | Get-Member | Select -ExpandProperty Name) -Contains $data.PropertyName) {
                                                Write-Verbose -Message "Generating a chart for the property '$($data.PropertyName)'"
                                                
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
                                                $stream = New-Object System.IO.MemoryStream
                                                $chart.SaveImage($stream, "png")
                                                
                                                # $output += New-Object PSObject -Property @{Label = $data.PropertyName; Bytes = $stream.GetBuffer()}
                                                $chart.SaveImage("$Path\Chart-$($data.PropertyName).png","png")
                                                $output += New-Object PSObject -Property @{Title = $data.PropertyName; Path = "$Path\Chart-$($data.PropertyName).png"; Bytes = $stream.GetBuffer()}
                                                
                                                #$today = (Get-Date).ToString("yyyy-MM-dd")
                                                # $chart.SaveImage("$Path\Chart-$($data.PropertyName)-$today.png","png")
                                                #Write-Output "$Path\Chart-$($data.PropertyName)-$today.png"
                                        } Else {
                                                Write-Warning -Message "The property '$($data.PropertyName)' does not exist in the given object"
                                        }
                                } Catch {
                                        
                                }
                        }
                }
        }
        
        END {
                return $output
        }
}

function Export-PowerPoint {
		<#
	.SYNOPSIS
	Exports Charts to PowerPoint format

	.DESCRIPTION
	Export the Charts to a powerpoint presentation. The first page is a Title with a subtitle. Then one slide will be created for each graph together with a main title.
	
	.PARAMETER  <Path>
	Specifies de export path folder (must be a folder).
	
	.PARAMETER  <GraphInfos>
	This parameter must be an object with the following two headers : Path;Title.
	Path --> Represents the the path to the physical location of the chart.
	Title --> A short title of what the chart represent
	
	.PARAMETER  <Title>
	Title that will be used on all documents (Front page of the PowerPoint export, Header of Html file). 
	
	.PARAMETER  <Subtitle>
	SubTitle that will be used on all documents (Front page of the PowerPoint export, Header of Html file (Underneath the title)). 
	
	.PARAMETER  <Debug>
	This parameter is optional, and will if called, activate the deubbing mode wich can help to troubleshoot the script if needed. 

	.NOTES
	-Version 0.4
	-Author : Stéphane van Gulick
	-Creation date: 08/01/2014


	.EXAMPLE
	Export-powerPoint -title "PowerShell Winter Scripting Games 2014" -Subtitle "Posh Monks" -Path D:\Exports -GraphInfos $ArrayImage
	
	Exports the Images to a powerPoint format. The file name is Export-PowerShellMonks.pptx. On the first slide,
	The title : "PowerShell Winter Scripting Games 2014" and the subtitle "Power Monks" will be displayed.
	The file will be exported to D:\Export Folder.
	
	

#>
	
	[cmdletbinding()]
	
		Param(
		
		[Parameter(mandatory=$true)]$Path = $(throw "Path is mandatory, please provide a value."),
		[Parameter(mandatory=$true)]$GraphInfos,
		[Parameter(mandatory=$false)]$title,
		[Parameter(mandatory=$false)]$Subtitle
		
		)

	Begin {
		Add-type -AssemblyName office
		Add-Type -AssemblyName microsoft.office.interop.powerpoint
		#DEfining PowerPoints main variables
			$MSTrue=[Microsoft.Office.Core.MsoTriState]::msoTrue
			$MsFalse=[Microsoft.Office.Core.MsoTriState]::msoFalse
			$slideTypeTitle = [microsoft.office.interop.powerpoint.ppSlideLayout]::ppLayoutTitle
			$SlideTypeChart = [microsoft.office.interop.powerpoint.ppSlideLayout]::ppLayoutChart
			
		#Creating the ComObject
			$Application = New-Object -ComObject powerpoint.application
			#$application.visible = $MSTrue
	}
	Process{
		#Creating the presentation
			$Presentation = $Application.Presentations.add() 
		#Adding the first slide
			$Titleslide = $Presentation.Slides.add(1,$slideTypeTitle)
			$Titleslide.Shapes.Title.TextFrame.TextRange.Text = $Title
			$Titleslide.shapes.item(2).TextFrame.TextRange.Text = $Subtitle
			$Titleslide.BackgroundStyle = 11
			[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Titleslide)
		
		#Adding the charts
		foreach ($Graphinfo in $GraphInfos) {

			#Adding slide
			$slide = $Presentation.Slides.add($Presentation.Slides.count+1,$SlideTypeChart)

			#Defining slide type:
			#http://msdn.microsoft.com/en-us/library/microsoft.office.interop.powerpoint.ppslidelayout(v=office.14).aspx
					$slide.Layout = $SlideTypeChart
					$slide.BackgroundStyle = 11
					$slide.Shapes.Title.TextFrame.TextRange.Text = $Graphinfo.title
			#Adding picture (chart) to presentation:
				#http://msdn.microsoft.com/en-us/library/office/bb230700(v=office.12).aspx
					$slide.Shapes.AddPicture($Graphinfo.Path,$mstrue,$msTrue,300,100,350,400)
					[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($slide)
		}
	}
end {
		$presentation.Saveas($exportPath)
	 	$presentation.Close()
		[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($presentation)
		$Application.quit()
		[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Application)
		[gc]::collect()
		[gc]::WaitForPendingFinalizers()
		$Application =  $null
	}
	
}

Function Export-html {
	
	<#
	.SYNOPSIS
	Exports data to HTML format

	.DESCRIPTION
	ExportTo-HTML has a personalized CSS code which make the output nicer then the classical ConvertTo-Html and allows to add images / graphs in the HTML output
	
	.PARAMETER  <Debug>
	This parameter is optional, and will if called, activate the deubbing mode wich can help to troubleshoot the script if needed. 
	
	.NOTES
	-Version 0.1
	-Author : Stéphane van Gulick
	-Creation date: 01/06/2012
	-Creation date: 01/06/2012
	-Script revision history
	##0.1 : Initilisation
	##0.2 : First version
	##0.3 : Added Image possibilities

	
	
	.EXAMPLE
	Exportto-html -Data (Get-Process) -Path "d:\temp\export.html" -title "Data export"
	
	Exports data to a HTML file located in d:\temp\export.html with a title "Data export"
	
	.EXAMPLE
	In order to call the script in debugging mode
	Exportto-html  -Image $ByteImage -Data (Get-service) "d:\temp\export.html" -title "Data Service export"
	
	Exports data to a HTML file located in d:\temp\export.html with a title "Data export". Adds also an image in the HTML output.
	#Remark: -image must be  of Byte format.
#>
	
	[cmdletbinding()]
	
		Param(
		
		[Parameter(mandatory=$true)]$Path = $(throw "Path is mandatory, please provide a value."),
		[Parameter(mandatory=$false)]$GraphInfos,
		[Parameter(mandatory=$false)]$Data,
		[Parameter(mandatory=$false)]$title,
		[Parameter(mandatory=$false)]$Subtitle,
		[Parameter(mandatory=$false)]$Image
		
		)
	Begin{
	
		#Preparing HTML header:
		
		$html = @" 
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://
www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
		
<style type="text/css">
body {
    height: 100%;
    margin: 0px;
	background-color: #a0e1ff;
	background-image: -ms-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: -moz-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: -o-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: -webkit-gradient(linear, left top, right bottom, color-stop(0, #FFFFFF), color-stop(1, #00A3EF));
	background-image: -webkit-linear-gradient(top left, #FFFFFF 0%, #00A3EF 100%);
	background-image: linear-gradient(to bottom right, #FFFFFF 0%, #00A3EF 100%);
    background-repeat: no-repeat;
    background-attachment: fixed;
	font-family:"Tahoma", "Lucida Sans Unicode", Verdana, Arial, Helvetica, sans-serif;
	font-size:12px;
}

#container {
	padding-top:50px;
	padding-bottom:50px;
}

#core {
	background-color: #efefef;
	-webkit-background-size: 50px 50px;
	-moz-background-size: 50px 50px;
	background-size: 50px 50px;
	-moz-box-shadow: 1px 1px 8px gray;
	-webkit-box-shadow: 1px 1px 8px gray;
	box-shadow: 1px 1px 8px gray;
	box-shadow: 0 0 5px #888;
	border: 1px solid #91938d;
	margin: 0 auto;
	width: 880px;
}

#header {
	background-color: #2d2d2d;
	border-bottom: 3px solid #666863;
	height: 35px;
	margin-bottom: 20px;
}

#title {
	color: #ffffff;
	font-family: Tahoma;
	font-size: 18px;
	line-height: 35px;
	font-variant: small-caps;
	font-weight: bold;
	padding-left: 25px;
	margin: 0 auto;
	/*text-shadow: 2px 1px 3px rgba(0, 0, 0, 0.47);*/
	text-transform: uppercase;
	vertical-align:middle;
}

#summary {
	border: 1px dashed #8aaa7b;
	background-color: #eaffe0;
	margin: 0 auto;
	padding: 5px;
	width: 800px;
}

#content_header {
	font-size: 14px;
	font-weight: bold;
}

#chart_container {
	background-color: #e0f3ff;
	border: 1px solid #b3c3cc;
	margin: 0px auto 15px;
	margin-top: 15px;
	padding: 5px;
	width: 800px;
}

#values_container {
	background-color: #fffced;
	border: 1px solid #bcb3cc;
	margin: 0px auto 15px;
	margin-top: 15px;
	padding: 5px;
	width: 800px;
}

#informations {
	border-collapse: collapse;
	border: 1px solid #888;
	margin: 5px;
}

#informations td {
	padding-left: 10px;
	padding-right: 20px;
}

#informations th {
	background-color: #ffee9b;
	border: 1px solid #000;
}

#informations tr {
	background-color: #fff8d8;
}

.title_chart {
	display: block;
	font-size: 12px;
	font-weight: bold;
	margin-bottom: 4px;
}

.chart {
	border: 1px solid #ddd;
	display: block;
	margin: 0px auto 5px;
}

a:visited { color: blue; }
a:link { color: blue; }
</style>
		
</head>
<body>
<div id="container">
	<div id="core">
		<div id="header"><span id="title">POSH Monks Report</span></div>
"@
		
	}
	Process {
        #If HTML view has been selected, the returned service status will be exported to a HTML file as well
        Write-Verbose "Exporting object to HTML $($path)"
		
		# Generate the table of contents
		$html += '
		<div id="summary">
			<span id="content_header">Table of contents:</span>
			<ul>'
		
		ForEach ($item in $GraphInfos) {
			$html += '
				<li><a href="#anch' + $item.Title + '">Chart: ' + $item.Title + '</a></li>'
		}
		
		$html += '
				<li><a href="#anchValues">Analyzed Computers</a></li>
			</ul>
		</div>
		'
		
		# Generate the graphs
		ForEach ($item in $GraphInfos) {
			$converted = [System.Convert]::ToBase64String($item.Bytes)
			$html += '<div id="chart_container">
				<span id="anch' + $item.Title + '" class="title_chart">Chart: ' + $item.Title + '</span><br />
				<img class="chart" src="data:image/jpg;base64,' + $converted + '" />
			</div>'
		}
		
		# Generate a table for the analyzed computers
		$html += '
			<div id="values_container">
				<span id="anchValues" class="title_chart">Analyzed Computers</span><br />
				<table id="informations">
				'
		
		# Todo: Add a label or a title to get a better visual of the given property
		ForEach ($item in $Data) {
			# We retrieve the NoteProperties from the given object, we don't need the methods, we skip the computername since it's our header
			$properties = ($item | Get-Member | Where-Object {($_.MemberType -eq "NoteProperty") -and ($_.Name -ne "ComputerName")} | Select -ExpandProperty Name)
			
			$tableset = '<tr><th>Computer Name:</th><th>' + $item.ComputerName + '</th></tr>'
			ForEach ($property in $properties) {
				$tableset += '<tr><td>' + $property + '</td><td>' + $($item.$property) + '</td></tr>'
			}
			
			$html += $tableset
			
			# $computerName = $item.ComputerName
			# $html += '
				# <tr>
					# <td>
				# </tr>
			# '
			write-host $computerName
		}
		# the line below retrieve the NoteProperties of an object by skipping the Method and other stuff. We need a label still.
		#($obj | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty"} | Select -ExpandProperty Name)
		
		#$html += $Data | ConvertTo-Html
		
		$html += '
				</table>
			</div>'
                  <#        
                       	$htmltitle = "<h2>$($title)</h2>"
						$htmlSubtitle = "<h3>$($Subtitle)</h3>"
                       	$HtmlItem = $Data | ConvertTo-Html -Fragment
                           	
                      	if ($Image){
					$ImageHTML = @"
<IMG class="Graphs" src="data:image/jpg;base64,$($Image)" style="left: 50%" alt="Image01">
"@
		
			}#>
                  
	}         
	End {
		$html += "</div></div></body></html>"
		$html | Out-File $Path
	}
}

Function Get-Base64Image {
		<#
	.SYNOPSIS
	Converts an image to Byte type
	
	.DESCRIPTION
	Usefull in oder to add an image byte into HTML code and make the HTML file independant from any other external file.
	
	.PARAMETER <Path>
	File path to the original image file.
	
	.PARAMETER  <Debug>
	This parameter is optional, and will if called, activate the deubbing mode wich can help to troubleshoot the script if needed.
	
	#>
	
	[cmdletbinding()]
		
		Param(
		
		[Parameter(mandatory=$true)]$Path = $(throw "Path is mandatory, please provide a value.")
	)
	begin{}
	process{
		$ImageBytes = [Convert]::ToBase64String((Get-Content $Path -Encoding Byte))
	}
	End{
		return $ImageBytes
	}
}

function New-export {
	
[cmdletbinding()]
	
		Param(
		
		[Parameter(mandatory=$true)]$Path = $(throw "Path is mandatory, please provide a value."), #Full  path ? Or folder path ?
		[Parameter(mandatory=$true)]$Data,
		[Parameter(mandatory=$false)][Validateset("csv", "html", "powerpoint")][String]$Exportype,
		[Parameter(mandatory=$false, ParameterSetName="ppt")]$ArrayImage,
		[Parameter(mandatory=$false)]$title,
		[Parameter(mandatory=$false)]$Subtitle,
		[Parameter(mandatory=$false)]$Image
		
		)
	Begin {
		
		
			switch ($Exportype){
				
					("csv"){
						$FileName = "Export-$($Title).Csv"
						$ExportPath = Join-Path -Path $Path -ChildPath $FileName
						Write-Verbose "exporting the file to $($exportPath)"	
						$Data | Export-Csv -Path $ExportPath -NoTypeInformation
					}
					("Html"){
						$FileName = "Export-$($Title).html"
						$ExportPath = Join-Path -Path $Path -ChildPath $FileName
						Write-Verbose "exporting the file to $($exportPath)"	
						Export-html -Data $Data -title $title -Subtitle $Subtitle -Path $ExportPath -GraphInfos $ArrayImage
					}
					("PowerPoint"){
						$FileName = "Export-$($Title).pptx"
						$ExportPath = Join-Path -Path $Path -ChildPath $FileName
						Write-Verbose "exporting the file to $($exportPath)"	
						Export-powerPoint -title $Title -Subtitle $SubTitle -Path $ExportPath -GraphInfos $ArrayImage
					
					}
					default {
						Write-Host "none"
					}

			}
	}
	Process{
	
		}
	End{
	}
}

########Testing#############

$cp1 = New-Object PSObject -Property @{
        ComputerName                = "SRV001"
        IISInstalled                = $true
        SQLInstalled                = $true
        ExchangeInstalled        = $false
        SharepointInstalled        = $false
        CPU                                = 4
        MemoryGB                = 6
        Manufacturer        = "Allister Fisto Industries"
        Model                        = "Fistron 2000"
        ServicePack                = "Microsoft Windows Server 2008 R2 Enterprise"
		OS = ""
}

$cp2 = New-Object PSObject -Property @{
        ComputerName                = "SRV002"
        IISInstalled                = $true
        SQLInstalled                = $true
        ExchangeInstalled        = $false
        SharepointInstalled        = $true
        CPU                                = 2
        MemoryGB                = 2
        Manufacturer        = "Allister Fisto Industries"
        Model                        = "Fistron 3000"
        ServicePack                = "Microsoft Windows Server 2008 R2 Standard"
}

$cp3 = New-Object PSObject -Property @{
        ComputerName                = "SRV003"
        IISInstalled                = $false
        SQLInstalled                = $false
        ExchangeInstalled        = $true
        SharepointInstalled        = $false
        CPU                                = 4
        MemoryGB                = 8
        Manufacturer        = "Allister Fisto Industries"
        Model                        = "Fistron 2000"
        ServicePack                = "Microsoft Windows Server 2008 Standard"
}

$computers = @($cp1, $cp2, $cp3)
#$ByteImage  = Get-Base64Image "E:\Users\Administrator\SkyDrive\Scripting\Githhub\WinterScriptingGames2014\Event 0 - Practice\Charts\Chart-CPU-2014-01-06.png"

######ENDTESTING#####################

$Title  = "Posh-Monks"
$SubTitle = "Winter Scripting Games 2014 - Event:00 (Practice)"


#ExportTo-PowerPoint -Path "D:\temp\plop.pptx" -GraphInfos $a -title $Title -Subtitle $SubTitle
#Exportto-html  -Image $ByteImage -Data (Get-Process) -Path "d:\temp\plop.html" -title $Title -Subtitle  $SubTitle

$Output = New-Chart -Computers $computers -Path "c:\ps" -Roles -OS -Hardware
#Export powerpoint
	#New-export -Path "c:\ps\" -Exportype "powerpoint"-title $Title -Subtitle $SubTitle -ArrayImage $output
#Export Html
	New-export -Path "c:\ps\" -Exportype "html" -title $Title -Subtitle $SubTitle -Data $computers -ArrayImage $output