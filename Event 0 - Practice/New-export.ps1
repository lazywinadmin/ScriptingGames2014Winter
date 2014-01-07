#========================================================================
# 
# Created on:   1/5/2014 1:08 PM
# Created by:   Administrator
# Organization: 
# Filename:     
#========================================================================

function Exportto-PowerPoint {
	
	[cmdletbinding()]
	
	Param(
	
	$Path,
	$GraphicSource
	
	)
	
	
	#Add-type -AssemblyName office
		$Application = New-Object -ComObject powerpoint.application
		$application.visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
		$slideType = "microsoft.office.interop.powerpoint.ppSlideLayout" -as [type]
		$templatePresentation = "C:\fso\TemplatePresentation.pptx"
		Import-Csv -Path C:\fso\pptTemplateNames.csv | ForEach-Object { `
		 $presentation = $application.Presentations.open($templatePresentation)
		 $customLayout = $presentation.Slides.item(2).customLayout
		 $slide = $presentation.slides.addSlide(1,$customLayout)
		 $slide.layout = $slideType::ppLayoutTitle
		 $slide.Shapes.title.TextFrame.TextRange.Text = $_.group
		 $slide.shapes.item(2).TextFrame.TextRange.Text = $_.date

		 $presentation.SavecopyAs("C:\fso\$($_.group)")
		 $presentation.Close()
		 "Created $($_.group)"
		}

		$application.quit()
		$application = $null
		[gc]::collect()
		[gc]::WaitForPendingFinalizers()
			
}

Function Exportto-html {
	
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
		[Parameter(mandatory=$false)]$Data,
		[Parameter(mandatory=$false)]$title,
		[Parameter(mandatory=$false)]$Subtitle,
		[Parameter(mandatory=$false)]$Image
		
		)
	Begin{
	
		#Preparing HTML header:
		
		$HtmlHeader = @" 
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://
www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
<style type="text/css">
<!--body {
background-color: #66CCFF;
} 
table {
background-color: white;
margin: 5px;
top: 10px;
display: inline-block;
padding: 5px;
border: 1px solid black
}
h2 {
clear: both;
width:500px;
padding:10px;
border:5px solid gray;	
text-align:center;
font-size: 150%;
margin-left: auto;
margin-right: auto;
margin-top: auto;
}
h3 {
clear: both;
color: #FF0000;
font-size: 115%;
margin-left: 10px;
margin-top: 15px;
text-align: center;
}
p {
color: #FF0000;
margin-left: 10px;
margin-top: 15px; 
}
IMG.Graphs {
display: block;
    margin-left: auto;
    margin-right: auto
}
tr:nth-child(odd) {background-color: lightgray}
-->
</style>
</head>
<body>
"@
		
		}
	Process{
	
		
		
                        #If HTML view has been selected, the returned service status will be exported to a HTML file as well
                        Write-Verbose "Exporting object to HTML $($path)"
                         
                          
                       	$htmltitle = "<h2>$($title)</h2>"
						$htmlSubtitle = "<h3>$($Subtitle)</h3>"
                       	$HtmlItem = $Data | ConvertTo-Html -Fragment
                           	
                      	if ($Image){
					$ImageHTML = @"
<IMG class="Graphs" src="data:image/jpg;base64,$($Image)" style="left: 50%" alt="Image01">
"@
			}
                  
	}         
	End{
			$HtmlHeader + $htmltitle + $htmlsubtitle+ $HtmlItem + $ImageHTML| Out-File $Path
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

$ByteImage  = Get-Base64Image "E:\Users\Administrator\SkyDrive\Scripting\Githhub\WinterScriptingGames2014\Event 0 - Practice\Charts\Chart-CPU-2014-01-06.png"

Exportto-html  -Image $ByteImage -Data (Get-Process) -Path "d:\temp\plop.html" -title "Winter Scripting Games 2014 - Practice Event" -Subtitle  "Posh Monks"